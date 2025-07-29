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

  // 🔥 SHARED CUSTOM PROFESSION NAMES - Accessible from all views
  static final Map<EmployeeRole, String> customProfessionNames = {
    EmployeeRole.tj: 'TJ',
    EmployeeRole.varu1: 'VARU1',
    EmployeeRole.varu2: 'VARU2',
    EmployeeRole.varu3: 'VARU3',
    EmployeeRole.varu4: 'VARU4',
    EmployeeRole.pasta1: 'PASTA1',
    EmployeeRole.pasta2: 'PASTA2',
    EmployeeRole.ict: 'ICT',
    EmployeeRole.tarvike: 'TARVIKE',
    EmployeeRole.pora: 'PORA',
    EmployeeRole.huolto: 'HUOLTO',
    // Default names for configurable slots
    EmployeeRole.slot1: 'SLOT1',
    EmployeeRole.slot2: 'SLOT2',
    EmployeeRole.slot3: 'SLOT3',
    EmployeeRole.slot4: 'SLOT4',
    EmployeeRole.slot5: 'SLOT5',
    EmployeeRole.slot6: 'SLOT6',
    EmployeeRole.slot7: 'SLOT7',
    EmployeeRole.slot8: 'SLOT8',
    EmployeeRole.slot9: 'SLOT9',
    EmployeeRole.slot10: 'SLOT10',
  };

  static final Map<EmployeeRole, String> customProfessionFullNames = {
    EmployeeRole.tj: 'Työnjohtaja',
    EmployeeRole.varu1: 'Varustaja 1',
    EmployeeRole.varu2: 'Varustaja 2',
    EmployeeRole.varu3: 'Varustaja 3',
    EmployeeRole.varu4: 'Varustaja 4',
    EmployeeRole.pasta1: 'Pasta 1',
    EmployeeRole.pasta2: 'Pasta 2',
    EmployeeRole.ict: 'ICT',
    EmployeeRole.tarvike: 'Tarvike',
    EmployeeRole.pora: 'Pora',
    EmployeeRole.huolto: 'Huolto',
    // Default full names for configurable slots
    EmployeeRole.slot1: 'Custom Profession 1',
    EmployeeRole.slot2: 'Custom Profession 2',
    EmployeeRole.slot3: 'Custom Profession 3',
    EmployeeRole.slot4: 'Custom Profession 4',
    EmployeeRole.slot5: 'Custom Profession 5',
    EmployeeRole.slot6: 'Custom Profession 6',
    EmployeeRole.slot7: 'Custom Profession 7',
    EmployeeRole.slot8: 'Custom Profession 8',
    EmployeeRole.slot9: 'Custom Profession 9',
    EmployeeRole.slot10: 'Custom Profession 10',
  };

  // 🔥 ACTIVE PROFESSION SLOTS - Track which configurable slots are enabled
  static final Set<EmployeeRole> activeProfessionSlots = <EmployeeRole>{};
  
  /// Get role display name using custom names
  static String getRoleDisplayName(EmployeeRole role) {
    return customProfessionNames[role] ?? role.name.toUpperCase();
  }

  /// Get compact role name for calendar display
  static String getCompactRoleName(EmployeeRole role) {
    final customName = customProfessionNames[role];
    if (customName != null) {
      // For custom names, allow up to 8 characters
      if (customName.length <= 8) return customName;
      // If longer than 8 chars, try to abbreviate
      if (customName.contains(' ')) {
        final abbreviated = customName.split(' ').map((word) => word.isNotEmpty ? word[0] : '').join('').toUpperCase();
        return abbreviated.length <= 8 ? abbreviated : abbreviated.substring(0, 8);
      }
      return customName.substring(0, 8);
    }
    
    // Default compact names
    switch (role) {
      case EmployeeRole.tj: return 'TJ';
      case EmployeeRole.varu1: return 'V1';
      case EmployeeRole.varu2: return 'V2';
      case EmployeeRole.varu3: return 'V3';
      case EmployeeRole.varu4: return 'V4';
      case EmployeeRole.pasta1: return 'P1';
      case EmployeeRole.pasta2: return 'P2';
      case EmployeeRole.ict: return 'ICT';
      case EmployeeRole.tarvike: return 'TR';
      case EmployeeRole.pora: return 'PR';
      case EmployeeRole.huolto: return 'HU';
      case EmployeeRole.custom: return 'CU';
      case EmployeeRole.slot1:
      case EmployeeRole.slot2:
      case EmployeeRole.slot3:
      case EmployeeRole.slot4:
      case EmployeeRole.slot5:
      case EmployeeRole.slot6:
      case EmployeeRole.slot7:
      case EmployeeRole.slot8:
      case EmployeeRole.slot9:
      case EmployeeRole.slot10:
        return role.name.substring(4).toUpperCase(); // "slot1" -> "1"
    }
  }

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