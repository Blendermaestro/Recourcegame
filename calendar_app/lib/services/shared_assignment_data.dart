import 'package:calendar_app/models/employee.dart';
import 'package:flutter/foundation.dart';

/// 🔥 SHARED ASSIGNMENT DATA - Single source of truth for both WeekView and YearView
class SharedAssignmentData {
  // Shared assignment data between all views
  static final Map<String, Employee> assignments = {};
  
  // Callbacks for when data changes
  static final List<VoidCallback> _changeListeners = [];
  
  // Shared profession settings between all views  
  static final Map<int, Map<EmployeeRole, bool>> weekDayShiftProfessions = {};
  static final Map<int, Map<EmployeeRole, bool>> weekNightShiftProfessions = {};
  static final Map<int, Map<EmployeeRole, int>> weekDayShiftRows = {};
  static final Map<int, Map<EmployeeRole, int>> weekNightShiftRows = {};
  
  /// Clear all data (useful for logout/reset)
  static void clearAll() {
    assignments.clear();
    weekDayShiftProfessions.clear();
    weekNightShiftProfessions.clear();
    weekDayShiftRows.clear();
    weekNightShiftRows.clear();
    print('SharedAssignmentData - Cleared all data');
  }
  
  /// Clear assignments for a specific week
  static void clearWeek(int weekNumber, {bool notifyListeners = true}) {
    final beforeCount = assignments.length;
    assignments.removeWhere((key, value) {
      final parts = key.split('-');
      if (parts.isNotEmpty) {
        final week = int.tryParse(parts[0]);
        return week == weekNumber;
      }
      return false;
    });
    final clearedCount = beforeCount - assignments.length;
    print('SharedAssignmentData - Cleared week $weekNumber: removed $clearedCount assignments, ${assignments.length} remaining');
    
    // Notify listeners that data has changed (unless suppressed)
    if (clearedCount > 0 && notifyListeners) {
      _notifyListeners();
    }
  }
  
  /// Get assignments count for debugging
  static int get assignmentCount => assignments.length;
  
  /// Get assignment count for a specific week
  static int getWeekAssignmentCount(int weekNumber) {
    return assignments.entries.where((entry) {
      final parts = entry.key.split('-');
      if (parts.isNotEmpty) {
        final week = int.tryParse(parts[0]);
        return week == weekNumber;
      }
      return false;
    }).length;
  }
  
  /// Add listener for data changes
  static void addListener(VoidCallback listener) {
    _changeListeners.add(listener);
  }
  
  /// Remove listener for data changes
  static void removeListener(VoidCallback listener) {
    _changeListeners.remove(listener);
  }
  
  /// Notify all listeners that data has changed
  static void _notifyListeners() {
    for (final listener in _changeListeners) {
      try {
        listener();
      } catch (e) {
        print('SharedAssignmentData - Error notifying listener: $e');
      }
    }
  }
  
  /// Update assignments for a specific week and notify listeners
  static void updateAssignmentsForWeek(int weekNumber, Map<String, Employee> newAssignments) {
    // First, clear existing assignments for this week (without notifying)
    clearWeek(weekNumber, notifyListeners: false);
    
    // Then add the new assignments (they should all be for this week)
    assignments.addAll(newAssignments);
    print('SharedAssignmentData - Updated week $weekNumber with ${newAssignments.length} assignments (Total: ${assignmentCount})');
    
    // Notify listeners once after both clear and add operations
    _notifyListeners();
  }
  
  /// Update assignments and notify listeners (deprecated - use updateAssignmentsForWeek)
  static void updateAssignments(Map<String, Employee> newAssignments) {
    assignments.addAll(newAssignments);
    _notifyListeners();
  }
  
  /// Force notify all listeners (useful for view switching)
  static void forceRefresh() {
    _notifyListeners();
    print('SharedAssignmentData - Forced refresh with ${assignmentCount} assignments');
  }
} 