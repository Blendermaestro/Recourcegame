import 'package:calendar_app/models/employee.dart';
import 'package:calendar_app/services/supabase_config.dart';
import 'package:calendar_app/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalendarDataService {
  static SupabaseClient get _client => SupabaseConfig.client;

  // Employee operations
  static Future<List<Employee>> getEmployees() async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('employees')
        .select()
        .eq('user_id', userId)
        .order('name');

    return response.map((json) => Employee.fromSupabase(json)).toList();
  }

  static Future<void> saveEmployee(Employee employee) async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('User not authenticated');

    final data = employee.toSupabase();
    data['user_id'] = userId;

    // Check if employee exists
    final existing = await _client
        .from('employees')
        .select('id')
        .eq('user_id', userId)
        .eq('id', employee.id)
        .maybeSingle();

    if (existing != null) {
      // Update
      await _client
          .from('employees')
          .update(data)
          .eq('id', employee.id)
          .eq('user_id', userId);
    } else {
      // Insert
      await _client.from('employees').insert(data);
    }
  }

  static Future<void> deleteEmployee(String employeeId) async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('User not authenticated');

    // Delete assignments first
    await _client
        .from('work_assignments')
        .delete()
        .eq('user_id', userId)
        .eq('employee_id', employeeId);

    // Then delete employee
    await _client
        .from('employees')
        .delete()
        .eq('id', employeeId)
        .eq('user_id', userId);
  }

  // Work assignment operations
  static Future<Map<String, Employee>> getAssignments(int weekNumber) async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('work_assignments')
        .select('*, employees(*)')
        .eq('user_id', userId)
        .eq('week_number', weekNumber);

    Map<String, Employee> assignments = {};
    
    for (final assignment in response) {
      final employeeData = assignment['employees'];
      if (employeeData != null) {
        final employee = Employee.fromSupabase(employeeData);
        final key = '${assignment['shift_title']}-${assignment['day_index']}-${assignment['lane']}';
        assignments[key] = employee;
      }
    }

    return assignments;
  }

  static Future<void> saveAssignment({
    required String employeeId,
    required int weekNumber,
    required int dayIndex,
    required String shiftTitle,
    required int lane,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('User not authenticated');

    final shiftType = shiftTitle.toLowerCase().contains('yö') ? 'night' : 'day';

    final data = {
      'user_id': userId,
      'employee_id': employeeId,
      'week_number': weekNumber,
      'day_index': dayIndex,
      'shift_type': shiftType,
      'lane': lane,
      'shift_title': shiftTitle,
    };

    await _client
        .from('work_assignments')
        .upsert(data, onConflict: 'user_id,week_number,day_index,shift_type,lane');
  }

  static Future<void> deleteAssignment({
    required int weekNumber,
    required int dayIndex,
    required String shiftTitle,
    required int lane,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('User not authenticated');

    final shiftType = shiftTitle.toLowerCase().contains('yö') ? 'night' : 'day';

    await _client
        .from('work_assignments')
        .delete()
        .eq('user_id', userId)
        .eq('week_number', weekNumber)
        .eq('day_index', dayIndex)
        .eq('shift_type', shiftType)
        .eq('lane', lane);
  }

  // Week settings operations
  static Future<Map<String, dynamic>> getWeekSettings(int weekNumber) async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('week_settings')
        .select()
        .eq('user_id', userId)
        .eq('week_number', weekNumber);

    Map<String, dynamic> settings = {
      'day_professions': <String, bool>{},
      'night_professions': <String, bool>{},
      'day_rows': <String, int>{},
      'night_rows': <String, int>{},
    };

    for (final setting in response) {
      final profession = setting['profession'];
      final shiftType = setting['shift_type'];
      final isVisible = setting['is_visible'] ?? true;
      final rowCount = setting['row_count'] ?? 1;

      if (shiftType == 'day') {
        settings['day_professions'][profession] = isVisible;
        settings['day_rows'][profession] = rowCount;
      } else {
        settings['night_professions'][profession] = isVisible;
        settings['night_rows'][profession] = rowCount;
      }
    }

    return settings;
  }

  static Future<void> saveWeekSettings({
    required int weekNumber,
    required Map<String, bool> dayProfessions,
    required Map<String, bool> nightProfessions,
    required Map<String, int> dayRows,
    required Map<String, int> nightRows,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('User not authenticated');

    List<Map<String, dynamic>> settingsToUpsert = [];

    // Day shift settings
    for (final entry in dayProfessions.entries) {
      settingsToUpsert.add({
        'user_id': userId,
        'week_number': weekNumber,
        'shift_type': 'day',
        'profession': entry.key,
        'is_visible': entry.value,
        'row_count': dayRows[entry.key] ?? 1,
      });
    }

    // Night shift settings
    for (final entry in nightProfessions.entries) {
      settingsToUpsert.add({
        'user_id': userId,
        'week_number': weekNumber,
        'shift_type': 'night',
        'profession': entry.key,
        'is_visible': entry.value,
        'row_count': nightRows[entry.key] ?? 1,
      });
    }

    if (settingsToUpsert.isNotEmpty) {
      await _client
          .from('week_settings')
          .upsert(settingsToUpsert, onConflict: 'user_id,week_number,shift_type,profession');
    }
  }

  // Initialize default settings for new users
  static Future<void> initializeDefaultSettings() async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('User not authenticated');

    // Check if user already has settings
    final existing = await _client
        .from('week_settings')
        .select('id')
        .eq('user_id', userId)
        .limit(1);

    if (existing.isNotEmpty) return; // User already has settings

    // Create default settings for all weeks (1-52)
    List<Map<String, dynamic>> defaultSettings = [];
    
    final defaultDayProfessions = {
      'tj': true,
      'varu1': true,
      'varu2': true,
      'varu3': true,
      'varu4': false,
      'pasta1': true,
      'pasta2': true,
      'ict': true,
      'tarvike': true,
      'pora': true,
      'huolto': true,
    };

    final defaultNightProfessions = {
      'tj': true,
      'varu1': true,
      'varu2': true,
      'varu3': true,
      'varu4': true,
      'pasta1': false,
      'pasta2': true,
      'ict': false,
      'tarvike': true,
      'pora': false,
      'huolto': false,
    };

    final defaultRows = {
      'tj': 1,
      'varu1': 2,
      'varu2': 2,
      'varu3': 2,
      'varu4': 2,
      'pasta1': 2,
      'pasta2': 2,
      'ict': 2,
      'tarvike': 1,
      'pora': 1,
      'huolto': 1,
    };

    for (int week = 1; week <= 52; week++) {
      // Day shift settings
      for (final entry in defaultDayProfessions.entries) {
        defaultSettings.add({
          'user_id': userId,
          'week_number': week,
          'shift_type': 'day',
          'profession': entry.key,
          'is_visible': entry.value,
          'row_count': defaultRows[entry.key] ?? 1,
        });
      }

      // Night shift settings
      for (final entry in defaultNightProfessions.entries) {
        defaultSettings.add({
          'user_id': userId,
          'week_number': week,
          'shift_type': 'night',
          'profession': entry.key,
          'is_visible': entry.value,
          'row_count': defaultRows[entry.key] ?? 1,
        });
      }
    }

    // Insert in batches to avoid hitting size limits
    const batchSize = 1000;
    for (int i = 0; i < defaultSettings.length; i += batchSize) {
      final batch = defaultSettings.sublist(
        i, 
        i + batchSize > defaultSettings.length ? defaultSettings.length : i + batchSize
      );
      await _client.from('week_settings').insert(batch);
    }
  }
} 