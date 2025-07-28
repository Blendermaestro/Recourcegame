import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calendar_app/models/employee.dart';
import 'dart:convert';

// Helper functions for enum conversion
String _enumToString(dynamic enumValue) {
  if (enumValue == null) return '';
  return enumValue.toString().split('.').last;
}

EmployeeRole? _stringToEmployeeRole(String value) {
  try {
    return EmployeeRole.values.firstWhere(
      (e) => _enumToString(e) == value,
      orElse: () => throw StateError('Not found'),
    );
  } catch (e) {
    print('SharedDataService - Failed to parse EmployeeRole: $value');
    return null;
  }
}

class SharedDataService {
  static final _supabase = Supabase.instance.client;
  
  // Public access to Supabase client for batch operations
  static SupabaseClient get supabase => _supabase;

  // EMPLOYEES - Shared across all users
  static Future<List<Employee>> loadEmployees() async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .limit(1000); // Remove user_id filter for shared data
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Employee.fromSupabase(json)).toList();
    } catch (e) {
      print('Error loading employees: $e');
      return [];
    }
  }

  static Future<void> saveEmployee(Employee employee) async {
    try {
      await _supabase.from('employees').upsert({
        'id': employee.id,
        'name': employee.name,
        'category': employee.category.name,
        'type': employee.type.name, 
        'role': employee.role.name,
        'shift_cycle': employee.shiftCycle.name,
        'user_id': _supabase.auth.currentUser?.id, // Still track who added it
      });
      print('Employee saved: ${employee.name}');
    } catch (e) {
      print('Error saving employee: $e');
      throw e;
    }
  }

  static Future<void> deleteEmployee(String employeeId) async {
    try {
      await _supabase
          .from('employees')
          .delete()
          .eq('id', employeeId);
      print('Employee deleted: $employeeId');
    } catch (e) {
      print('Error deleting employee: $e');
      throw e;
    }
  }

  // WORK ASSIGNMENTS - Load and convert to view format
  // PROFESSION SETTINGS - Cloud storage methods
  static Future<void> saveProfessionSettings({
    required int weekNumber,
    required Map<EmployeeRole, bool> dayProfessions,
    required Map<EmployeeRole, bool> nightProfessions,
    required Map<EmployeeRole, int> dayRows,
    required Map<EmployeeRole, int> nightRows,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      List<Map<String, dynamic>> settingsToUpsert = [];

      // Day shift settings
      for (final entry in dayProfessions.entries) {
        settingsToUpsert.add({
          'user_id': userId,
          'week_number': weekNumber,
          'shift_type': 'day',
          'profession': entry.key.name,
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
          'profession': entry.key.name,
          'is_visible': entry.value,
          'row_count': nightRows[entry.key] ?? 1,
        });
      }

      if (settingsToUpsert.isNotEmpty) {
        await _supabase
            .from('week_settings')
            .upsert(settingsToUpsert, onConflict: 'user_id,week_number,shift_type,profession');
      }
      
      print('SharedDataService: Saved profession settings for week $weekNumber');
    } catch (e) {
      print('SharedDataService: Error saving profession settings: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> loadProfessionSettings(int weekNumber) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('week_settings')
          .select()
          .eq('user_id', userId)
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

      print('SharedDataService: Loaded profession settings for week $weekNumber');
      
      return {
        'dayProfessions': dayProfessions,
        'nightProfessions': nightProfessions,
        'dayRows': dayRows,
        'nightRows': nightRows,
      };
    } catch (e) {
      print('SharedDataService: Error loading profession settings: $e');
      return {};
    }
  }

  static Future<Map<String, Employee>> loadAssignments(int weekNumber) async {
    try {
      // 🔥 SHARED DATA - No user authentication required for viewing
      
      // Load assignments, employees, and week settings in parallel
      final assignmentsFuture = _supabase
          .from('work_assignments')
          .select('*, employees(*)')
          .eq('week_number', weekNumber); // 🔥 SHARED: No user filter
      
      final daySettingsFuture = _supabase
          .from('week_settings')
          .select()
          .eq('week_number', weekNumber)
          .eq('shift_type', 'day');
          
      final nightSettingsFuture = _supabase
          .from('week_settings')
          .select()
          .eq('week_number', weekNumber)
          .eq('shift_type', 'night');

      final results = await Future.wait([
        assignmentsFuture,
        daySettingsFuture,
        nightSettingsFuture,
      ]);

      final assignments = results[0] as List<dynamic>;
      final daySettings = results[1] as List<dynamic>;
      final nightSettings = results[2] as List<dynamic>;

      // Create profession settings maps with defaults
      final Map<EmployeeRole, bool> dayProfessions = {};
      final Map<EmployeeRole, int> dayRows = {};
      final Map<EmployeeRole, bool> nightProfessions = {};
      final Map<EmployeeRole, int> nightRows = {};

      // Set default values for all professions
      for (final profession in EmployeeRole.values) {
        dayProfessions[profession] = true;
        dayRows[profession] = 1;
        nightProfessions[profession] = true;
        nightRows[profession] = 1;
      }

      // Load day settings
      for (final setting in daySettings) {
        try {
          final profession = _stringToEmployeeRole(setting['profession']);
          if (profession != null) {
            dayProfessions[profession] = setting['is_visible'] ?? true;
            dayRows[profession] = setting['row_count'] ?? 1;
          }
        } catch (e) {
          print('SharedDataService - Error parsing day setting: $e');
        }
      }

      // Load night settings
      for (final setting in nightSettings) {
        try {
          final profession = _stringToEmployeeRole(setting['profession']);
          if (profession != null) {
            nightProfessions[profession] = setting['is_visible'] ?? true;
            nightRows[profession] = setting['row_count'] ?? 1;
          }
        } catch (e) {
          print('SharedDataService - Error parsing night setting: $e');
        }
      }

      print('SharedDataService - Week $weekNumber: Day settings: ${daySettings.length}, Night settings: ${nightSettings.length}');

      // Convert assignments to view format
      final Map<String, Employee> convertedAssignments = {};
      
      print('SharedDataService - Converting ${assignments.length} raw assignments...');
      
      for (final assignment in assignments) {
        final employeeData = assignment['employees'];
        if (employeeData != null) {
          final employee = Employee.fromSupabase(employeeData);
          final lane = assignment['lane'] as int;
          final shiftTitle = assignment['shift_title'] as String;
          final dayIndex = assignment['day_index'] as int;
          
          // Convert lane back to profession + professionRow
          final professionInfo = _getAbsoluteLaneToProfession(
            lane, 
            shiftTitle, 
            shiftTitle.toLowerCase().contains('yö') ? nightProfessions : dayProfessions,
            shiftTitle.toLowerCase().contains('yö') ? nightRows : dayRows,
          );
          
          if (professionInfo != null) {
            final profession = professionInfo['profession'] as EmployeeRole;
            final professionString = _enumToString(profession);
            // Create key in the format expected by views: weekNumber-shiftTitle-day-profession-professionRow
            final key = '$weekNumber-$shiftTitle-$dayIndex-$professionString-${professionInfo['row']}';
            convertedAssignments[key] = employee;
            print('SharedDataService - Converted: lane $lane -> $professionString:${professionInfo['row']} -> key: $key');
          } else {
            print('SharedDataService - Failed to convert lane $lane for shift $shiftTitle');
          }
        }
      }
      
      print('SharedDataService - Loaded ${convertedAssignments.length} assignments for week $weekNumber');
      return convertedAssignments;
    } catch (e) {
      print('Error loading assignments: $e');
      return {};
    }
  }

  static Future<void> saveAssignment({
    required int weekNumber,
    required int dayIndex, 
    required String shiftTitle,
    required int lane,
    required Employee employee,
  }) async {
    try {
      await _supabase.from('work_assignments').upsert({
        'week_number': weekNumber,
        'day_index': dayIndex,
        'shift_type': shiftTitle.toLowerCase().contains('night') ? 'night' : 'day',
        'shift_title': shiftTitle,
        'lane': lane,
        'employee_id': employee.id,
        'user_id': _supabase.auth.currentUser?.id,
      });
    } catch (e) {
      print('Error saving assignment: $e');
      throw e;
    }
  }

  static Future<void> deleteAssignment({
    required int weekNumber,
    required int dayIndex,
    required String shiftTitle, 
    required int lane,
  }) async {
    try {
      await _supabase
          .from('work_assignments')
          .delete()
          .eq('week_number', weekNumber)
          .eq('day_index', dayIndex)
          .eq('shift_title', shiftTitle)
          .eq('lane', lane);
    } catch (e) {
      print('Error deleting assignment: $e');
      throw e;
    }
  }

  // CLEAR ALL DATA - For reset functionality
  static Future<void> clearAllData() async {
    try {
      // Delete all assignments
      await _supabase.from('work_assignments').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      
      // Delete all employees  
      await _supabase.from('employees').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      
      // Delete all week settings
      await _supabase.from('week_settings').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      
      print('All shared data cleared from database');
    } catch (e) {
      print('Error clearing data: $e');
      throw e;
    }
  }

  // Convert absolute lane back to profession + professionRow
  static Map<String, dynamic>? _getAbsoluteLaneToProfession(
    int absoluteLane, 
    String shiftTitle,
    Map<EmployeeRole, bool> professionVisibility,
    Map<EmployeeRole, int> professionRows,
  ) {
    final visibleProfessions = EmployeeRole.values
        .where((role) => professionVisibility[role] == true)
        .toList();
    
    int currentLane = 0;
    for (final profession in visibleProfessions) {
      final rows = professionRows[profession] ?? 1;
      
      if (absoluteLane >= currentLane && absoluteLane < currentLane + rows) {
        // Found the profession!
        final professionRow = absoluteLane - currentLane;
        return {
          'profession': profession,
          'row': professionRow,
        };
      }
      currentLane += rows;
    }
    
    // 🔥 HANDLE OUT-OF-RANGE LANES - Map to custom profession
    if (absoluteLane >= currentLane) {
      print('SharedDataService - Lane $absoluteLane out of range, mapping to custom:${absoluteLane - currentLane}');
      return {
        'profession': EmployeeRole.custom,
        'row': absoluteLane - currentLane,
      };
    }
    
    return null; // Invalid lane
  }
} 