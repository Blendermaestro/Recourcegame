import 'package:calendar_app/services/shared_data_service.dart';
import 'package:calendar_app/models/employee.dart';

/// 🔥 SHARED DATA FIX SERVICE - Methods for multi-user shared data
/// This service uses the new shared database tables instead of per-user tables
class SharedDataFixService {
  
  // 🔒 SHARED WEEK LOCK METHODS
  
  /// Load week lock state from shared database
  static Future<bool> loadWeekLockState(int weekNumber) async {
    try {
      final response = await SharedDataService.supabase
          .from('week_lock_states')
          .select('is_locked')
          .eq('week_number', weekNumber)
          .maybeSingle();
      
      return response?['is_locked'] as bool? ?? false;
    } catch (e) {
      print('SharedDataFixService: ❌ Error loading lock state: $e');
      return false;
    }
  }
  
  /// Save week lock state to shared database
  static Future<void> saveWeekLockState(int weekNumber, bool isLocked) async {
    try {
      final currentUser = SharedDataService.supabase.auth.currentUser;
      
      if (isLocked) {
        // Insert or update lock state
        await SharedDataService.supabase
            .from('week_lock_states')
            .upsert({
              'week_number': weekNumber,
              'is_locked': true,
              'locked_by': currentUser?.id,
              'locked_at': DateTime.now().toIso8601String(),
            });
      } else {
        // Remove lock state
        await SharedDataService.supabase
            .from('week_lock_states')
            .delete()
            .eq('week_number', weekNumber);
      }
      
      print('SharedDataFixService: ✅ Saved lock state for week $weekNumber: $isLocked');
    } catch (e) {
      print('SharedDataFixService: ❌ Error saving lock state: $e');
      rethrow;
    }
  }
  
  // 🔧 SHARED PROFESSION SETTINGS METHODS
  
  /// Save profession settings to shared database  
  static Future<void> saveSharedProfessionSettings({
    required int weekNumber,
    required Map<EmployeeRole, bool> dayProfessions,
    required Map<EmployeeRole, bool> nightProfessions,
    required Map<EmployeeRole, int> dayRows,
    required Map<EmployeeRole, int> nightRows,
  }) async {
    try {
      final userId = SharedDataService.supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      List<Map<String, dynamic>> settingsToUpsert = [];

      // Day shift settings (skip custom professions - they have their own table)
      for (final entry in dayProfessions.entries) {
        if (entry.key != EmployeeRole.custom) {
          settingsToUpsert.add({
            'week_number': weekNumber,
            'shift_type': 'day',
            'profession': entry.key.name,
            'is_visible': entry.value,
            'row_count': dayRows[entry.key] ?? 1,
            'last_updated_by': userId,
          });
        }
      }

      // Night shift settings (skip custom professions - they have their own table)
      for (final entry in nightProfessions.entries) {
        if (entry.key != EmployeeRole.custom) {
          settingsToUpsert.add({
            'week_number': weekNumber,
            'shift_type': 'night',
            'profession': entry.key.name,
            'is_visible': entry.value,
            'row_count': nightRows[entry.key] ?? 1,
            'last_updated_by': userId,
          });
        }
      }

      if (settingsToUpsert.isNotEmpty) {
        // 🔥 SHARED DATA: Delete existing settings first, then insert new ones
        await SharedDataService.supabase
            .from('shared_week_settings')
            .delete()
            .eq('week_number', weekNumber);
            
        // Insert fresh shared settings
        await SharedDataService.supabase
            .from('shared_week_settings')
            .insert(settingsToUpsert);
      }
      
      print('SharedDataFixService: ✅ Saved shared profession settings for week $weekNumber');
    } catch (e) {
      print('SharedDataFixService: ❌ Error saving shared profession settings: $e');
      rethrow;
    }
  }
  
  /// Load profession settings from shared database
  static Future<Map<String, dynamic>> loadSharedProfessionSettings(int weekNumber) async {
    try {
      final response = await SharedDataService.supabase
          .from('shared_week_settings')
          .select()
          .eq('week_number', weekNumber);

      final dayProfessions = <EmployeeRole, bool>{};
      final nightProfessions = <EmployeeRole, bool>{};
      final dayRows = <EmployeeRole, int>{};
      final nightRows = <EmployeeRole, int>{};

      for (final setting in response) {
        final profession = _stringToEmployeeRole(setting['profession']);
        if (profession != null) {
          final isVisible = setting['is_visible'] ?? true;
          final rowCount = setting['row_count'] ?? 1;
          
          if (setting['shift_type'] == 'day') {
            dayProfessions[profession] = isVisible;
            dayRows[profession] = rowCount;
          } else if (setting['shift_type'] == 'night') {
            nightProfessions[profession] = isVisible;
            nightRows[profession] = rowCount;
          }
        }
      }

      print('SharedDataFixService: ✅ Loaded shared profession settings for week $weekNumber');
      
      return {
        'dayProfessions': dayProfessions,
        'nightProfessions': nightProfessions,
        'dayRows': dayRows,
        'nightRows': nightRows,
      };
    } catch (e) {
      print('SharedDataFixService: ❌ Error loading shared profession settings: $e');
      return {};
    }
  }
  
  // Helper method to convert string to EmployeeRole
  static EmployeeRole? _stringToEmployeeRole(String roleString) {
    try {
      return EmployeeRole.values.firstWhere((role) => role.name == roleString);
    } catch (e) {
      return null;
    }
  }
} 