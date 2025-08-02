import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/vacation_absence.dart';
import '../services/shared_data_service.dart';
import '../services/shared_assignment_data.dart';
import '../services/shared_assignment_data.dart';

class VacationManager {
  static final List<VacationAbsence> _vacations = [];
  
  static List<VacationAbsence> get vacations => List.unmodifiable(_vacations);
  
  static Future<void> loadVacations() async {
    try {
      print('VacationManager: Loading vacations from Supabase...');
      
      // 🔥 NEW: Load from Supabase for shared access
      final response = await SharedDataService.supabase
          .from('vacation_absences')
          .select()
          .order('start_date', ascending: false);
      
      _vacations.clear();
      _vacations.addAll(
        response.map((json) => VacationAbsence.fromSupabase(json)).toList()
      );
      
      print('VacationManager: ✅ Loaded ${_vacations.length} vacation/absence records from Supabase');
      if (_vacations.isNotEmpty) {
        for (final vacation in _vacations.take(3)) {
          print('VacationManager: - ${vacation.id}: ${vacation.type.name} for ${vacation.employeeId}');
        }
      }
      
      // 🔥 MIGRATION: Also load old SharedPreferences data if exists
      await _migrateOldVacationData();
      
    } catch (e) {
      print('VacationManager: ❌ Error loading vacations: $e');
      print('VacationManager: Stack trace: ${StackTrace.current}');
      // Fallback to SharedPreferences if Supabase fails
      await _loadFromSharedPreferences();
    }
  }
  
  // 🔥 MIGRATION: Move old data to Supabase
  static Future<void> _migrateOldVacationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vacationsJson = prefs.getString('vacations');
      
      if (vacationsJson != null) {
        final List<dynamic> vacationsList = json.decode(vacationsJson);
        final oldVacations = vacationsList.map((v) => VacationAbsence.fromJson(v)).toList();
        
        for (final vacation in oldVacations) {
          // Check if this vacation already exists in Supabase
          final existing = _vacations.where((v) => v.id == vacation.id).firstOrNull;
          if (existing == null) {
            await SharedDataService.saveVacation(vacation);
            _vacations.add(vacation);
            print('VacationManager: Migrated vacation ${vacation.id} to Supabase');
          }
        }
        
        // Clear old data after successful migration
        await prefs.remove('vacations');
        print('VacationManager: Migration complete, cleared old SharedPreferences data');
      }
    } catch (e) {
      print('VacationManager: Error during migration: $e');
    }
  }
  
  // 🔥 FALLBACK: Load from SharedPreferences if Supabase fails
  static Future<void> _loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vacationsJson = prefs.getString('vacations');
      
      if (vacationsJson != null) {
        final List<dynamic> vacationsList = json.decode(vacationsJson);
        _vacations.clear();
        _vacations.addAll(vacationsList.map((v) => VacationAbsence.fromJson(v)).toList());
        print('VacationManager: Fallback - Loaded ${_vacations.length} records from SharedPreferences');
      }
    } catch (e) {
      print('VacationManager: Error loading from SharedPreferences: $e');
    }
  }
  
  static Future<void> saveVacations() async {
    // 🔥 DEPRECATED: Individual save operations now use Supabase directly
    // This method kept for compatibility but does nothing
    print('VacationManager: saveVacations() deprecated - use addVacation/removeVacation instead');
  }
  
  static Future<void> addVacation(VacationAbsence vacation) async {
    try {
      print('VacationManager: 🔄 Saving vacation ${vacation.id} to Supabase...');
      
      // 🔥 NEW: Save to Supabase for shared access
      await SharedDataService.saveVacation(vacation);
      
      // 🔥 VACATION OVERRIDE: Remove conflicting work assignments
      await _removeConflictingAssignments(vacation);
      
      // Add to local cache
      _vacations.add(vacation);
      
      print('VacationManager: ✅ Added vacation ${vacation.id} to Supabase and local cache');
      print('VacationManager: Total vacations now: ${_vacations.length}');
      
    } catch (e) {
      print('VacationManager: ❌ Error adding vacation: $e');
      print('VacationManager: Stack trace: ${StackTrace.current}');
      throw e;
    }
  }
  
  static Future<void> removeVacation(String vacationId) async {
    try {
      // 🔥 NEW: Delete from Supabase for shared access
      await SharedDataService.deleteVacation(vacationId);
      _vacations.removeWhere((v) => v.id == vacationId);
      print('VacationManager: Removed vacation $vacationId from Supabase');
    } catch (e) {
      print('VacationManager: Error removing vacation: $e');
      throw e;
    }
  }
  
  static List<VacationAbsence> getEmployeeVacations(String employeeId) {
    return _vacations.where((v) => v.employeeId == employeeId).toList();
  }
  
  static VacationAbsence? getActiveVacation(String employeeId, DateTime date) {
    return _vacations
        .where((v) => v.employeeId == employeeId && v.isActiveOn(date))
        .firstOrNull;
  }
  
  static bool isEmployeeOnVacation(String employeeId, DateTime date) {
    return getActiveVacation(employeeId, date) != null;
  }
  
  static List<VacationAbsence> getCurrentVacations(String employeeId) {
    final now = DateTime.now();
    return _vacations
        .where((v) => v.employeeId == employeeId && 
                      (v.endDate.isAfter(now) || v.endDate.isAtSameMomentAs(now)))
        .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  static Future<void> clearAll() async {
    _vacations.clear();
    await saveVacations();
    print('VacationManager: All vacation data cleared');
  }
  
  /// 🔥 VACATION OVERRIDE: Remove work assignments that conflict with vacation dates
  static Future<void> _removeConflictingAssignments(VacationAbsence vacation) async {
    try {
      print('VacationManager: 🔍 Checking for conflicting work assignments for ${vacation.employeeId}...');
      
      // Get all assignments for current year
      final currentYear = SharedAssignmentData.currentYear;
      final allAssignments = SharedAssignmentData.getAssignmentsForYear(currentYear);
      final assignmentsToRemove = <String>[];
      
      // Check each assignment for conflicts with vacation dates
      for (final entry in allAssignments.entries) {
        final employee = entry.value;
        if (employee.id != vacation.employeeId) continue; // Only check this employee's assignments
        
        // Parse assignment key to get the date
        final assignmentKey = entry.key;
        final parts = assignmentKey.split('-');
        if (parts.length >= 3) {
          final weekNumber = int.tryParse(parts[0]);
          final dayIndex = int.tryParse(parts[2]);
          
          if (weekNumber != null && dayIndex != null) {
            // Calculate the actual date of this assignment
            final assignmentDate = _getDateFromWeekAndDay(weekNumber, dayIndex, currentYear);
            
            // Check if assignment date falls within vacation period
            if (vacation.isActiveOn(assignmentDate)) {
              assignmentsToRemove.add(assignmentKey);
              print('VacationManager: 📅 Found conflicting assignment on ${assignmentDate.toString().split(' ')[0]} (Week $weekNumber, Day $dayIndex)');
            }
          }
        }
      }
      
      // Remove conflicting assignments
      if (assignmentsToRemove.isNotEmpty) {
        for (final key in assignmentsToRemove) {
          SharedAssignmentData.removeAssignmentForYear(currentYear, key);
        }
        
        // Force refresh to update UI
        SharedAssignmentData.forceRefresh();
        
        print('VacationManager: ✅ Removed ${assignmentsToRemove.length} conflicting work assignments for vacation ${vacation.id}');
      } else {
        print('VacationManager: ✅ No conflicting work assignments found for vacation ${vacation.id}');
      }
      
    } catch (e) {
      print('VacationManager: ❌ Error removing conflicting assignments: $e');
      // Don't throw - vacation should still be saved even if assignment removal fails
    }
  }
  
  /// Helper: Get actual date from week number and day index
  static DateTime _getDateFromWeekAndDay(int weekNumber, int dayIndex, int year) {
    // Get first day of the year
    final firstDayOfYear = DateTime(year, 1, 1);
    
    // Calculate first Monday of the year (ISO week date standard)
    final firstMonday = firstDayOfYear.add(Duration(days: (8 - firstDayOfYear.weekday) % 7));
    
    // Calculate the target date
    final targetDate = firstMonday.add(Duration(days: (weekNumber - 1) * 7 + dayIndex));
    
    return targetDate;
  }
  
  static Future<void> _removeConflictingAssignments(VacationAbsence vacation) async {
    print('VacationManager: TODO - Remove conflicting assignments for ${vacation.employeeId}');
  }
} 