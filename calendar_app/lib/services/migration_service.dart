import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../models/employee.dart';
import '../models/vacation_absence.dart';

/// 🔥 SAFE MIGRATION SERVICE - Moves local data to Supabase without breaking assignments
class MigrationService {
  static final _supabase = Supabase.instance.client;
  
  /// Check if migration has been completed for current user
  static Future<bool> isMigrationCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      
      return prefs.getBool('migration_completed_$userId') ?? false;
    } catch (e) {
      print('MigrationService: Error checking migration status: $e');
      return false;
    }
  }
  
  /// Mark migration as completed for current user
  static Future<void> markMigrationCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await prefs.setBool('migration_completed_$userId', true);
        print('MigrationService: Marked migration as completed for user $userId');
      }
    } catch (e) {
      print('MigrationService: Error marking migration completed: $e');
    }
  }
  
  /// Migrate custom professions from local storage to Supabase
  static Future<void> migrateCustomProfessions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      // Check if already migrated
      final existingData = await _supabase
          .from('custom_professions')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      
      if (existingData.isNotEmpty) {
        print('MigrationService: Custom professions already exist in Supabase, skipping migration');
        return;
      }
      
      // Load from local storage
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('custom_professions');
      
      if (jsonString != null) {
        final json = jsonDecode(jsonString);
        CustomProfessionManager.fromJson(json);
        
        // Save to Supabase
        final List<Map<String, dynamic>> professionsToInsert = [];
        for (final profession in CustomProfessionManager.allCustomProfessions) {
          professionsToInsert.add({
            'user_id': userId,
            'profession_id': profession.id,
            'name': profession.name,
            'short_name': profession.shortName,
            'default_day_visible': profession.defaultDayVisible,
            'default_night_visible': profession.defaultNightVisible,
            'default_rows': profession.defaultRows,
          });
        }
        
        if (professionsToInsert.isNotEmpty) {
          await _supabase.from('custom_professions').insert(professionsToInsert);
          print('MigrationService: Migrated ${professionsToInsert.length} custom professions to Supabase');
        }
      }
    } catch (e) {
      print('MigrationService: Error migrating custom professions: $e');
    }
  }
  
  /// Migrate vacation data from local storage to Supabase
  static Future<void> migrateVacationData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      // Check if already migrated
      final existingData = await _supabase
          .from('vacation_absences')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      
      if (existingData.isNotEmpty) {
        print('MigrationService: Vacation data already exists in Supabase, skipping migration');
        return;
      }
      
      // Load from local storage
      final prefs = await SharedPreferences.getInstance();
      final vacationsJson = prefs.getString('vacations');
      
      if (vacationsJson != null) {
        final List<dynamic> vacationsList = json.decode(vacationsJson);
        final vacations = vacationsList.map((v) => VacationAbsence.fromJson(v)).toList();
        
        // Save to Supabase
        final List<Map<String, dynamic>> vacationsToInsert = [];
        for (final vacation in vacations) {
          vacationsToInsert.add({
            'user_id': userId,
            'vacation_id': vacation.id,
            'employee_id': vacation.employeeId,
            'employee_name': vacation.employeeName,
            'start_date': vacation.startDate.toIso8601String().split('T')[0], // Date only
            'end_date': vacation.endDate.toIso8601String().split('T')[0], // Date only
            'type': vacation.type.name,
            'notes': vacation.notes,
          });
        }
        
        if (vacationsToInsert.isNotEmpty) {
          await _supabase.from('vacation_absences').insert(vacationsToInsert);
          print('MigrationService: Migrated ${vacationsToInsert.length} vacation records to Supabase');
        }
      }
    } catch (e) {
      print('MigrationService: Error migrating vacation data: $e');
    }
  }
  
  /// Migrate profession settings from local storage to Supabase
  static Future<void> migrateProfessionSettings() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      // Check if already migrated by looking for any week settings
      final existingData = await _supabase
          .from('week_settings')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      
      if (existingData.isNotEmpty) {
        print('MigrationService: Week settings already exist in Supabase, skipping migration');
        return;
      }
      
      // Load from local storage
      final prefs = await SharedPreferences.getInstance();
      final dayProfessionsJson = prefs.getString('week_day_professions');
      final nightProfessionsJson = prefs.getString('week_night_professions');
      final dayRowsJson = prefs.getString('week_day_rows');
      final nightRowsJson = prefs.getString('week_night_rows');
      
      List<Map<String, dynamic>> settingsToInsert = [];
      
      // Process day profession settings
      if (dayProfessionsJson != null) {
        final Map<String, dynamic> data = json.decode(dayProfessionsJson);
        for (final entry in data.entries) {
          final week = int.parse(entry.key);
          final Map<String, dynamic> profs = entry.value;
          
          for (final profEntry in profs.entries) {
            settingsToInsert.add({
              'user_id': userId,
              'week_number': week,
              'shift_type': 'day',
              'profession': profEntry.key,
              'is_visible': profEntry.value,
              'row_count': 1, // Default, will be updated with row data
            });
          }
        }
      }
      
      // Process night profession settings
      if (nightProfessionsJson != null) {
        final Map<String, dynamic> data = json.decode(nightProfessionsJson);
        for (final entry in data.entries) {
          final week = int.parse(entry.key);
          final Map<String, dynamic> profs = entry.value;
          
          for (final profEntry in profs.entries) {
            settingsToInsert.add({
              'user_id': userId,
              'week_number': week,
              'shift_type': 'night',
              'profession': profEntry.key,
              'is_visible': profEntry.value,
              'row_count': 1, // Default, will be updated with row data
            });
          }
        }
      }
      
      // Update row counts from day rows data
      if (dayRowsJson != null) {
        final Map<String, dynamic> data = json.decode(dayRowsJson);
        for (final entry in data.entries) {
          final week = int.parse(entry.key);
          final Map<String, dynamic> rows = entry.value;
          
          for (final rowEntry in rows.entries) {
            // Find matching setting and update row count
            for (var setting in settingsToInsert) {
              if (setting['week_number'] == week && 
                  setting['shift_type'] == 'day' && 
                  setting['profession'] == rowEntry.key) {
                setting['row_count'] = rowEntry.value;
                break;
              }
            }
          }
        }
      }
      
      // Update row counts from night rows data
      if (nightRowsJson != null) {
        final Map<String, dynamic> data = json.decode(nightRowsJson);
        for (final entry in data.entries) {
          final week = int.parse(entry.key);
          final Map<String, dynamic> rows = entry.value;
          
          for (final rowEntry in rows.entries) {
            // Find matching setting and update row count
            for (var setting in settingsToInsert) {
              if (setting['week_number'] == week && 
                  setting['shift_type'] == 'night' && 
                  setting['profession'] == rowEntry.key) {
                setting['row_count'] = rowEntry.value;
                break;
              }
            }
          }
        }
      }
      
      if (settingsToInsert.isNotEmpty) {
        await _supabase.from('week_settings').insert(settingsToInsert);
        print('MigrationService: Migrated ${settingsToInsert.length} week settings to Supabase');
      }
    } catch (e) {
      print('MigrationService: Error migrating profession settings: $e');
    }
  }
  
  /// Run complete migration process
  static Future<void> runMigration() async {
    try {
      if (await isMigrationCompleted()) {
        print('MigrationService: Migration already completed, skipping');
        return;
      }
      
      print('MigrationService: Starting migration process...');
      
      await migrateCustomProfessions();
      await migrateVacationData();
      await migrateProfessionSettings();
      
      await markMigrationCompleted();
      
      print('MigrationService: ✅ Migration completed successfully!');
    } catch (e) {
      print('MigrationService: ❌ Migration failed: $e');
    }
  }
} 