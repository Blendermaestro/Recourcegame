import 'package:calendar_app/data/default_employees.dart';
import 'package:calendar_app/models/employee.dart';
import 'package:calendar_app/models/vacation_absence.dart';
import 'package:calendar_app/data/vacation_manager.dart';
import 'package:calendar_app/views/employee_settings/employee_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:calendar_app/services/auth_service.dart';
import 'package:calendar_app/services/shared_data_service.dart';
import 'package:calendar_app/services/shared_assignment_data.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fullscreen_stub.dart' 
  if (dart.library.html) 'fullscreen_web.dart' 
  if (dart.library.io) 'fullscreen_mobile.dart' as fullscreen;

class DragState {
  final double startX;
  final double currentX;
  final bool isLeftResize;
  final int originalStartDay;
  final int originalDuration;
  
  DragState({
    required this.startX,
    required this.currentX,
    required this.isLeftResize,
    required this.originalStartDay,
    required this.originalDuration,
  });
}

class WeekView extends StatefulWidget {
  final int weekNumber;
  final Function(int)? onWeekChanged;
  final Function(String)? onViewChanged;
  const WeekView({super.key, required this.weekNumber, this.onWeekChanged, this.onViewChanged});

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  // 🔥 SHARED ASSIGNMENT DATA - Use truly shared data class with year awareness
  Map<String, Employee> get _assignments => SharedAssignmentData.getAssignmentsForYear(_currentYear);
  
  Map<int, Map<EmployeeRole, bool>> get _weekDayShiftProfessions => SharedAssignmentData.weekDayShiftProfessions;
  Map<int, Map<EmployeeRole, bool>> get _weekNightShiftProfessions => SharedAssignmentData.weekNightShiftProfessions;
  Map<int, Map<EmployeeRole, int>> get _weekDayShiftRows => SharedAssignmentData.weekDayShiftRows;
  Map<int, Map<EmployeeRole, int>> get _weekNightShiftRows => SharedAssignmentData.weekNightShiftRows;

  // 🔥 USE SHARED PROFESSION DATA - All profession customization moved to SharedAssignmentData
  Map<EmployeeRole, String> get _customProfessionNames => SharedAssignmentData.customProfessionNames;
  Map<EmployeeRole, String> get _customProfessionFullNames => SharedAssignmentData.customProfessionFullNames;
  Set<EmployeeRole> get _activeProfessionSlots => SharedAssignmentData.activeProfessionSlots;
  
  // Collapsible employee groups
  final Map<EmployeeCategory, bool> _collapsedGroups = {
    EmployeeCategory.ab: false,
    EmployeeCategory.cd: false,
    EmployeeCategory.huolto: false,
    EmployeeCategory.sijainen: false,
  };

  // Toggle for hiding worker section
  bool _showWorkerSection = true;
  
  // Current year for display
  int _currentYear = 2025;
  
  // Tab state - 0 for day shift, 1 for night shift
  int _currentTabIndex = 0;
  
  // 🔥 FIXED RESIZE SYSTEM - No more key mismatches or blocking saves
  String? _resizeModeBlockKey; // Format: "employeeId-shiftTitle-profession-professionRow"
  Map<String, DragState>? _dragStates;
  Map<String, dynamic>? _dragOriginalAssignment;
  
  // 🔥 DEBOUNCED CLOUD SAVING - No more blocking UI
  Timer? _saveDebounceTimer;
  bool _hasPendingChanges = false;
  bool _isDragActive = false; // Protect drag states during saves
  bool _hasLoadedOnce = false; // Track if we've loaded assignments at least once
  
  @override
  void initState() {
    super.initState();
    
    // 🧹 PERFORMANCE: Cleanup expired cache on startup
    cleanupExpiredCache();
    
    // FORCE INITIALIZE PROFESSION SETTINGS FOR CURRENT WEEK IMMEDIATELY
    if (!_weekDayShiftProfessions.containsKey(widget.weekNumber)) {
      _weekDayShiftProfessions[widget.weekNumber] = Map.from(_getDefaultDayShiftProfessions());
    }
    if (!_weekNightShiftProfessions.containsKey(widget.weekNumber)) {
      _weekNightShiftProfessions[widget.weekNumber] = Map.from(_getDefaultNightShiftProfessions());
    }
    if (!_weekDayShiftRows.containsKey(widget.weekNumber)) {
      _weekDayShiftRows[widget.weekNumber] = Map.from(_getDefaultDayShiftRows());
    }
    if (!_weekNightShiftRows.containsKey(widget.weekNumber)) {
      _weekNightShiftRows[widget.weekNumber] = Map.from(_getDefaultNightShiftRows());
    }
    
    // Listen for assignment data changes
    SharedAssignmentData.addListener(_onAssignmentDataChanged);
    
    // 🔥 LISTEN FOR YEAR CHANGES FROM OTHER VIEWS
    SharedAssignmentData.addYearChangeListener(_onYearChanged);
    
    _loadCurrentYear(); // Load the selected year
    _clearOldDataOnFirstRun(); // Clear old data during migration
    _loadCustomProfessions(); // Load custom professions first
    _loadProfessionNames(); // Load custom profession names
    _loadEmployees();
    _loadAssignments(); // LOAD ASSIGNMENTS FROM SUPABASE
    _loadProfessionSettings(); // LOAD GLOBAL PROFESSION SETTINGS
    VacationManager.loadVacations(); // Load vacation data
    
    // 🔥 FIX LOADING TIMING - Force a proper refresh after everything is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        SharedAssignmentData.forceRefresh();
        setState(() {});
      }
    });
    
    // 🔥 ADD PAGE UNLOAD HANDLER - Save before refresh/close
    _setupPageUnloadHandler();
  }
  
  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    
    // Remove listeners when widget is disposed
    SharedAssignmentData.removeListener(_onAssignmentDataChanged);
    SharedAssignmentData.removeYearChangeListener(_onYearChanged);
    
    // 🔥 FIX: Don't force async save in dispose - just mark for immediate save
    if (_hasPendingChanges && !_isDragActive && !_isSaving) {
      print('WeekView: Marking for immediate save on dispose...');
      // Schedule immediate save without waiting
      Timer(Duration.zero, () {
        if (!_isSaving) {
          _performCloudSave(force: true);
        }
      });
    }
    
    // 🧹 PERFORMANCE: Cleanup expired cache entries periodically
    cleanupExpiredCache();
    
    super.dispose();
  }
  
  void _onAssignmentDataChanged() {
    if (mounted && !_isDragActive) {
      setState(() {});
      print('Week View - Refreshed due to assignment data change');
    }
  }
  
  // 🔥 HANDLE YEAR CHANGES FROM OTHER VIEWS
  void _onYearChanged(int newYear) {
    if (mounted && newYear != _currentYear) {
      setState(() {
        _currentYear = newYear;
      });
      _saveCurrentYear(); // Save the new year
      _loadAssignments(forceReload: true); // Reload assignments for new year
      print('Week View - Year changed from other view to: $newYear');
    }
  }
  
  // 🔥 DETECT WEEK CHANGES - Preload data when week number changes
  @override
  void didUpdateWidget(WeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.weekNumber != widget.weekNumber) {
      print('WeekView: Week changed from ${oldWidget.weekNumber} to ${widget.weekNumber} - preloading data...');
      
      // Initialize profession settings for new week
      if (!_weekDayShiftProfessions.containsKey(widget.weekNumber)) {
        _weekDayShiftProfessions[widget.weekNumber] = Map.from(_getDefaultDayShiftProfessions());
      }
      if (!_weekNightShiftProfessions.containsKey(widget.weekNumber)) {
        _weekNightShiftProfessions[widget.weekNumber] = Map.from(_getDefaultNightShiftProfessions());
      }
      if (!_weekDayShiftRows.containsKey(widget.weekNumber)) {
        _weekDayShiftRows[widget.weekNumber] = Map.from(_getDefaultDayShiftRows());
      }
      if (!_weekNightShiftRows.containsKey(widget.weekNumber)) {
        _weekNightShiftRows[widget.weekNumber] = Map.from(_getDefaultNightShiftRows());
      }
      
      // Preload assignments for new week
      _loadAssignments(forceReload: true);
      _loadProfessionSettings();
    }
  }
  
  // 🔥 SIMPLIFIED UNLOAD HANDLER - Just rely on faster saves
  void _setupPageUnloadHandler() {
    // For now, just rely on 100ms debounce + immediate saves for critical operations
    // Web unload handlers are complex with Flutter - the faster saves should be sufficient
    print('Save timing optimized: 100ms debounce + immediate saves for drag/resize');
  }

  Future<void> _loadCurrentYear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedYear = prefs.getInt('selected_year');
      if (savedYear != null && mounted) {
        setState(() {
          _currentYear = savedYear;
          SharedAssignmentData.currentYear = savedYear; // Update shared year
        });
      }
    } catch (e) {
      print('Error loading current year: $e');
    }
  }

  void _goToCurrentWeek() {
    final currentWeek = _getCurrentWeek();
    final currentYear = DateTime.now().year;
    
    setState(() {
      _currentYear = currentYear;
    });
    
    SharedAssignmentData.setCurrentYear(currentYear); // 🔥 NOTIFY ALL VIEWS
    _saveCurrentYear();
    
    // Navigate to current week
    widget.onWeekChanged?.call(currentWeek);
  }

  Future<void> _saveCurrentYear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_year', _currentYear);
    } catch (e) {
      print('Error saving current year: $e');
    }
  }

  int _getCurrentWeek() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final firstMonday = startOfYear.subtract(Duration(days: startOfYear.weekday - 1));
    final difference = now.difference(firstMonday).inDays;
    final currentWeek = (difference / 7).floor() + 1;
    return currentWeek.clamp(1, 52);
  }

  double _getEffectiveWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    return kIsWeb && screenWidth > 800 ? 800.0 : screenWidth;
  }

  // 🗑️ REMOVED: Duplicate dispose method - merged with the one above

  // Clear old data during migration to new Supabase system
  Future<void> _clearOldDataOnFirstRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCleared = prefs.getBool('migration_cleared') ?? false;
      
      if (!hasCleared) {
        // Clear all old data
        await prefs.remove('employees');
        await prefs.remove('assignments');
        await prefs.setBool('migration_cleared', true);
        print('WeekView: Cleared old data during migration to Supabase system');
      }
    } catch (e) {
      print('WeekView: Error during data migration: $e');
    }
  }

  Future<void> _loadEmployees() async {
    try {
      // Clear old SharedPreferences data (migration from old system)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('employees');
      
      // Load from Supabase database
      final loadedEmployees = await SharedDataService.loadEmployees();
      
      // Update global list
      defaultEmployees.clear();
      defaultEmployees.addAll(loadedEmployees);
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading employees: $e');
      // Fallback to empty list if database fails
      defaultEmployees.clear();
      if (mounted) {
        setState(() {});
      }
    }
  }

  static Map<EmployeeRole, bool> _getDefaultDayShiftProfessions() => {
    EmployeeRole.tj: true,
    EmployeeRole.varu1: true,
    EmployeeRole.varu2: true,
    EmployeeRole.varu3: true,
    EmployeeRole.varu4: false,
    EmployeeRole.pasta1: true,
    EmployeeRole.pasta2: true,
    EmployeeRole.ict: true,
    EmployeeRole.tarvike: true,
    EmployeeRole.pora: true,
    EmployeeRole.huolto: true,
    EmployeeRole.custom: false,
  };
  
  static Map<EmployeeRole, bool> _getDefaultNightShiftProfessions() => {
    EmployeeRole.tj: true,
    EmployeeRole.varu1: true,
    EmployeeRole.varu2: true,
    EmployeeRole.varu3: true,
    EmployeeRole.varu4: false,
    EmployeeRole.pasta1: false,
    EmployeeRole.pasta2: true,
    EmployeeRole.ict: false,
    EmployeeRole.tarvike: true,
    EmployeeRole.pora: false,
    EmployeeRole.huolto: false,
    EmployeeRole.custom: false,
  };
  
  static Map<EmployeeRole, int> _getDefaultDayShiftRows() => {
    EmployeeRole.tj: 1,
    EmployeeRole.varu1: 2,
    EmployeeRole.varu2: 2,
    EmployeeRole.varu3: 2,
    EmployeeRole.varu4: 2,
    EmployeeRole.pasta1: 2,
    EmployeeRole.pasta2: 2,
    EmployeeRole.ict: 2,
    EmployeeRole.tarvike: 1,
    EmployeeRole.pora: 1,
    EmployeeRole.huolto: 1,
    EmployeeRole.custom: 1,
  };
  
  static Map<EmployeeRole, int> _getDefaultNightShiftRows() => {
    EmployeeRole.tj: 1,
    EmployeeRole.varu1: 2,
    EmployeeRole.varu2: 2,
    EmployeeRole.varu3: 2,
    EmployeeRole.varu4: 2,
    EmployeeRole.pasta1: 1,
    EmployeeRole.pasta2: 2,
    EmployeeRole.ict: 2,
    EmployeeRole.tarvike: 1,
    EmployeeRole.pora: 1,
    EmployeeRole.huolto: 1,
    EmployeeRole.custom: 1,
  };
  
  Map<EmployeeRole, bool> get _dayShiftProfessions {
    if (!_weekDayShiftProfessions.containsKey(widget.weekNumber)) {
      _weekDayShiftProfessions[widget.weekNumber] = Map.from(_getDefaultDayShiftProfessions());
    }
    return _weekDayShiftProfessions[widget.weekNumber]!;
  }
  
  Map<EmployeeRole, bool> get _nightShiftProfessions {
    if (!_weekNightShiftProfessions.containsKey(widget.weekNumber)) {
      _weekNightShiftProfessions[widget.weekNumber] = Map.from(_getDefaultNightShiftProfessions());
    }
    return _weekNightShiftProfessions[widget.weekNumber]!;
  }
  
  Map<EmployeeRole, int> get _dayShiftRows {
    if (!_weekDayShiftRows.containsKey(widget.weekNumber)) {
      _weekDayShiftRows[widget.weekNumber] = Map.from(_getDefaultDayShiftRows());
    }
    return _weekDayShiftRows[widget.weekNumber]!;
  }
  
  Map<EmployeeRole, int> get _nightShiftRows {
    if (!_weekNightShiftRows.containsKey(widget.weekNumber)) {
      _weekNightShiftRows[widget.weekNumber] = Map.from(_getDefaultNightShiftRows());
    }
    return _weekNightShiftRows[widget.weekNumber]!;
  }

  void _handleDropToLane(Employee employee, int dayIndex, String shiftTitle, int lane) {
    // 🔥 CONVERT ABSOLUTE LANE TO PROFESSION + ROW (NO MORE MISALIGNMENT!)
    final professionInfo = _getAbsoluteLaneToProfession(lane, shiftTitle);
    if (professionInfo == null) return; // Invalid lane
    
    final profession = professionInfo['profession'] as EmployeeRole;
    final professionRow = professionInfo['row'] as int;
    
    // Get week dates for vacation checking
    final weekDates = _getDatesForWeek(widget.weekNumber);
    
    // 🔥 SMART ALLOCATION - Find which days this employee is already allocated to (ANY row)
    final employeeAllocatedDays = <int>{};
    for (final entry in _assignments.entries) {
      final parsed = _parseAssignmentKey(entry.key);
      if (parsed != null &&
          parsed['weekNumber'] == widget.weekNumber &&
          parsed['shiftTitle'] == shiftTitle &&
          entry.value.id == employee.id) {
        employeeAllocatedDays.add(parsed['day'] as int);
      }
    }
    
    // 🔥 GET EXISTING ASSIGNMENTS FOR THIS SPECIFIC ROW (for smart fill-up)
    final existingRowKeys = _assignments.keys.where((key) {
      final parsed = _parseAssignmentKey(key);
      return parsed != null &&
             parsed['weekNumber'] == widget.weekNumber &&
             parsed['shiftTitle'] == shiftTitle &&
             parsed['profession'] == profession &&
             parsed['professionRow'] == professionRow &&
             _assignments[key]?.id == employee.id;
    }).toList();
    
    final existingRowDays = existingRowKeys.map((key) {
      final parsed = _parseAssignmentKey(key);
      return parsed!['day'] as int;
    }).toSet();
    
    // Determine which days to allocate
    final daysToAllocate = <int>[];
    
    for (int day = 0; day < 7; day++) {
      // Check if this specific slot is already occupied by ANOTHER employee
      final slotKey = _generateAssignmentKey(widget.weekNumber, shiftTitle, day, profession, professionRow);
      if (_assignments.containsKey(slotKey) && _assignments[slotKey]?.id != employee.id) {
        continue; // Skip - occupied by someone else
      }
      
      // Check if employee is on vacation this day
      final dayDate = weekDates[day];
      if (VacationManager.isEmployeeOnVacation(employee.id, dayDate)) {
        continue; // Skip - employee on vacation
      }
      
             // 🔥 SMART LOGIC: 
       // - If this row already has assignments, just fill missing days (FILL UP mode)
       // - If different row, avoid days already allocated elsewhere
       if (existingRowDays.isNotEmpty) {
         // FILL UP mode: only add days missing from THIS row
         if (!existingRowDays.contains(day)) {
           daysToAllocate.add(day);
         }
       } else {
         // NEW ROW mode: avoid days allocated to employee in ANY row
         if (!employeeAllocatedDays.contains(day)) {
           daysToAllocate.add(day);
         }
       }
    }
    
    if (daysToAllocate.isEmpty) {
      // 🔥 REMOVED SPAM: No more annoying notifications
      print('WeekView: ${employee.name} already assigned to all possible days this week');
      return;
    }
    
    setState(() {
      // 🔥 SMART ASSIGNMENT LOGIC
      if (existingRowDays.isEmpty) {
        // NEW ROW: Remove any existing assignments for this row first (shouldn't be any)
        for (final key in existingRowKeys) {
          SharedAssignmentData.removeAssignmentForYear(_currentYear, key);
        }
      }
      
      // 🔥 CLEAR OVERLAPPING ASSIGNMENTS: Remove any other employees in the target slots
      _removeOverlappingAssignments(
        shiftTitle: shiftTitle,
        profession: profession,
        professionRow: professionRow,
        days: daysToAllocate,
        excludeEmployeeId: employee.id, // Don't remove this employee's own assignments
        excludeSpecificRow: '${profession.name}|$professionRow', // Don't remove from this specific row
      );
      
      // Add assignments for all days we need to allocate
      for (final day in daysToAllocate) {
        final key = _generateAssignmentKey(widget.weekNumber, shiftTitle, day, profession, professionRow);
        SharedAssignmentData.setAssignmentForYear(_currentYear, key, employee);
        print('WeekView: Added assignment Y$_currentYear-$key -> ${employee.name}');
      }
    });
    
    // 🔥 INSTANT UI + DEBOUNCED CLOUD SAVE to prevent connection errors
    print('WeekView: 🎯 DRAG ENDED - ${employee.name} assigned to ${daysToAllocate.length} days. Scheduling save...');
    _scheduleCloudSave();
    _dragOriginalAssignment = null;
    
    // Success message with smart feedback
    String allocatedDaysText;
    if (existingRowDays.isNotEmpty) {
      // FILL UP mode
      if (daysToAllocate.length == 0) {
        allocatedDaysText = 'täytetty (oli jo täysi)';
      } else {
        allocatedDaysText = 'täytetty +${daysToAllocate.length} päivää';
      }
    } else {
      // NEW ROW mode
      allocatedDaysText = daysToAllocate.length == 7 
          ? 'koko riville' 
          : '${daysToAllocate.length} päivään (muut jo varattu)';
    }
    
    // 🔥 REMOVED SPAM: No more success notifications - work in silence
    print('WeekView: ✓ ${employee.name} assigned to ${daysToAllocate.length} days');
  }

  void _handleResize(Employee employee, String shiftTitle, int startDay, int duration, EmployeeRole profession, int professionRow) {
    try {
      // 🔥 PROFESSION INFO ALREADY PROVIDED - No conversion needed!
      int removedCount = 0;
    
      setState(() {
        // SMART RESIZE WITH CONFLICT RESOLUTION
        
        // FIRST: Find and remove ONLY the original block being resized (exact same profession + row)
        final originalKeys = _assignments.keys
            .where((key) {
              final parsed = _parseAssignmentKey(key);
              return parsed != null &&
                     parsed['weekNumber'] == widget.weekNumber &&
                     parsed['shiftTitle'] == shiftTitle &&
                     parsed['profession'] == profession &&
                     parsed['professionRow'] == professionRow &&
                     _assignments[key]?.id == employee.id;
            })
            .toList();
        
        // Remove the original block being resized
        removedCount = originalKeys.length;
        print('WeekView: Removing $removedCount original assignments during resize for ${employee.name}');
        for (final key in originalKeys) {
          print('WeekView: Removing original assignment: $key');
          SharedAssignmentData.removeAssignmentForYear(_currentYear, key);
        }
        
        // 🔥 SECOND: Use consistent overlap removal for target area
        final targetDays = List.generate(duration, (i) => startDay + i).where((day) => day < 7).toList();
        _removeOverlappingAssignments(
          shiftTitle: shiftTitle,
          profession: profession,
          professionRow: professionRow,
          days: targetDays,
          excludeEmployeeId: employee.id, // Don't remove this employee's assignments
          excludeSpecificRow: '${profession.name}|$professionRow', // Don't remove from this specific row being resized
        );
        
        // THIRD: Add new resized block
        for (final day in targetDays) {
          final key = _generateAssignmentKey(widget.weekNumber, shiftTitle, day, profession, professionRow);
          SharedAssignmentData.setAssignmentForYear(_currentYear, key, employee);
          print('WeekView: Resize added assignment Y$_currentYear-$key -> ${employee.name}');
        }
      });
      
      // 🔥 INSTANT UI + FORCE SAVE FOR RESIZE OPERATIONS
      print('WeekView: 📏 RESIZE ENDED - ${employee.name} resized to $duration days ($removedCount removed). Forcing save...');
      _hasPendingChanges = true;
      
      // Cancel any pending saves and force immediate save for resize operations
      _saveDebounceTimer?.cancel();
      _forceSave();
    } catch (e) {
      print('❌ Error during resize operation: $e');
      // Don't break the UI on resize errors
    }
  }

  void _handleRemove(Employee employee, String shiftTitle) {
    setState(() {
      _removeEmployeeFromShift(employee, shiftTitle);
    });
    
    // 🔥 INSTANT UI + DEBOUNCED CLOUD SAVE
    print('WeekView: 🗑️ REMOVE - ${employee.name} removed from ${shiftTitle}. Scheduling save...');
    _scheduleCloudSave();
  }

  void _removeEmployeeFromShift(Employee employee, String shiftTitle) {
    final keysToRemove = _assignments.keys
        .where((key) {
          final parsed = _parseAssignmentKey(key);
          return parsed != null &&
                 parsed['weekNumber'] == widget.weekNumber &&
                 parsed['shiftTitle'] == shiftTitle &&
                 _assignments[key]?.id == employee.id;
        })
        .toList();
    
    for (final key in keysToRemove) {
      SharedAssignmentData.removeAssignmentForYear(_currentYear, key);
    }
  }

  void _removeSpecificBlock(Employee employee, String shiftTitle, int blockStartDay, int blockLane) {
    // 🔥 CONVERT ABSOLUTE LANE TO PROFESSION + ROW (NO MORE MISALIGNMENT!)
    final professionInfo = _getAbsoluteLaneToProfession(blockLane, shiftTitle);
    if (professionInfo == null) return; // Invalid lane
    
    final profession = professionInfo['profession'] as EmployeeRole;
    final professionRow = professionInfo['row'] as int;
    
    // Pre-compute keys to remove (outside setState for better performance)
    final thisBlockKeys = <String>[];
    for (int day = blockStartDay; day < 7; day++) {
      final key = _generateAssignmentKey(widget.weekNumber, shiftTitle, day, profession, professionRow);
      if (_assignments.containsKey(key) && _assignments[key]?.id == employee.id) {
        thisBlockKeys.add(key);
      } else {
        break; // Stop at first gap
      }
    }
      
    // Single setState with batched removal
    if (thisBlockKeys.isNotEmpty) {
      setState(() {
        for (final key in thisBlockKeys) {
          SharedAssignmentData.removeAssignmentForYear(_currentYear, key);
        }
      });
      
      // 🔥 INSTANT UI + DEBOUNCED CLOUD SAVE
      _scheduleCloudSave();
    }
  }

  List<String> _getShiftTitlesForWeek(int weekNumber) {
    final cyclePosition = (weekNumber - 1) % 4;
    switch (cyclePosition) {
      case 0: return ['A / Päivävuoro', 'B / Yövuoro']; // Week 1: A=day, B=night
      case 1: return ['C / Päivävuoro', 'D / Yövuoro']; // Week 2: C=day, D=night  
      case 2: return ['B / Päivävuoro', 'A / Yövuoro']; // Week 3: B=day, A=night
      case 3: return ['D / Päivävuoro', 'C / Yövuoro']; // Week 4: D=day, C=night
      default: return ['A / Päivävuoro', 'B / Yövuoro'];
    }
  }

  List<DateTime> _getDatesForWeek(int weekNumber) {
    final year = 2025; // Fixed to 2025
    final jan4 = DateTime(year, 1, 4);
    final firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final weekStart = firstMonday.add(Duration(days: (weekNumber - 1) * 7));
    
    // Start from Tuesday (weekStart + 1 day)
    final tuesdayStart = weekStart.add(const Duration(days: 1));
    return List.generate(7, (index) => tuesdayStart.add(Duration(days: index)));
  }

  // 🔥 PROFESSION-BASED STORAGE SYSTEM - NO MORE LANE MISALIGNMENT! 🔥
  
  /// Convert absolute lane to profession + profession row
  /// Returns null if lane is invalid
  Map<String, dynamic>? _getAbsoluteLaneToProfession(int absoluteLane, String shiftTitle) {
    final isDay = !shiftTitle.toLowerCase().contains('yö');
    final visibleProfessions = EmployeeRole.values
        .where((role) => isDay ? _dayShiftProfessions[role] == true : _nightShiftProfessions[role] == true)
        .toList();
    
    int currentLane = 0;
    for (final profession in visibleProfessions) {
      final rows = isDay ? _dayShiftRows[profession] ?? 1 : _nightShiftRows[profession] ?? 1;
      
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
    
    return null; // Invalid lane
  }
  
  /// Convert profession + profession row to absolute lane
  /// Returns -1 if profession is not visible or row is invalid
  int _getProfessionToAbsoluteLane(EmployeeRole profession, int professionRow, String shiftTitle) {
    final isDay = !shiftTitle.toLowerCase().contains('yö');
    final visibleProfessions = EmployeeRole.values
        .where((role) => isDay ? _dayShiftProfessions[role] == true : _nightShiftProfessions[role] == true)
        .toList();
    
    int currentLane = 0;
    for (final visibleProfession in visibleProfessions) {
      if (visibleProfession == profession) {
        final maxRows = isDay ? _dayShiftRows[profession] ?? 1 : _nightShiftRows[profession] ?? 1;
        if (professionRow >= 0 && professionRow < maxRows) {
          final finalLane = currentLane + professionRow;
          print('🔥 LANE CALC: ${profession.name}:$professionRow -> lane $finalLane (shift: $shiftTitle)');
          return finalLane;
        }
        return -1; // Invalid row
      }
      
      final rows = isDay ? _dayShiftRows[visibleProfession] ?? 1 : _nightShiftRows[visibleProfession] ?? 1;
      currentLane += rows;
    }
    
    print('🔥 LANE CALC: ${profession.name}:$professionRow -> INVALID (shift: $shiftTitle)');
    return -1; // Profession not visible
  }
  
  /// Generate new profession-based assignment key
  // 🔥 UNIFIED KEY GENERATION - No more mismatches!
  String _generateAssignmentKey(int weekNumber, String shiftTitle, int day, EmployeeRole profession, int professionRow) {
    return '$weekNumber-$shiftTitle-$day-${profession.name}-$professionRow';
  }
  
  String _generateBlockKey(Employee employee, String shiftTitle, EmployeeRole profession, int professionRow) {
    return '${employee.id}|$shiftTitle|${profession.name}|$professionRow';
  }
  
  // 🔥 THROTTLED CLOUD SAVING - Prevent excessive database operations
  bool _isSaving = false;
  DateTime? _lastSaveTime;
  
    void _scheduleCloudSave() {
    // 🔥 REDUCED THROTTLING: Allow faster saves for debugging
    final now = DateTime.now();
    if (_isSaving) {
      print('WeekView: ⏳ Save already in progress, skipping...');
      _hasPendingChanges = true; // Mark for retry
      return;
    }
    
    if (_lastSaveTime != null && now.difference(_lastSaveTime!) < Duration(milliseconds: 500)) {
      print('WeekView: ⏳ Save throttled - too recent (${now.difference(_lastSaveTime!).inMilliseconds}ms ago)');
      _hasPendingChanges = true; // Still mark as pending for retry
      return;
    }

    _hasPendingChanges = true;
    print('WeekView: ⏰ Scheduling ATOMIC save in 100ms... (Current assignments: ${_assignments.length}, isDragActive: $_isDragActive)');
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      print('WeekView: 🚀 Timer fired - hasPending:$_hasPendingChanges, isDragActive:$_isDragActive, isSaving:$_isSaving');
      if (_hasPendingChanges && !_isDragActive && !_isSaving) {
        print('WeekView: 🚀 Executing ATOMIC cloud save...');
        _performCloudSave();
      } else {
        print('WeekView: ⏸️ Skipping save - conditions not met');
      }
    });
  }
  
    Future<void> _performCloudSave({bool force = false}) async {
    if (!force && (!_hasPendingChanges || _isDragActive || _isSaving)) {
      return;
    }
    
    _isSaving = true;
    _hasPendingChanges = false;
    _lastSaveTime = DateTime.now();

    try {
      await _saveAssignments();
      print('✅ Assignments saved successfully');
    } catch (e) {
      print('❌ Save failed: $e');
      _hasPendingChanges = true;
      if (!_isDragActive) {
        _showCloudSaveError();
      }
    } finally {
      _isSaving = false;
    }
  }
  
  /// Force save bypassing throttling (for critical operations)
  Future<void> _forceSave() async {
    print('WeekView: Forcing immediate save...');
    _saveDebounceTimer?.cancel();
    await _performCloudSave(force: true);
  }
  
  void _showCloudSaveError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Yhteysvirhe - muutokset tallennetaan pian'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Yritä nyt',
            onPressed: () => _performCloudSave(),
          ),
        ),
      );
    }
  }
  
  /// Parse profession-based assignment key
  /// Returns null if key format is invalid
  Map<String, dynamic>? _parseAssignmentKey(String key) {
    final parts = key.split('-');
    if (parts.length != 5) return null; // Invalid format
    
    try {
      final weekNumber = int.parse(parts[0]);
      final shiftTitle = parts[1];
      final day = int.parse(parts[2]);
      final profession = EmployeeRole.values.byName(parts[3]);
      final professionRow = int.parse(parts[4]);
      
      return {
        'weekNumber': weekNumber,
        'shiftTitle': shiftTitle,
        'day': day,
        'profession': profession,
        'professionRow': professionRow,
      };
    } catch (e) {
      return null; // Invalid values
    }
    }
  
  /// Remove duplicate employee assignments for the current week (smart deduplication)
  void _deduplicateAssignments() {
    final duplicateSlots = <String, List<String>>{}; // slot identifier -> list of keys
    
    // Find all assignments for current week and group by exact slot
    for (final entry in _assignments.entries) {
      final parsed = _parseAssignmentKey(entry.key);
      if (parsed != null && parsed['weekNumber'] == widget.weekNumber) {
        // Create slot identifier: shiftTitle-day-profession-professionRow
        final slotId = '${parsed['shiftTitle']}-${parsed['day']}-${parsed['profession']}-${parsed['professionRow']}';
        duplicateSlots.putIfAbsent(slotId, () => []).add(entry.key);
      }
    }
    
    // Remove duplicates - keep only first assignment per slot
    int duplicatesRemoved = 0;
    for (final entry in duplicateSlots.entries) {
      if (entry.value.length > 1) {
        // Sort by key to ensure consistent behavior, then keep first
        entry.value.sort();
        for (int i = 1; i < entry.value.length; i++) {
          SharedAssignmentData.removeAssignmentForYear(_currentYear, entry.value[i]);
          duplicatesRemoved++;
        }
      }
    }
    
    if (duplicatesRemoved > 0) {
      print('WeekView: Removed $duplicatesRemoved duplicate assignments for week ${widget.weekNumber} (same slot duplicates only)');
    }
  }
  
  // 🔥 ATOMIC CLOUD SAVING - No more race conditions or duplicates
  Future<void> _saveAssignments() async {
    try {
      // 🔥 DEDUPLICATE ASSIGNMENTS - Remove duplicate employees
      _deduplicateAssignments();
      
      // 🔥 SAVE PROFESSION SETTINGS FIRST - Ensure load uses same settings as save
      await _saveProfessionSettings();
      
      // 🔥 ATOMIC APPROACH: Clear entire week first, then insert all assignments
      print('🔥 ATOMIC SAVE: Clearing week ${widget.weekNumber} assignments...');
      
      // Step 1: DELETE ALL assignments for this week (atomic clear)
      final deleteResult = await SharedDataService.supabase.from('work_assignments')
        .delete()
        .eq('week_number', widget.weekNumber);
      print('🔥 ATOMIC DELETE: Cleared week ${widget.weekNumber} (affected: ${deleteResult.toString()})');
      
      // Step 2: Collect all assignments to save for this week
      final assignmentsToSave = <Map<String, dynamic>>[];
      final assignmentKeys = <String>{}; // Track constraint keys to avoid duplicates
      
      for (final entry in _assignments.entries) {
        final parsed = _parseAssignmentKey(entry.key);
        if (parsed != null && parsed['weekNumber'] == widget.weekNumber) {
          final lane = _getProfessionToAbsoluteLane(parsed['profession'], parsed['professionRow'], parsed['shiftTitle']);
          if (lane != -1) { // Valid lane
            final shiftType = parsed['shiftTitle'].toLowerCase().contains('yö') ? 'night' : 'day';
            final userId = SharedDataService.supabase.auth.currentUser?.id;
            
            // Create constraint key to avoid duplicates
            final constraintKey = '${parsed['weekNumber']}-${parsed['day']}-$shiftType-$lane';
            
            // Only add if we haven't already processed this constraint combination
            if (!assignmentKeys.contains(constraintKey)) {
              assignmentsToSave.add({
                'week_number': parsed['weekNumber'],
                'day_index': parsed['day'],
                'shift_title': parsed['shiftTitle'],
                'lane': lane,
                'employee_id': entry.value.id,
                'shift_type': shiftType,
                'user_id': userId,
              });
              
              assignmentKeys.add(constraintKey);
              print('🔥 SAVE: Assignment ${entry.value.name} -> week:${parsed['weekNumber']} day:${parsed['day']} shift:${parsed['shiftTitle']} lane:$lane');
            }
          }
        }
      }
      
      // Step 3: INSERT ALL assignments at once (batch insert)
      if (assignmentsToSave.isNotEmpty) {
        print('🔥 ATOMIC SAVE: Inserting ${assignmentsToSave.length} assignments...');
        print('🔥 SAMPLE ASSIGNMENT: ${assignmentsToSave.first}');
        final insertResult = await SharedDataService.supabase.from('work_assignments').insert(assignmentsToSave);
        print('🔥 ATOMIC INSERT: Result: ${insertResult.toString()}');
      } else {
        print('🔥 ATOMIC SAVE: No assignments to insert for week ${widget.weekNumber}');
      }
      
      print('✅ ATOMIC SAVE: Cleared and saved ${assignmentsToSave.length} assignments for week ${widget.weekNumber}');
      
      // 🔥 REFRESH SHARED DATA - Ensure other views see changes
      await _refreshAssignmentsFromSupabase();
    } catch (e) {
      print('WeekView: Error saving assignments: $e');
      rethrow; // Let calling code handle the error appropriately
    }
  }

  Future<void> _loadAssignments({bool forceReload = false}) async {
    // 🔥 PROTECT DRAG STATES - Don't reload during active drag operations
    if (_isDragActive) {
      print('WeekView: Skipping assignment reload during active drag');
      return;
    }
    
    // 🏎️ INTELLIGENT CACHE CHECK - Use cached data if available and fresh
    if (!forceReload && _isCacheValid(widget.weekNumber)) {
      final cachedData = _assignmentCache[widget.weekNumber]!;
      print('WeekView: ⚡ CACHE HIT for week ${widget.weekNumber} (${cachedData.length} assignments)');
      SharedAssignmentData.updateAssignmentsForWeek(widget.weekNumber, cachedData);
      _hasLoadedOnce = true;
      if (mounted) {
        setState(() {});
      }
      // 🔮 PREDICTIVE PRELOADING in background
      _preloadAdjacentWeeks();
      return;
    }
    
    // 🔥 FALLBACK: Check SharedAssignmentData cache
    final existingCount = SharedAssignmentData.getWeekAssignmentCount(widget.weekNumber);
    if (!forceReload && existingCount > 0 && _hasLoadedOnce) {
      print('WeekView: Found ${existingCount} existing assignments for week ${widget.weekNumber}, using SharedAssignmentData cache');
      if (mounted) {
        setState(() {});
      }
      return;
    }
    
    try {
      // Clear old SharedPreferences data (migration)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('assignments');
      
      print('WeekView: 🔄 Loading assignments from database for week ${widget.weekNumber}${forceReload ? " (forced)" : ""}...');
      
      // Load assignments from Supabase database for current week ONLY
      final supabaseAssignments = await SharedDataService.loadAssignments(widget.weekNumber);
      
      // 🏎️ CACHE THE RESULTS for ultra-fast future access
      _assignmentCache[widget.weekNumber] = Map<String, Employee>.from(supabaseAssignments);
      _cacheTimestamps[widget.weekNumber] = DateTime.now();
      
      // Update assignments for current week (clears old + adds new + notifies)
      SharedAssignmentData.updateAssignmentsForWeek(widget.weekNumber, supabaseAssignments);
      
      print('WeekView: ✅ Loaded ${SharedAssignmentData.getWeekAssignmentCount(widget.weekNumber)} assignments for week ${widget.weekNumber} (Total: ${SharedAssignmentData.assignmentCount})');
      
      _hasLoadedOnce = true; // Mark as loaded
      
      if (mounted && !_isDragActive) {
        setState(() {});
      }
      
      // 🔮 PREDICTIVE PRELOADING in background
      _preloadAdjacentWeeks();
      
    } catch (e) {
      print('WeekView: ❌ Error loading assignments: $e');
      // Only clear current week assignments if not in drag mode
      if (!_isDragActive) {
        SharedAssignmentData.clearWeek(widget.weekNumber);
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  /// Force refresh assignments from Supabase to sync with other views
  Future<void> _refreshAssignmentsFromSupabase() async {
    try {
      print('WeekView: 🔄 Force refreshing assignments from Supabase...');
      
      // Load fresh assignments from Supabase
      final freshAssignments = await SharedDataService.loadAssignments(widget.weekNumber);
      
      // Update SharedAssignmentData with fresh data
      SharedAssignmentData.updateAssignmentsForWeek(widget.weekNumber, freshAssignments);
      
      print('WeekView: ✅ Refreshed ${freshAssignments.length} assignments from Supabase');
      
      // Update UI
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('WeekView: ❌ Error refreshing assignments: $e');
    }
  }

  // 🏎️ CACHE VALIDATION - Check if cached data is still fresh
  bool _isCacheValid(int weekNumber) {
    if (!_assignmentCache.containsKey(weekNumber) || !_cacheTimestamps.containsKey(weekNumber)) {
      return false;
    }
    final age = DateTime.now().difference(_cacheTimestamps[weekNumber]!);
    return age.inMinutes < _cacheExpirationMinutes;
  }

  // 🔮 PREDICTIVE PRELOADING - Load adjacent weeks in background for instant navigation
  void _preloadAdjacentWeeks() {
    for (int offset in [-1, 1]) {
      final targetWeek = widget.weekNumber + offset;
      if (!_preloadedWeeks.contains(targetWeek) && !_isCacheValid(targetWeek)) {
        _preloadedWeeks.add(targetWeek);
        // Preload in background with small delay to not impact current UI
        Future.delayed(const Duration(milliseconds: 100), () {
          _preloadWeekData(targetWeek);
        });
      }
    }
  }

  // 🔮 PRELOAD WEEK DATA in background
  Future<void> _preloadWeekData(int weekNumber) async {
    try {
      print('WeekView: 🔮 Preloading week $weekNumber in background...');
      final assignments = await SharedDataService.loadAssignments(weekNumber);
      _assignmentCache[weekNumber] = Map<String, Employee>.from(assignments);
      _cacheTimestamps[weekNumber] = DateTime.now();
      print('WeekView: ✅ Preloaded week $weekNumber (${assignments.length} assignments)');
    } catch (e) {
      print('WeekView: ⚠️ Preload failed for week $weekNumber: $e');
      _preloadedWeeks.remove(weekNumber); // Allow retry later
    }
  }

  // 🧹 CACHE CLEANUP - Remove expired cache entries
  static void cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredWeeks = <int>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value).inMinutes >= _cacheExpirationMinutes) {
        expiredWeeks.add(entry.key);
      }
    }
    
    for (final week in expiredWeeks) {
      _assignmentCache.remove(week);
      _cacheTimestamps.remove(week);
      _preloadedWeeks.remove(week);
    }
    
    if (expiredWeeks.isNotEmpty) {
      print('WeekView: 🧹 Cleaned up ${expiredWeeks.length} expired cache entries');
    }
  }

  // SAVE PROFESSION SETTINGS GLOBALLY TOO
  Future<void> _saveProfessionSettings() async {
    try {
      // 🔥 100% SUPABASE STORAGE - No local fallback
      await SharedDataService.saveProfessionSettings(
        weekNumber: widget.weekNumber,
        dayProfessions: _dayShiftProfessions,
        nightProfessions: _nightShiftProfessions,
        dayRows: _dayShiftRows,
        nightRows: _nightShiftRows,
      );
      
      print('WeekView: ✅ Saved profession settings to Supabase for week ${widget.weekNumber}');
      
      // Notify other views that profession settings have changed
      SharedAssignmentData.forceRefresh();
    } catch (e) {
      print('WeekView: ❌ Error saving profession settings: $e');
      rethrow;
    }
  }

  Future<void> _loadProfessionSettings() async {
    try {
      // 🔥 100% SUPABASE STORAGE - No local fallback
      final supabaseData = await SharedDataService.loadProfessionSettings(widget.weekNumber);
      
      if (supabaseData.isNotEmpty) {
        final dayProfessions = supabaseData['dayProfessions'] as Map<EmployeeRole, bool>?;
        final nightProfessions = supabaseData['nightProfessions'] as Map<EmployeeRole, bool>?;
        final dayRows = supabaseData['dayRows'] as Map<EmployeeRole, int>?;
        final nightRows = supabaseData['nightRows'] as Map<EmployeeRole, int>?;
        
        if (dayProfessions != null && dayProfessions.isNotEmpty) {
          _weekDayShiftProfessions[widget.weekNumber] = Map.from(dayProfessions);
        }
        if (nightProfessions != null && nightProfessions.isNotEmpty) {
          _weekNightShiftProfessions[widget.weekNumber] = Map.from(nightProfessions);
        }
        if (dayRows != null && dayRows.isNotEmpty) {
          _weekDayShiftRows[widget.weekNumber] = Map.from(dayRows);
        }
        if (nightRows != null && nightRows.isNotEmpty) {
          _weekNightShiftRows[widget.weekNumber] = Map.from(nightRows);
        }
        
        print('WeekView: ✅ Loaded profession settings from Supabase for week ${widget.weekNumber}');
      } else {
        // No settings found in Supabase, use defaults
        print('WeekView: No settings found in Supabase, using defaults for week ${widget.weekNumber}');
        _setDefaultProfessionSettings();
      }
      
      // Update UI after loading settings
      if (mounted) {
        setState(() {});
      }
      
    } catch (e) {
      print('WeekView: ❌ Error loading profession settings from Supabase: $e');
      _setDefaultProfessionSettings();
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Set default profession settings as fallback
  void _setDefaultProfessionSettings() {
    // Initialize default settings for the current week
    _weekDayShiftProfessions[widget.weekNumber] = Map.from(_getDefaultDayShiftProfessions());
    _weekNightShiftProfessions[widget.weekNumber] = Map.from(_getDefaultNightShiftProfessions());
    _weekDayShiftRows[widget.weekNumber] = Map.from(_getDefaultDayShiftRows());
    _weekNightShiftRows[widget.weekNumber] = Map.from(_getDefaultNightShiftRows());
    
    print('WeekView: Set default profession settings for week ${widget.weekNumber}');
  }

  /// Convert string to EmployeeRole (same as SharedDataService)
  EmployeeRole? _stringToEmployeeRole(String value) {
    try {
      return EmployeeRole.values.firstWhere((e) => e.toString().split('.').last == value);
    } catch (e) {
      return null;
    }
  }

  /// Convert enum to string (same as SharedDataService)  
  String _enumToString(dynamic enumValue) {
    return enumValue.toString().split('.').last;
  }

  void _showAddEmployeeDialog(EmployeeCategory category) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lisää työntekijä - ${_getCategoryDisplayName(category)}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Syötä työntekijän nimi',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Peruuta'),
          ),
                    TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final newEmployee = Employee(
                  id: const Uuid().v4(),
                  name: controller.text.trim(),
                  category: category,
                  type: EmployeeType.vakityontekija, // Default type
                  role: EmployeeRole.varu1, // Default role
                  shiftCycle: ShiftCycle.none, // Default shift cycle
                );
                
                try {
                  // Save to Supabase database
                  await SharedDataService.saveEmployee(newEmployee);
                  
                  // Reload employees from database to refresh the list
                  await _loadEmployees();
                  
                  Navigator.of(context).pop();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Employee ${newEmployee.name} added successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding employee: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Lisää'),
          ),
        ],
      ),
    );
  }
  
  String _getCategoryDisplayName(EmployeeCategory category) {
    switch (category) {
      case EmployeeCategory.ab:
        return 'A/B vuorot';
      case EmployeeCategory.cd:
        return 'C/D vuorot';
      case EmployeeCategory.huolto:
        return 'Huolto';
      case EmployeeCategory.sijainen:
        return 'Sijaiset';
    }
  }



  Future<void> _saveEmployees() async {
    // This method is now deprecated - use SharedDataService.saveEmployee() for individual saves
    // and _loadEmployees() to refresh the list from database
    print('_saveEmployees() called - this is deprecated, use SharedDataService instead');
  }

  void _showProfessionEditDialog() {
    // 🔥 DEBUG: Force refresh profession data to fix grayed-out issue
    try {
      // Ensure profession data exists for current week
      if (!_weekDayShiftProfessions.containsKey(widget.weekNumber)) {
        _weekDayShiftProfessions[widget.weekNumber] = Map.from(_getDefaultDayShiftProfessions());
      }
      if (!_weekNightShiftProfessions.containsKey(widget.weekNumber)) {
        _weekNightShiftProfessions[widget.weekNumber] = Map.from(_getDefaultNightShiftProfessions());
      }
      if (!_weekDayShiftRows.containsKey(widget.weekNumber)) {
        _weekDayShiftRows[widget.weekNumber] = Map.from(_getDefaultDayShiftRows());
      }
      if (!_weekNightShiftRows.containsKey(widget.weekNumber)) {
        _weekNightShiftRows[widget.weekNumber] = Map.from(_getDefaultNightShiftRows());
      }
      
      print('🔧 PROFESSION DEBUG: Week ${widget.weekNumber} - Day professions: ${_dayShiftProfessions.length}, Night professions: ${_nightShiftProfessions.length}');
      
      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog.fullscreen(
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('Profession Settings', style: TextStyle(fontSize: 16, color: Colors.white)),
                    backgroundColor: const Color(0xFF253237),
                    foregroundColor: Colors.white,
                  ),
                  body: Container(
                    padding: const EdgeInsets.all(16),
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          labelColor: Colors.black87,
                          unselectedLabelColor: Colors.black54,
                          tabs: [
                            Tab(text: 'Day Shift'),
                            Tab(text: 'Night Shift'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildProfessionSettings(setDialogState, true),
                              _buildProfessionSettings(setDialogState, false),
                            ],
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('🔥 ERROR in profession dialog: $e');
      // Show simple error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to open profession settings: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showAddCustomProfessionDialog(StateSetter parentSetState) {
    final nameController = TextEditingController();
    final shortNameController = TextEditingController();
    bool dayVisible = true;
    bool nightVisible = true;
    int rows = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Custom Profession'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Profession Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: shortNameController,
                    decoration: const InputDecoration(
                      labelText: 'Short Name (e.g., TEST)',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 6,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: dayVisible,
                        onChanged: (value) => setDialogState(() => dayVisible = value ?? true),
                      ),
                      const Text('Visible in Day Shift'),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: nightVisible,
                        onChanged: (value) => setDialogState(() => nightVisible = value ?? true),
                      ),
                      const Text('Visible in Night Shift'),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Rows: '),
                      IconButton(
                        onPressed: rows > 1 ? () => setDialogState(() => rows--) : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$rows'),
                      IconButton(
                        onPressed: rows < 4 ? () => setDialogState(() => rows++) : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                    if (nameController.text.isNotEmpty && shortNameController.text.isNotEmpty) {
                      final customProf = CustomProfession(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        shortName: shortNameController.text.toUpperCase(),
                        defaultDayVisible: dayVisible,
                        defaultNightVisible: nightVisible,
                        defaultRows: rows,
                      );
                      
                      CustomProfessionManager.addCustomProfession(customProf);
                      _saveCustomProfessions();
                      
                      Navigator.pop(context);
                      parentSetState(() {});
                      setState(() {});
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveCustomProfessions() async {
    try {
      // 🔥 100% SUPABASE STORAGE - Save custom professions to cloud
      await CustomProfessionManager.saveToSupabase(SharedDataService.supabase);
      print('WeekView: ✅ Saved custom professions to Supabase');
    } catch (e) {
      print('WeekView: ❌ Error saving custom professions: $e');
      rethrow;
    }
  }

  Future<void> _loadCustomProfessions() async {
    try {
      // 🔥 100% SUPABASE STORAGE - Load custom professions from cloud
      await CustomProfessionManager.loadFromSupabase(SharedDataService.supabase);
      print('WeekView: ✅ Loaded ${CustomProfessionManager.allCustomProfessions.length} custom professions from Supabase');
    } catch (e) {
      print('WeekView: ❌ Error loading custom professions from Supabase: $e');
    }
  }

  Widget _buildProfessionSettings(StateSetter setDialogState, bool isDayShift) {
    try {
      final professions = isDayShift ? _dayShiftProfessions : _nightShiftProfessions;
      final rows = isDayShift ? _dayShiftRows : _nightShiftRows;
      
      // 🔥 DEBUG: Log profession data to help debug gray screen
      print('🔧 PROFESSION DIALOG: isDayShift=$isDayShift, professions.length=${professions.length}, rows.length=${rows.length}');
      
      // 🔥 FILTER PROFESSIONS: Show default professions + active slots, exclude custom and inactive slots
      final defaultProfessions = [
        EmployeeRole.tj, EmployeeRole.varu1, EmployeeRole.varu2, EmployeeRole.varu3, EmployeeRole.varu4,
        EmployeeRole.pasta1, EmployeeRole.pasta2, EmployeeRole.ict, EmployeeRole.tarvike, EmployeeRole.pora, EmployeeRole.huolto
      ];
      final slotProfessions = [EmployeeRole.slot1, EmployeeRole.slot2, EmployeeRole.slot3, EmployeeRole.slot4, EmployeeRole.slot5,
                              EmployeeRole.slot6, EmployeeRole.slot7, EmployeeRole.slot8, EmployeeRole.slot9, EmployeeRole.slot10];
      
      final activeSlotsOnly = slotProfessions.where((slot) => SharedAssignmentData.activeProfessionSlots.contains(slot)).toList();
      final availableRoles = [...defaultProfessions, ...activeSlotsOnly];
      
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔥 PROFESSION MANAGEMENT BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _canAddMoreProfessions() ? () => _addNewProfession(setDialogState) : null,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: activeSlotsOnly.isNotEmpty ? () => _removeProfession(setDialogState) : null,
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            // 🔥 PROFESSION LIST
            ...availableRoles.map((role) {
            try {
              // 🔥 NULL SAFETY: Ensure values exist with proper defaults
              final isVisible = professions[role] ?? false;
              final rowCount = rows[role] ?? 1;
              
              print('🔧 ROLE DEBUG: $role -> visible=$isVisible, rows=$rowCount');
              
              return Card(
                color: Colors.grey[50],
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      // Checkbox for visibility
                      Checkbox(
                        value: isVisible,
                        onChanged: (bool? value) {
                          final wasVisible = isVisible;
                          final willBeVisible = value ?? false;
                          
                          setDialogState(() {
                            professions[role] = willBeVisible;
                          });
                          
                          // If profession is being hidden, move assignments back to workers
                          if (wasVisible && !willBeVisible) {
                            _moveAssignmentsBackToWorkers(role, isDayShift ? 'Päivävuoro' : 'Yövuoro');
                          }
                          
                          _saveProfessionSettings(); // SAVE GLOBAL PROFESSION SETTINGS
                          
                          // INSTANT UPDATE - Update main UI immediately
                          if (mounted) {
                            setState(() {});
                          }
                        },
                      ),
                      // Profession name with edit functionality
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _editProfessionName(role, setDialogState),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _getRoleDisplayName(role),
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12, // Even smaller font for better mobile experience
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Row count controls
                      // Decrease button
                      IconButton(
                        onPressed: rowCount > 1 ? () {
                          setDialogState(() {
                            rows[role] = (rowCount - 1).clamp(1, 4);
                          });
                          _saveProfessionSettings(); // SAVE GLOBAL PROFESSION SETTINGS
                          
                          // INSTANT UPDATE - Update main UI immediately
                          if (mounted) {
                            setState(() {});
                          }
                        } : null,
                        icon: const Icon(Icons.remove, size: 16),
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        padding: EdgeInsets.zero,
                      ),
                      // Current count
                      Container(
                        width: 30,
                        alignment: Alignment.center,
                        child: Text(
                          '$rowCount',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Increase button
                      IconButton(
                        onPressed: rowCount < 4 ? () {
                          setDialogState(() {
                            rows[role] = (rowCount + 1).clamp(1, 4);
                          });
                          _saveProfessionSettings(); // SAVE GLOBAL PROFESSION SETTINGS
                          
                          // INSTANT UPDATE - Update main UI immediately
                          if (mounted) {
                            setState(() {});
                          }
                        } : null,
                        icon: const Icon(Icons.add, size: 16),
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              );
            } catch (e) {
              print('🔥 ERROR building role $role: $e');
              // Return an error card instead of crashing
              return Card(
                color: Colors.red[100],
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Error loading $role: $e'),
                ),
              );
            }
          }),
          ],
        ),
      );
    } catch (e) {
      print('🔥 CRITICAL ERROR in _buildProfessionSettings: $e');
      // Return a simple error widget instead of gray screen
      return Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error loading profession settings: $e'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _forceRefreshProfessionData();
                setDialogState(() {}); // Refresh dialog
              },
              child: const Text('Reset Data'),
            ),
          ],
        ),
      );
    }
  }

  // Function to move assignments back to workers when profession is hidden
  void _moveAssignmentsBackToWorkers(EmployeeRole hiddenRole, String shiftType) {
    final assignmentsToRemove = <String>[];
    
    // Find all assignments for the hidden profession in current week
    for (final entry in _assignments.entries) {
      final parsed = _parseAssignmentKey(entry.key);
      if (parsed != null && 
          parsed['weekNumber'] == widget.weekNumber && 
          parsed['profession'] == hiddenRole &&
          parsed['shiftTitle'].contains(shiftType)) {
        assignmentsToRemove.add(entry.key);
      }
    }
    
    // Remove the assignments (this moves them back to workers list)
    for (final key in assignmentsToRemove) {
      SharedAssignmentData.removeAssignmentForYear(_currentYear, key);
    }
    
    // 🔥 INSTANT UI + DEBOUNCED CLOUD SAVE
    _scheduleCloudSave();
    
    // Update UI
    if (mounted) {
      setState(() {});
    }
    
    print('Moved ${assignmentsToRemove.length} assignments back to workers for hidden profession: ${hiddenRole.name}');
  }

  String _getRoleDisplayName(EmployeeRole role) {
    // Use shared custom names
    return SharedAssignmentData.getRoleDisplayName(role);
  }

  /// Edit profession names (both short and full names)
  void _editProfessionName(EmployeeRole role, StateSetter setDialogState) {
    final shortNameController = TextEditingController(text: SharedAssignmentData.customProfessionNames[role] ?? '');
    final fullNameController = TextEditingController(text: SharedAssignmentData.customProfessionFullNames[role] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profession: ${role.name.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: shortNameController,
              decoration: const InputDecoration(
                labelText: 'Short Name (displayed in calendar, max 8 chars)',
                hintText: 'e.g., TJ, ICT, VARU1',
                counterText: '', // Hide the character counter
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name (displayed in settings)',
                hintText: 'e.g., Työnjohtaja, ICT-vastaava',
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final shortName = shortNameController.text.trim().toUpperCase();
              final fullName = fullNameController.text.trim();
              
              if (shortName.isNotEmpty && fullName.isNotEmpty) {
                setState(() {
                  SharedAssignmentData.customProfessionNames[role] = shortName;
                  SharedAssignmentData.customProfessionFullNames[role] = fullName;
                });
                setDialogState(() {}); // Update the profession settings dialog
                _saveProfessionNames();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Save custom profession names to cloud storage
  Future<void> _saveProfessionNames() async {
    try {
      // Save to SharedPreferences as backup and for immediate access
      final prefs = await SharedPreferences.getInstance();
      final shortNamesJson = SharedAssignmentData.customProfessionNames.map((key, value) => MapEntry(key.name, value));
      final fullNamesJson = SharedAssignmentData.customProfessionFullNames.map((key, value) => MapEntry(key.name, value));
      final activeSlotsJson = SharedAssignmentData.activeProfessionSlots.map((slot) => slot.name).toList();
      
      await prefs.setString('custom_profession_short_names', json.encode(shortNamesJson));
      await prefs.setString('custom_profession_full_names', json.encode(fullNamesJson));
      await prefs.setString('active_profession_slots', json.encode(activeSlotsJson));
      
      print('✅ Saved custom profession names and ${SharedAssignmentData.activeProfessionSlots.length} active slots locally');
    } catch (e) {
      print('❌ Error saving profession names: $e');
    }
  }

  /// Load custom profession names from storage
  Future<void> _loadProfessionNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load short names
      final shortNamesJson = prefs.getString('custom_profession_short_names');
      if (shortNamesJson != null) {
        final Map<String, dynamic> shortNamesMap = json.decode(shortNamesJson);
        for (final entry in shortNamesMap.entries) {
          final role = EmployeeRole.values.firstWhere(
            (r) => r.name == entry.key,
            orElse: () => EmployeeRole.tj,
          );
          if (role != EmployeeRole.custom) {
            SharedAssignmentData.customProfessionNames[role] = entry.value;
          }
        }
      }
      
      // Load full names
      final fullNamesJson = prefs.getString('custom_profession_full_names');
      if (fullNamesJson != null) {
        final Map<String, dynamic> fullNamesMap = json.decode(fullNamesJson);
        for (final entry in fullNamesMap.entries) {
          final role = EmployeeRole.values.firstWhere(
            (r) => r.name == entry.key,
            orElse: () => EmployeeRole.tj,
          );
          if (role != EmployeeRole.custom) {
            SharedAssignmentData.customProfessionFullNames[role] = entry.value;
          }
        }
      }

      // Load active profession slots
      final activeSlotsJson = prefs.getString('active_profession_slots');
      if (activeSlotsJson != null) {
        final List<dynamic> slotNames = json.decode(activeSlotsJson);
        SharedAssignmentData.activeProfessionSlots.clear();
        for (final slotName in slotNames) {
          final role = EmployeeRole.values.firstWhere(
            (r) => r.name == slotName,
            orElse: () => EmployeeRole.tj,
          );
          if (role.name.startsWith('slot')) {
            SharedAssignmentData.activeProfessionSlots.add(role);
          }
        }
      }
      
      print('✅ Loaded custom profession names and ${SharedAssignmentData.activeProfessionSlots.length} active slots');
    } catch (e) {
      print('❌ Error loading profession names: $e');
    }
  }

  /// Check if more professions can be added
  bool _canAddMoreProfessions() {
    final slotProfessions = [EmployeeRole.slot1, EmployeeRole.slot2, EmployeeRole.slot3, EmployeeRole.slot4, EmployeeRole.slot5,
                            EmployeeRole.slot6, EmployeeRole.slot7, EmployeeRole.slot8, EmployeeRole.slot9, EmployeeRole.slot10];
    return SharedAssignmentData.activeProfessionSlots.length < slotProfessions.length;
  }

  /// Add a new profession slot
  void _addNewProfession(StateSetter setDialogState) {
    final slotProfessions = [EmployeeRole.slot1, EmployeeRole.slot2, EmployeeRole.slot3, EmployeeRole.slot4, EmployeeRole.slot5,
                            EmployeeRole.slot6, EmployeeRole.slot7, EmployeeRole.slot8, EmployeeRole.slot9, EmployeeRole.slot10];
    
    // Find first available slot
    final availableSlot = slotProfessions.firstWhere(
      (slot) => !SharedAssignmentData.activeProfessionSlots.contains(slot),
      orElse: () => EmployeeRole.slot1,
    );

    if (!SharedAssignmentData.activeProfessionSlots.contains(availableSlot)) {
      final shortNameController = TextEditingController(text: 'NEW${SharedAssignmentData.activeProfessionSlots.length + 1}');
      final fullNameController = TextEditingController(text: 'New Profession ${SharedAssignmentData.activeProfessionSlots.length + 1}');

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add New Profession'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                           TextField(
               controller: shortNameController,
               decoration: const InputDecoration(
                 labelText: 'Short Name (displayed in calendar, max 8 chars)',
                 hintText: 'e.g., MECH, ELECT, CLEAN',
                 counterText: '', // Hide the character counter
               ),
               textCapitalization: TextCapitalization.characters,
               maxLength: 8,
             ),
              const SizedBox(height: 16),
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name (displayed in settings)',
                  hintText: 'e.g., Mechanic, Electrician, Cleaner',
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final shortName = shortNameController.text.trim().toUpperCase();
                final fullName = fullNameController.text.trim();
                
                if (shortName.isNotEmpty && fullName.isNotEmpty) {
                  setState(() {
                    SharedAssignmentData.activeProfessionSlots.add(availableSlot);
                    SharedAssignmentData.customProfessionNames[availableSlot] = shortName;
                    SharedAssignmentData.customProfessionFullNames[availableSlot] = fullName;
                    
                    // Set default visibility and rows for the new profession in current week
                    final dayProfessions = _weekDayShiftProfessions[widget.weekNumber] ??= {};
                    final nightProfessions = _weekNightShiftProfessions[widget.weekNumber] ??= {};
                    final dayRows = _weekDayShiftRows[widget.weekNumber] ??= {};
                    final nightRows = _weekNightShiftRows[widget.weekNumber] ??= {};
                    
                    dayProfessions[availableSlot] = true;
                    nightProfessions[availableSlot] = true;
                    dayRows[availableSlot] = 1;
                    nightRows[availableSlot] = 1;
                  });
                  setDialogState(() {}); // Update the profession settings dialog
                  _saveProfessionNames();
                  _saveProfessionSettings();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );
    }
  }

  /// Remove a profession slot
  void _removeProfession(StateSetter setDialogState) {
    final activeSlots = SharedAssignmentData.activeProfessionSlots.toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profession'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select profession to remove:'),
            const SizedBox(height: 16),
            ...activeSlots.map((slot) => ListTile(
              title: Text(SharedAssignmentData.customProfessionNames[slot] ?? slot.name.toUpperCase()),
              subtitle: Text(SharedAssignmentData.customProfessionFullNames[slot] ?? 'Custom Profession'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    SharedAssignmentData.activeProfessionSlots.remove(slot);
                    
                    // Remove assignments for this profession
                    _moveAssignmentsBackToWorkers(slot, 'Päivävuoro');
                    _moveAssignmentsBackToWorkers(slot, 'Yövuoro');
                    
                    // Reset profession settings for current week
                    final dayProfessions = _weekDayShiftProfessions[widget.weekNumber];
                    final nightProfessions = _weekNightShiftProfessions[widget.weekNumber];
                    final dayRows = _weekDayShiftRows[widget.weekNumber];
                    final nightRows = _weekNightShiftRows[widget.weekNumber];
                    
                    dayProfessions?.remove(slot);
                    nightProfessions?.remove(slot);
                    dayRows?.remove(slot);
                    nightRows?.remove(slot);
                  });
                  setDialogState(() {}); // Update the profession settings dialog
                  _saveProfessionNames();
                  _saveProfessionSettings();
                  Navigator.pop(context);
                },
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _toggleResizeMode(Employee employee, String shiftTitle, int blockStartDay, int blockLane) {
    // 🔥 FIX: Use the specific block lane to get profession info, not any assignment
    final professionInfo = _getAbsoluteLaneToProfession(blockLane, shiftTitle);
    if (professionInfo == null) return;
    
    final profession = professionInfo['profession'] as EmployeeRole;
    final professionRow = professionInfo['row'] as int;
    final blockKey = _generateBlockKey(employee, shiftTitle, profession, professionRow);
    
    // 🔥 DEBUG: Log all instances of this employee to help diagnose multi-row issues
    final allEmployeeKeys = _assignments.entries
        .where((entry) => entry.value.id == employee.id && 
                         _parseAssignmentKey(entry.key)?['shiftTitle'] == shiftTitle)
        .map((entry) => entry.key)
        .toList();
    print('🔧 RESIZE: Employee ${employee.name} has ${allEmployeeKeys.length} assignment(s) in $shiftTitle');
    for (final key in allEmployeeKeys) {
      final parsed = _parseAssignmentKey(key);
      if (parsed != null) {
        final keyBlockKey = _generateBlockKey(employee, shiftTitle, parsed['profession'], parsed['professionRow']);
        print('🔧   Assignment: ${parsed['profession']}.${parsed['professionRow']} day ${parsed['day']} -> blockKey: $keyBlockKey');
      }
    }
    print('🔧 RESIZE: Toggling blockKey: $blockKey (from lane $blockLane -> ${profession.name}.${professionRow})');
    
    setState(() {
      // 🔥 FIX: Clear ALL resize modes and drag states to ensure only ONE block is editable
      if (_resizeModeBlockKey == blockKey) {
        // Clicking the same block - turn off resize mode
        _resizeModeBlockKey = null;
        _dragStates?.clear();
        print('🔧 RESIZE: Disabled resize mode for $blockKey');
      } else {
        // Clicking different block - switch to this block only
        _resizeModeBlockKey = blockKey;
        _dragStates?.clear(); // Clear previous drag states
        print('🔧 RESIZE: Enabled resize mode for $blockKey (cleared others)');
      }
    });
  }

  void _handleResizeStart(DragStartDetails details, Employee employee, String shiftTitle, bool isLeftResize) {
    try {
      _isDragActive = true; // Protect from cloud saves during drag
      
      // 🔥 FIX: Use the current resize mode block key to get profession info
      if (_resizeModeBlockKey == null) return;
      
      // Parse profession info from the current resize mode block key
      final keyParts = _resizeModeBlockKey!.split('|');
      if (keyParts.length != 4) return;
      
      final profession = EmployeeRole.values.byName(keyParts[2]);
      final professionRow = int.parse(keyParts[3]);
      final blockKey = _resizeModeBlockKey!;
    
    // 🔥 FIX: Get ONLY current specific profession/row assignments, not ALL employee assignments
    final currentKeys = _assignments.entries
        .where((entry) {
          final parsed = _parseAssignmentKey(entry.key);
          return parsed != null && 
                 parsed['weekNumber'] == widget.weekNumber && 
                 parsed['shiftTitle'] == shiftTitle && 
                 entry.value.id == employee.id &&
                 parsed['profession'] == profession &&
                 parsed['professionRow'] == professionRow;
        })
        .map((e) => e.key)
        .toList();
    
    currentKeys.sort((a, b) {
      final parsedA = _parseAssignmentKey(a);
      final parsedB = _parseAssignmentKey(b);
      final dayA = parsedA?['day'] ?? 0;
      final dayB = parsedB?['day'] ?? 0;
      return dayA.compareTo(dayB);
    });
    
    final originalStartDay = currentKeys.isNotEmpty ? (_parseAssignmentKey(currentKeys.first)?['day'] ?? 0) : 0;
    final originalEndDay = currentKeys.isNotEmpty ? (_parseAssignmentKey(currentKeys.last)?['day'] ?? 0) : 0;
    final originalDuration = originalEndDay - originalStartDay + 1;
    
    // Initialize resize mode with smooth transition
    setState(() {
      _resizeModeBlockKey = blockKey;
      _dragStates ??= {};
      _dragStates![blockKey] = DragState(
        startX: details.globalPosition.dx,
        currentX: details.globalPosition.dx,
        isLeftResize: isLeftResize,
        originalStartDay: originalStartDay,
        originalDuration: originalDuration,
      );
    });
    
    HapticFeedback.lightImpact();
    } catch (e) {
      print('❌ Error starting resize: $e');
      _isDragActive = false;
    }
  }

  // 🚀 BATCHED RESIZE UPDATE FLAG - prevents setState spam
  bool _hasPendingResizeUpdate = false;
  
  // 🏎️ INTELLIGENT CACHING SYSTEM
  static final Map<int, Map<String, Employee>> _assignmentCache = {};
  static final Map<int, DateTime> _cacheTimestamps = {};
  static const int _cacheExpirationMinutes = 5;
  static final Set<int> _preloadedWeeks = <int>{};
  
  void _handleLeftResize(DragUpdateDetails details, Employee employee, String shiftTitle) {
    if (_resizeModeBlockKey == null || _dragStates == null) return;
    
    final currentDragState = _dragStates![_resizeModeBlockKey!];
    if (currentDragState != null) {
      // 🚀 ULTRA-SMOOTH: Update drag state without immediate rebuild
      _dragStates![_resizeModeBlockKey!] = DragState(
        startX: currentDragState.startX,
        currentX: details.globalPosition.dx,
        isLeftResize: true,
        originalStartDay: currentDragState.originalStartDay,
        originalDuration: currentDragState.originalDuration,
      );
      
      // 🔄 BATCHED UPDATE: Only one setState per frame (60fps max)
      if (!_hasPendingResizeUpdate) {
        _hasPendingResizeUpdate = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
            _hasPendingResizeUpdate = false;
          }
        });
      }
    }
  }

  void _handleRightResize(DragUpdateDetails details, Employee employee, String shiftTitle) {
    if (_resizeModeBlockKey == null || _dragStates == null) return;
    
    final currentDragState = _dragStates![_resizeModeBlockKey!];
    if (currentDragState != null) {
      // 🚀 ULTRA-SMOOTH: Update drag state without immediate rebuild
      _dragStates![_resizeModeBlockKey!] = DragState(
        startX: currentDragState.startX,
        currentX: details.globalPosition.dx,
        isLeftResize: false,
        originalStartDay: currentDragState.originalStartDay,
        originalDuration: currentDragState.originalDuration,
      );
      
      // 🔄 BATCHED UPDATE: Only one setState per frame (60fps max)
      if (!_hasPendingResizeUpdate) {
        _hasPendingResizeUpdate = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
            _hasPendingResizeUpdate = false;
          }
        });
      }
    }
  }



  void _performResize(Employee employee, String shiftTitle, int targetDay, bool isLeftResize) {
    // 🔥 FIX: Get profession info from current resize mode block key
    if (_resizeModeBlockKey == null) return;
    final keyParts = _resizeModeBlockKey!.split('|');
    if (keyParts.length != 4) return;
    final profession = EmployeeRole.values.byName(keyParts[2]);
    final professionRow = int.parse(keyParts[3]);
    
    // 🔥 FIXED: Find ONLY specific profession/row assignments, not ALL employee assignments
    final currentEntries = _assignments.entries
        .where((entry) {
          final parsed = _parseAssignmentKey(entry.key);
          return parsed != null && 
                 parsed['weekNumber'] == widget.weekNumber && 
                 parsed['shiftTitle'] == shiftTitle && 
                 entry.value.id == employee.id &&
                 parsed['profession'] == profession &&
                 parsed['professionRow'] == professionRow;
        })
        .toList();
    
    if (currentEntries.isEmpty) {
      print('WeekView: No assignments found for resize - employee: ${employee.name}, shift: $shiftTitle');
      return;
    }
    
    // Sort by day to get the span
    currentEntries.sort((a, b) {
      final dayA = _parseAssignmentKey(a.key)?['day'] ?? 0;
      final dayB = _parseAssignmentKey(b.key)?['day'] ?? 0;
      return dayA.compareTo(dayB);
    });
        
    final firstEntry = currentEntries.first;
    final lastEntry = currentEntries.last;
    final firstParsed = _parseAssignmentKey(firstEntry.key)!;
    final lastParsed = _parseAssignmentKey(lastEntry.key)!;
    
    final currentStartDay = firstParsed['day'] as int;
    final currentEndDay = lastParsed['day'] as int;
    // 🔥 profession and professionRow already defined from resize mode block key
    
    int newStartDay, newEndDay;
    
    if (isLeftResize) {
      // Resizing from left - change start day
      newStartDay = targetDay.clamp(0, currentEndDay);
      newEndDay = currentEndDay;
    } else {
      // Resizing from right - change end day
      newStartDay = currentStartDay;
      newEndDay = targetDay.clamp(currentStartDay, 6);
    }
    
    // Only update if there's an actual change
    if (newStartDay != currentStartDay || newEndDay != currentEndDay) {
      final newDuration = newEndDay - newStartDay + 1;
      print('WeekView: Resizing ${employee.name} from days $currentStartDay-$currentEndDay to $newStartDay-$newEndDay (duration: $newDuration)');
      
      // Use the NEW handleResize with correct profession info
      _handleResize(employee, shiftTitle, newStartDay, newDuration, profession, professionRow);
    }
  }

  // 🔥 GET EMPLOYEE'S PROFESSION INFO FROM ASSIGNMENTS - No more dependency loops!
  Map<String, dynamic>? _getEmployeeProfessionInfo(Employee employee, String shiftTitle) {
    final entry = _assignments.entries
        .where((e) {
          final parsed = _parseAssignmentKey(e.key);
          return parsed != null && 
                 parsed['weekNumber'] == widget.weekNumber && 
                 parsed['shiftTitle'] == shiftTitle && 
                 e.value.id == employee.id;
        })
        .firstOrNull;
    
    if (entry == null) return null;
    
    final parsed = _parseAssignmentKey(entry.key);
    if (parsed == null) return null;
    
    return {
      'profession': parsed['profession'] as EmployeeRole,
      'professionRow': parsed['professionRow'] as int,
    };
  }



  void _handleResizeEnd() {
    try {
      if (_resizeModeBlockKey == null || _dragStates == null) return;
      
      final blockKey = _resizeModeBlockKey!;
      final dragState = _dragStates![blockKey];
      
      if (dragState != null) {
      // 🔥 USE VISUAL WIDTH INSTEAD OF CURSOR POSITION - More reliable!
      final dayWidth = _getActualDayWidth(context);
      
      // Get employee and shift info from block key (format: employeeId|shiftTitle|profession|professionRow)
      final keyParts = blockKey.split('|');
      final employeeId = keyParts[0];
      final shiftTitle = keyParts[1];
      final professionName = keyParts[2];
      final professionRow = int.tryParse(keyParts[3]) ?? 0;
      
      // Find the employee
      final employee = _assignments.values.firstWhere((e) => e.id == employeeId, 
          orElse: () => Employee(id: '', name: '', category: EmployeeCategory.ab, type: EmployeeType.vakityontekija, role: EmployeeRole.varu1, shiftCycle: ShiftCycle.none));
      
      if (employee.id.isEmpty) return;
      
      // Get profession enum
      EmployeeRole? profession;
      try {
        profession = EmployeeRole.values.byName(professionName);
      } catch (e) {
        print('Invalid profession: $professionName');
        return;
      }
      
      // 🎯 VISUAL-BASED SNAPPING: Use actual visual width to determine target size
      final deltaX = dragState.currentX - dragState.startX;
      
      if (dragState.isLeftResize) {
        // 🎯 LEFT RESIZE: Calculate new start position from visual position  
        final newVisualLeft = (dragState.originalStartDay * dayWidth) + deltaX;
        final newStartDay = (newVisualLeft / dayWidth).round().clamp(0, 6).toInt();
        final originalEndDay = dragState.originalStartDay + dragState.originalDuration - 1;
        final newDuration = (originalEndDay - newStartDay + 1).clamp(1, 7).toInt();
        
        print('🎯 LEFT RESIZE: visual=${newVisualLeft}, newStart=${newStartDay}, duration=${newDuration}');
        
        if (newStartDay != dragState.originalStartDay || newDuration != dragState.originalDuration) {
          _handleResize(employee, shiftTitle, newStartDay, newDuration, profession, professionRow);
        }
      } else {
        // 🎯 RIGHT RESIZE: Calculate new duration from visual width
        final newVisualWidth = (dragState.originalDuration * dayWidth) + deltaX + 1; // +1 for border compensation
        final newDuration = (newVisualWidth / dayWidth).round().clamp(1, 7 - dragState.originalStartDay).toInt();
        
        print('🎯 RIGHT RESIZE: visual=${newVisualWidth}, duration=${newDuration}, dayWidth=${dayWidth}');
        
        if (newDuration != dragState.originalDuration) {
          _handleResize(employee, shiftTitle, dragState.originalStartDay, newDuration, profession, professionRow);
        }
      }
    }
    
    HapticFeedback.mediumImpact();
    
    // Clear drag and resize state
    setState(() {
      _dragStates = null;
      _resizeModeBlockKey = null;
      _isDragActive = false; // Allow cloud saves again
    });
    
    // 🔥 DEBOUNCED SAVE: Prevent connection errors during resize
    _scheduleCloudSave();
    } catch (e) {
      print('❌ Error during resize: $e');
      // Clear drag state on error
      setState(() {
        _dragStates = null;
        _resizeModeBlockKey = null;
        _isDragActive = false;
      });
    }
  }

  // 🔥 REMOVED DUPLICATE: dispose() method already exists above

  void _showEmployeeQuickFillMenu(Employee employee) {
    // Quick fill menu implementation
  }

  // Proper fullscreen toggle that actually works!
  void _toggleFullscreen() {
    try {
      fullscreen.toggleFullscreen();
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Fullscreen not supported on this platform');
    }
  }

  Future<void> _navigateToEmployeeSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmployeeSettingsView()),
    );
    // Refresh employee list when returning
    await _loadEmployees();
  }

  Widget _buildFullWidthEmployeeGrid() {
    // Group employees by category
    final Map<EmployeeCategory, List<Employee>> groupedEmployees = {};
    for (final employee in defaultEmployees) {
      groupedEmployees.putIfAbsent(employee.category, () => []).add(employee);
    }
    
    // Ensure all categories have an entry (even if empty)
    for (final category in EmployeeCategory.values) {
      groupedEmployees.putIfAbsent(category, () => []);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final cardWidth = 80.0;
        final cardsPerRow = (availableWidth / cardWidth).floor().clamp(1, 50);
        
        List<Widget> allGroupWidgets = [];
        
                for (final category in EmployeeCategory.values) {
          final employees = groupedEmployees[category] ?? [];
          // Filter out employees assigned for 7 days
          final availableEmployees = employees.where((employee) {
            final dayAllocation = _getEmployeeAllocation(employee, _getShiftTitlesForWeek(widget.weekNumber)[0]);
            final nightAllocation = _getEmployeeAllocation(employee, _getShiftTitlesForWeek(widget.weekNumber)[1]);
            final totalDays = dayAllocation + nightAllocation;
            return totalDays < 7;
          }).toList();
          
          final isCollapsed = _collapsedGroups[category] ?? false;
          
          // ALWAYS show category header (even for empty groups) - compact size
          allGroupWidgets.add(
            Row(
              children: [
                // 20% shorter width
                Expanded(
                  flex: 3, // 20% shorter (3/5 width instead of 4/5)
                  child: GestureDetector(
              onTap: () {
                setState(() {
                  _collapsedGroups[category] = !isCollapsed;
                });
              },
              child: Container(
                      height: 25.2, // Match employee name block height
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Reduced padding
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category),
                        borderRadius: BorderRadius.circular(4), // Smaller radius
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                            blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                        mainAxisSize: MainAxisSize.min, // Shrink to content
                  children: [
                    Icon(
                      isCollapsed ? Icons.expand_more : Icons.expand_less,
                            color: _getTextColorForCategory(category),
                            size: 12, // Smaller icon
                    ),
                          const SizedBox(width: 2), // Reduced spacing
                          Text(
                        '${_getCategoryDisplayName(category)} (${availableEmployees.length})',
                            style: TextStyle(
                              color: _getTextColorForCategory(category),
                              fontSize: 9, // Smaller text
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                          const SizedBox(width: 2), // Reduced spacing
                    GestureDetector(
                      onTap: () {
                        _showAddEmployeeDialog(category);
                      },
                      child: Container(
                              padding: const EdgeInsets.all(1), // Reduced padding
                              child: Icon(
                          Icons.add,
                                color: _getTextColorForCategory(category),
                                size: 12, // Smaller icon
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                  ),
                ),
                // Empty space on the right - more space now
                Expanded(
                  flex: 2, // More space (2/5 space)
                  child: Container(),
                ),
              ],
            ),
          );
          
          // Add employee cards if not collapsed (show even if empty)
          if (!isCollapsed) {
            if (availableEmployees.isEmpty) {
              // No longer show empty state message - worker count is shown in header
              // Just show empty space for this category
                         } else {
               // Show employee cards - ONE PER ROW
               for (final employee in availableEmployees) {
                 final dayAllocation = _getEmployeeAllocation(employee, _getShiftTitlesForWeek(widget.weekNumber)[0]);
                 final nightAllocation = _getEmployeeAllocation(employee, _getShiftTitlesForWeek(widget.weekNumber)[1]);
                 final totalDays = dayAllocation + nightAllocation;
                 
                 allGroupWidgets.add(
                   Container(
                     margin: const EdgeInsets.only(bottom: 2),
                     height: 25.2, // Fixed height for each row - matches grid rowHeight
                     child: Row(
                       children: [
                         // Employee card - 20% shorter to match headers
                         Expanded(
                           flex: 3, // Takes 3/5 of the space (20% shorter)
                           child: Draggable<Employee>(
                             data: employee,
                             feedback: Material(
                               child: Container(
                                 width: 120,
                                 height: 25.2,
                                 padding: const EdgeInsets.all(2),
                                 decoration: BoxDecoration(
                                   color: _getCategoryColor(category),
                                   border: Border.all(color: const Color(0xFF253237), width: 1), // Gunmetal border
                                   borderRadius: BorderRadius.circular(2),
                                 ),
                                 child: Center(
                                   child: Text(
                                     employee.name,
                                     style: TextStyle(
                                       color: _getTextColorForCategory(category), // Dynamic text color based on background
                                       fontSize: 10,
                                       fontWeight: FontWeight.w600,
                                     ),
                                     textAlign: TextAlign.center,
                                     overflow: TextOverflow.ellipsis,
                                   ),
                                 ),
                               ),
                             ),
                             child: Container(
                               decoration: BoxDecoration(
                                 color: totalDays == 0 ? Colors.white : 
                                        totalDays >= 7 ? const Color(0xFFC2DFE3) : const Color(0xFFE0FBFC), // White/Light blue/Light cyan
                                 border: Border.all(color: _getCategoryColor(category), width: 1),
                                 borderRadius: BorderRadius.circular(3),
                               ),
                               child: Stack(
                                 children: [
                                   Center(
                                     child: Padding(
                                       padding: const EdgeInsets.symmetric(horizontal: 2),
                                       child: Row(
                                         mainAxisAlignment: MainAxisAlignment.center,
                                         children: [
                                           Flexible(
                                     child: Text(
                                       employee.name,
                                       style: const TextStyle(
                                         fontSize: 10,
                                                 color: Color(0xFF253237), // Gunmetal text
                                         fontWeight: FontWeight.w600,
                                       ),
                                       textAlign: TextAlign.center,
                                       overflow: TextOverflow.ellipsis,
                                             ),
                                           ),
                                           // Show vacation status inline
                                           () {
                                             // Get dates for the DISPLAYED week (not current week)
                                             final weekDates = _getDatesForWeek(widget.weekNumber);
                                             final weekStart = weekDates.first;
                                             final weekEnd = weekDates.last;
                                             
                                             final allVacations = VacationManager.getEmployeeVacations(employee.id);
                                             final currentVacations = allVacations.where((vacation) {
                                               final vacationStart = DateTime(vacation.startDate.year, vacation.startDate.month, vacation.startDate.day);
                                               final vacationEnd = DateTime(vacation.endDate.year, vacation.endDate.month, vacation.endDate.day, 23, 59, 59);
                                               final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
                                               final weekEndDay = DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);
                                               
                                               return !vacationStart.isAfter(weekEndDay) && !vacationEnd.isBefore(weekStartDay);
                                             }).toList();
                                             
                                             if (currentVacations.isNotEmpty) {
                                               return Row(
                                                 mainAxisSize: MainAxisSize.min,
                                                 children: [
                                                   const SizedBox(width: 4),
                                                   Flexible(
                                                     child: Text(
                                                       currentVacations.first.getDisplayText(),
                                                       style: const TextStyle(
                                                         fontSize: 7,
                                                         color: Color(0xFF5C6B73), // Payne's gray
                                                         fontStyle: FontStyle.italic,
                                                       ),
                                                       overflow: TextOverflow.ellipsis,
                                                     ),
                                                   ),
                                                 ],
                                               );
                                             }
                                             return const SizedBox.shrink();
                                           }(),
                                         ],
                                       ),
                                     ),
                                   ),
                                   // Show allocation count
                                   if (totalDays > 0)
                                     Positioned(
                                       right: 1,
                                       top: 1,
                                       child: Container(
                                         padding: const EdgeInsets.all(1),
                                         decoration: BoxDecoration(
                                           color: totalDays >= 7 ? const Color(0xFF5C6B73) : const Color(0xFF253237), // Payne's gray or Gunmetal
                                           borderRadius: BorderRadius.circular(6),
                                         ),
                                         child: Text(
                                           '$totalDays',
                                           style: const TextStyle(
                                             fontSize: 6,
                                             color: Colors.white,
                                             fontWeight: FontWeight.bold,
                                           ),
                                         ),
                                       ),
                                     ),
                                   // Show day/night indicator
                                   if (dayAllocation > 0 || nightAllocation > 0)
                                     Positioned(
                                       left: 1,
                                       bottom: 1,
                                       child: Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           if (dayAllocation > 0)
                                             Container(
                                               width: 4,
                                               height: 4,
                                               decoration: const BoxDecoration(
                                                 color: Color(0xFFC2DFE3), // Light blue for day
                                                 shape: BoxShape.circle,
                                               ),
                                             ),
                                           if (dayAllocation > 0 && nightAllocation > 0)
                                             const SizedBox(width: 1),
                                           if (nightAllocation > 0)
                                             Container(
                                               width: 4,
                                               height: 4,
                                               decoration: const BoxDecoration(
                                                 color: Color(0xFF5C6B73), // Payne's gray for night
                                                 shape: BoxShape.circle,
                                               ),
                                             ),
                                         ],
                                       ),
                                     ),
                                 ],
                               ),
                             ),
                           ),
                         ),
                         // Right space for scrolling - more space now
                         Expanded(
                           flex: 2, // More space (2/5 space)
                           child: Container(), // Empty space for scrolling
                         ),
                       ],
                     ),
                   ),
                 );
               }
            }
          }
        }
        
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: allGroupWidgets,
          ),
        );
      },
    );
  }

  int _getEmployeeAllocation(Employee employee, String shiftTitle) {
    int count = 0;
    for (final entry in _assignments.entries) {
      if (entry.key.startsWith('${widget.weekNumber}-$shiftTitle') && entry.value.id == employee.id) {
        count++;
      }
    }
    return count;
  }



  Color _getCategoryColor(EmployeeCategory category) {
    return SharedAssignmentData.getCategoryColor(category);
  }

  Color _getTextColorForCategory(EmployeeCategory category) {
    return SharedAssignmentData.getTextColorForCategory(category);
  }

  Widget _buildUnifiedShiftView(List<String> shiftTitles) {
    return RepaintBoundary(
      key: ValueKey('unified-shift-${widget.weekNumber}-$_currentTabIndex'),
      child: Container(
        decoration: const BoxDecoration(
        color: Colors.white,
          border: Border.fromBorderSide(BorderSide(color: Color(0xFF9DB4C0), width: 1)),
        ),
            child: Row(
          key: ValueKey('shift-row-$_currentTabIndex'),
              children: [
                // Profession labels for current shift
                Container(
              key: const ValueKey('profession-labels'),
              width: 32, // Compact width to save space
              color: const Color(0xFF9DB4C0), // Cadet gray from palette
                  child: Column(
                    children: _currentTabIndex == 0 
                        ? _buildDayShiftProfessionLabels()
                        : _buildNightShiftProfessionLabels(),
                  ),
                ),
                // Calendar grid for current shift
                Expanded(
                  child: _buildSingleShiftCalendarGrid(shiftTitles[_currentTabIndex]),
                ),
              ],
            ),
      ),
    );
  }

  List<Widget> _buildDayShiftProfessionLabels() {
    return EmployeeRole.values.where((role) => _dayShiftProfessions[role] == true).expand((profession) {
      final rows = _dayShiftRows[profession] ?? 1;
      return List.generate(rows, (index) => Container(
        height: 25.2, // Match calendar grid row height
        decoration: BoxDecoration(
          color: const Color(0xFF9DB4C0), // Cadet gray background
          border: Border(bottom: BorderSide(color: const Color(0xFF5C6B73), width: 0.5)), // Payne's gray border
        ),
        child: Center(
          child: Text(
            _getCompactRoleName(profession),
            style: const TextStyle(
              color: Colors.white, // White text on cadet gray background
              fontSize: 8, // Smaller font for compact width
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ));
    }).toList();
  }

  List<Widget> _buildNightShiftProfessionLabels() {
    return EmployeeRole.values.where((role) => _nightShiftProfessions[role] == true).expand((profession) {
      final rows = _nightShiftRows[profession] ?? 1;
      return List.generate(rows, (index) => Container(
        height: 25.2, // Match calendar grid row height
        decoration: BoxDecoration(
          color: const Color(0xFF9DB4C0), // Cadet gray background
          border: Border(bottom: BorderSide(color: const Color(0xFF5C6B73), width: 0.5)), // Payne's gray border
        ),
        child: Center(
          child: Text(
            _getCompactRoleName(profession),
            style: const TextStyle(
              color: Colors.white, // White text on cadet gray background
              fontSize: 8, // Smaller font for compact width
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ));
    }).toList();
  }

  // Add compact role name function
  String _getCompactRoleName(EmployeeRole role) {
    // Use shared compact role name method
    return SharedAssignmentData.getCompactRoleName(role);
  }



  Widget _buildSingleShiftCalendarGrid(String shiftTitle) {
    const rowHeight = 25.2; // 1.4x larger (18 * 1.4)
    // 🔥 USE ACCURATE WIDTH CALCULATION  
    final dayWidth = _getActualDayWidth(context);
    
    // Calculate total rows for current shift
    int totalRows = 0;
    if (_currentTabIndex == 0) {
      // Day shift
      for (final profession in EmployeeRole.values.where((role) => _dayShiftProfessions[role] == true)) {
        totalRows += _dayShiftRows[profession] ?? 1;
      }
    } else {
      // Night shift
      for (final profession in EmployeeRole.values.where((role) => _nightShiftProfessions[role] == true)) {
        totalRows += _nightShiftRows[profession] ?? 1;
      }
    }
    
    return RepaintBoundary(
      key: ValueKey('calendar-grid-$shiftTitle-${widget.weekNumber}'),
      child: Stack(
      children: [
        // Grid background
          RepaintBoundary(
            key: ValueKey('grid-bg-$shiftTitle'),
            child: Column(
          children: List.generate(totalRows, (row) => 
            Container(
              height: rowHeight,
              child: Row(
                children: List.generate(7, (day) => 
                  Expanded(
                    child: DragTarget<Employee>(
                      onAcceptWithDetails: (details) {
                        _handleDropToLane(details.data, day, shiftTitle, row);
                      },
                      hitTestBehavior: HitTestBehavior.opaque, // Ensure reliable hit detection
                      builder: (context, candidateData, rejectedData) {
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[200]!, width: 0.5),
                            color: candidateData.isNotEmpty ? Colors.green.withOpacity(0.3) : null,
                          ),
                          child: const SizedBox.expand(), // Ensure full hit area
                        );
                      },
                        ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Assignment blocks for current shift
        ..._buildShiftAssignmentBlocks(shiftTitle, dayWidth, rowHeight),
      ],
      ),
    );
  }

  List<Widget> _buildShiftAssignmentBlocks(String shiftTitle, double dayWidth, double rowHeight) {
    List<Widget> blocks = [];
    Set<String> processedEmployees = {};
    
    // 🔥 FIXED: Group assignments by employee to create proper multi-day blocks
    final employeeBlocks = <String, List<String>>{};
    
    for (final entry in _assignments.entries) {
      final parsed = _parseAssignmentKey(entry.key);
      if (parsed != null && 
          parsed['weekNumber'] == widget.weekNumber && 
          parsed['shiftTitle'] == shiftTitle) {
        
        final profession = parsed['profession'] as EmployeeRole;
        final professionRow = parsed['professionRow'] as int;
        final employeeKey = '${entry.value.id}|${profession.name}|$professionRow';
        
        employeeBlocks.putIfAbsent(employeeKey, () => []);
        employeeBlocks[employeeKey]!.add(entry.key);
      }
    }
    
    // Render each employee's continuous blocks
    for (final entry in employeeBlocks.entries) {
      final employeeKey = entry.key;
      final assignmentKeys = entry.value;
      
      if (processedEmployees.contains(employeeKey)) continue;
      processedEmployees.add(employeeKey);
      
      // Get employee and profession info
      final keyParts = employeeKey.split('|');
      final employeeId = keyParts[0];
      final professionName = keyParts[1];
      final professionRow = int.parse(keyParts[2]);
      
      final employee = _assignments.values.firstWhere((e) => e.id == employeeId);
      final profession = EmployeeRole.values.byName(professionName);
      
      // Convert to absolute lane
      final absoluteLane = _getProfessionToAbsoluteLane(profession, professionRow, shiftTitle);
      if (absoluteLane == -1) continue;
      
      // Get all days for this employee block
      final days = assignmentKeys
          .map((key) => _parseAssignmentKey(key)?['day'] as int?)
          .where((day) => day != null)
          .cast<int>()
          .toList()..sort();
      
      if (days.isEmpty) continue;
      
      // Create block key for drag state
      final blockKey = _generateBlockKey(employee, shiftTitle, profession, professionRow);
      final dragState = _dragStates?[blockKey];
      
      // 🔥 FIX: Calculate block span from continuous days (handle gaps)
      final startDay = days.first;
      final endDay = days.last;
      final duration = days.length; // Use actual count, not range (handles gaps)
      print('🔥 BLOCK: ${employee.name} in ${profession.name}:$professionRow -> days:$days -> duration:$duration');
      
      // 🔥 FIX: Visual position for continuous days only  
      double visualLeft = startDay * dayWidth;
      double visualWidth = _calculateContinuousWidth(days, startDay, dayWidth);
      
      // Apply drag state for visual feedback
      if (dragState != null && _resizeModeBlockKey == blockKey) {
        final deltaX = dragState.currentX - dragState.startX;
        
        if (dragState.isLeftResize) {
          visualLeft = (dragState.originalStartDay * dayWidth) + deltaX;
          final originalEnd = dragState.originalStartDay + dragState.originalDuration - 1;
          visualWidth = (originalEnd * dayWidth + dayWidth) - visualLeft - 1;
        } else {
          // 🔥 FIX: Right resize - adjust width from original position, not from current visualLeft
          visualWidth = ((dragState.originalStartDay * dayWidth) + (dragState.originalDuration * dayWidth) + deltaX) - (dragState.originalStartDay * dayWidth) - 1;
        }
        
        visualLeft = visualLeft.clamp(0, 6 * dayWidth);
        visualWidth = visualWidth.clamp(dayWidth * 0.2, (7 * dayWidth) - visualLeft);
      }
      
      blocks.add(
        Positioned(
          left: visualLeft,
          top: absoluteLane * rowHeight,
          width: visualWidth,
          height: rowHeight - 1,
          child: _buildAssignmentBlock(employee, shiftTitle, startDay, absoluteLane),
        ),
      );
    }
    
    return blocks;
  }

  /// Calculate width for continuous days (handles gaps in assignments)
  double _calculateContinuousWidth(List<int> days, int startDay, double dayWidth) {
    if (days.isEmpty) return dayWidth - 1;
    
    // Find continuous segments from startDay
    int continuousCount = 1;
    for (int i = 1; i < days.length; i++) {
      if (days[i] == days[i-1] + 1) {
        continuousCount++;
      } else {
        break; // Stop at first gap
      }
    }
    
    return (continuousCount * dayWidth) - 1;
  }

  Widget _buildUnifiedCalendarGrid(List<String> shiftTitles) {
    const rowHeight = 25.2; // 1.4x larger (18 * 1.4)
    // 🔥 USE ACCURATE WIDTH CALCULATION
    final dayWidth = _getActualDayWidth(context);
    
    // Calculate total rows for both shifts
    int dayShiftRows = 0;
    for (final profession in EmployeeRole.values.where((role) => _dayShiftProfessions[role] == true)) {
      dayShiftRows += _dayShiftRows[profession] ?? 1;
    }
    
    int nightShiftRows = 0;
    for (final profession in EmployeeRole.values.where((role) => _nightShiftProfessions[role] == true)) {
      nightShiftRows += _nightShiftRows[profession] ?? 1;
    }
    
    return Stack(
      children: [
        // Grid background
        Column(
          children: [
            // Day shift header
            Container(
              height: 20,
              color: Colors.grey[200],
              child: Center(
                child: Text(
                  shiftTitles[0],
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ),
            // Day shift grid
            ...List.generate(dayShiftRows, (row) => 
              Container(
                height: rowHeight,
                child: Row(
                  children: List.generate(7, (day) => 
                    Expanded(
                      child: DragTarget<Employee>(
                                                 onAcceptWithDetails: (details) {
                           _handleDropToLane(details.data, day, shiftTitles[0], row);
                         },
                        builder: (context, candidateData, rejectedData) {
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[200]!, width: 0.5),
                              color: candidateData.isNotEmpty ? Colors.green.withOpacity(0.3) : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Night shift header
            Container(
              height: 20,
              color: Colors.grey[300],
              child: Center(
                child: Text(
                  shiftTitles[1],
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ),
            // Night shift grid
            ...List.generate(nightShiftRows, (row) => 
              Container(
                height: rowHeight,
                child: Row(
                  children: List.generate(7, (day) => 
                    Expanded(
                      child: DragTarget<Employee>(
                                                 onAcceptWithDetails: (details) {
                           _handleDropToLane(details.data, day, shiftTitles[1], row);
                         },
                        builder: (context, candidateData, rejectedData) {
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[200]!, width: 0.5),
                              color: candidateData.isNotEmpty ? Colors.green.withOpacity(0.3) : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Assignment blocks for both shifts
                    // 🔥 REMOVED: Old single-day rendering that conflicts with proper multi-day blocks
      ],
    );
  }

  List<Widget> _buildAllAssignmentBlocks(List<String> shiftTitles, double dayWidth, double rowHeight, int dayShiftOffset) {
    List<Widget> blocks = [];
    Set<String> processedAssignments = {};
    
    // Add day shift blocks
    for (final entry in _assignments.entries) {
      if (!processedAssignments.contains(entry.key)) {
        final parsed = _parseAssignmentKey(entry.key);
        if (parsed != null && 
            parsed['weekNumber'] == widget.weekNumber && 
            parsed['shiftTitle'] == shiftTitles[0]) {
          
          final startDay = parsed['day'] as int;
          final profession = parsed['profession'] as EmployeeRole;
          final professionRow = parsed['professionRow'] as int;
          
          // 🔥 CONVERT PROFESSION + ROW TO ABSOLUTE LANE FOR RENDERING
          final absoluteLane = _getProfessionToAbsoluteLane(profession, professionRow, shiftTitles[0]);
          if (absoluteLane == -1) continue; // Profession not visible or invalid row
          
          // Check if this block is being dragged
          final blockKey = '${entry.value.id}-${shiftTitles[0]}-$absoluteLane-$startDay';
          final dragState = _dragStates?[blockKey];
          
          // SINGLE-DAY CELL RENDERING (no block combining)
          int duration = 1; // Always render as single day
          
          // Calculate visual position - single cell only
          double visualLeft = startDay * dayWidth;
          double visualWidth = dayWidth - 1; // Single cell width
          
          if (dragState != null && _resizeModeBlockKey == blockKey) {
            final deltaX = dragState.currentX - dragState.startX;
            
            if (dragState.isLeftResize) {
              // Left resize - adjust start position and width
              visualLeft = (dragState.originalStartDay * dayWidth) + deltaX;
              final originalEnd = dragState.originalStartDay + dragState.originalDuration - 1;
              visualWidth = (originalEnd * dayWidth + dayWidth) - visualLeft - 1;
            } else {
              // 🔥 FIX: Right resize - adjust width from original position, not from current visualLeft
              visualWidth = ((dragState.originalStartDay * dayWidth) + (dragState.originalDuration * dayWidth) + deltaX) - (dragState.originalStartDay * dayWidth) - 1;
            }
            
            // Clamp to grid boundaries
            visualLeft = visualLeft.clamp(0, 6 * dayWidth);
            visualWidth = visualWidth.clamp(dayWidth * 0.2, (7 * dayWidth) - visualLeft);
          }
          
          blocks.add(
            Positioned(
              left: visualLeft,
              top: 20 + (absoluteLane * rowHeight), // 20 for header
              width: visualWidth,
              height: rowHeight - 1,
              child: _buildAssignmentBlock(entry.value, shiftTitles[0], startDay, absoluteLane),
            ),
          );
          processedAssignments.add(entry.key);
        }
      }
    }
    
    // Add night shift blocks (offset by day shift rows + header)
    for (final entry in _assignments.entries) {
      if (!processedAssignments.contains(entry.key)) {
        final parsed = _parseAssignmentKey(entry.key);
        if (parsed != null && 
            parsed['weekNumber'] == widget.weekNumber && 
            parsed['shiftTitle'] == shiftTitles[1]) {
          
          final startDay = parsed['day'] as int;
          final profession = parsed['profession'] as EmployeeRole;
          final professionRow = parsed['professionRow'] as int;
          
          // 🔥 CONVERT PROFESSION + ROW TO ABSOLUTE LANE FOR RENDERING
          final absoluteLane = _getProfessionToAbsoluteLane(profession, professionRow, shiftTitles[1]);
          if (absoluteLane == -1) continue; // Profession not visible or invalid row
          
          // Check if this block is being dragged
          final blockKey = '${entry.value.id}-${shiftTitles[1]}-$absoluteLane-$startDay';
          final dragState = _dragStates?[blockKey];
          
          // SINGLE-DAY CELL RENDERING (no block combining)
          int duration = 1; // Always render as single day
          
          // Calculate visual position - single cell only
          double visualLeft = startDay * dayWidth;
          double visualWidth = dayWidth - 1; // Single cell width
          
          if (dragState != null && _resizeModeBlockKey == blockKey) {
            final deltaX = dragState.currentX - dragState.startX;
            
            if (dragState.isLeftResize) {
              // Left resize - adjust start position and width
              visualLeft = (dragState.originalStartDay * dayWidth) + deltaX;
              final originalEnd = dragState.originalStartDay + dragState.originalDuration - 1;
              visualWidth = (originalEnd * dayWidth + dayWidth) - visualLeft - 1;
            } else {
              // 🔥 FIX: Right resize - adjust width from original position, not from current visualLeft
              visualWidth = ((dragState.originalStartDay * dayWidth) + (dragState.originalDuration * dayWidth) + deltaX) - (dragState.originalStartDay * dayWidth) - 1;
            }
            
            // Clamp to grid boundaries
            visualLeft = visualLeft.clamp(0, 6 * dayWidth);
            visualWidth = visualWidth.clamp(dayWidth * 0.2, (7 * dayWidth) - visualLeft);
          }
          
          blocks.add(
            Positioned(
              left: visualLeft,
              top: 20 + (dayShiftOffset * rowHeight) + 20 + (absoluteLane * rowHeight), // Day rows + night header
              width: visualWidth,
              height: rowHeight - 1,
              child: _buildAssignmentBlock(entry.value, shiftTitles[1], startDay, absoluteLane),
            ),
          );
          processedAssignments.add(entry.key);
        }
      }
    }
    
    return blocks;
  }

  Widget _buildAssignmentBlock(Employee employee, String shiftTitle, int blockStartDay, int blockLane) {
    // 🔥 FIX: Use THIS specific block's lane to get the correct profession info
    final professionInfo = _getAbsoluteLaneToProfession(blockLane, shiftTitle);
    if (professionInfo == null) {
      // Fallback if profession info not found
      return Container();
    }
    
    final profession = professionInfo['profession'] as EmployeeRole;
    final professionRow = professionInfo['row'] as int;
    final blockKey = _generateBlockKey(employee, shiftTitle, profession, professionRow);
    final isInResizeMode = _resizeModeBlockKey == blockKey;
    
    print('🔧 BLOCK: ${employee.name} at lane $blockLane -> ${profession.name}.${professionRow} -> blockKey: $blockKey, resizeMode: $isInResizeMode');
    
    return RepaintBoundary(
      key: ValueKey(blockKey),
      child: Builder(
        builder: (context) {
          // 🎨 VISUAL STRETCH ANIMATION (doesn't affect resize logic)
          Matrix4? visualTransform;
          bool showResizeHighlight = false;
          
          if (isInResizeMode && _dragStates?[blockKey] != null) {
            final dragState = _dragStates![blockKey]!;
            final deltaX = dragState.currentX - dragState.startX;
            final dayWidth = _getActualDayWidth(context);
            showResizeHighlight = true;
            
            if (dragState.isLeftResize) {
              // 🎨 LEFT RESIZE: Block visually follows cursor - left edge moves
              final newVisualLeft = (dragState.originalStartDay * dayWidth) + deltaX;
              final clampedLeft = newVisualLeft.clamp(0.0, 6 * dayWidth);
              final originalRight = (dragState.originalStartDay + dragState.originalDuration) * dayWidth;
              final newWidth = originalRight - clampedLeft;
              
              visualTransform = Matrix4.identity()
                ..translate(clampedLeft - (dragState.originalStartDay * dayWidth), 0.0)
                ..scale(newWidth / (dragState.originalDuration * dayWidth), 1.0);
            } else {
              // 🎨 RIGHT RESIZE: Block visually follows cursor - right edge moves
              final newVisualWidth = (dragState.originalDuration * dayWidth) + deltaX;
              final clampedWidth = newVisualWidth.clamp(dayWidth * 0.5, dayWidth * (7 - dragState.originalStartDay));
              
              visualTransform = Matrix4.identity()
                ..scale(clampedWidth / (dragState.originalDuration * dayWidth), 1.0);
            }
          }
          
          return Transform(
            transform: visualTransform ?? Matrix4.identity(),
            child: Container(
              decoration: BoxDecoration(
                // 🎨 VISUAL HIGHLIGHT during resize
                border: showResizeHighlight 
                  ? Border.all(color: Colors.blue.withOpacity(0.7), width: 2)
                  : null,
                borderRadius: BorderRadius.circular(4),
                boxShadow: showResizeHighlight ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 6.0,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () {
                  // 🔥 ONLY LONG PRESS ACTIVATES RESIZE MODE!
                  _toggleResizeMode(employee, shiftTitle, blockStartDay, blockLane);
                  HapticFeedback.mediumImpact(); // Haptic feedback for resize activation
                },
                child: isInResizeMode 
                  ? _buildResizeModeBlock(employee, shiftTitle, blockStartDay, blockLane)
                  : _buildDraggableBlock(employee, shiftTitle, blockStartDay, blockLane),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDraggableBlock(Employee employee, String shiftTitle, int blockStartDay, int blockLane) {
    return Draggable<Employee>(
                    data: employee,
                    onDragStarted: () {
                      // Store original assignment for potential restoration
                      _dragOriginalAssignment = {
                        'employee': employee,
                        'shiftTitle': shiftTitle,
                        'blockStartDay': blockStartDay,
                        'blockLane': blockLane,
                      };
                      _removeSpecificBlock(employee, shiftTitle, blockStartDay, blockLane);
                    },
                    onDragEnd: (details) {
                      // If drag ended without successful drop, restore the original assignment
                      if (!details.wasAccepted && _dragOriginalAssignment != null) {
                        final original = _dragOriginalAssignment!;
                        final originalEmployee = original['employee'] as Employee;
                        final originalShift = original['shiftTitle'] as String;
                        final originalDay = original['blockStartDay'] as int;
                        final originalLane = original['blockLane'] as int;
                        
                        // Restore original assignment
                        final professionInfo = _getAbsoluteLaneToProfession(originalLane, originalShift);
                        if (professionInfo != null) {
                          final profession = professionInfo['profession'] as EmployeeRole;
                          final professionRow = professionInfo['row'] as int;
                          final key = _generateAssignmentKey(widget.weekNumber, originalShift, originalDay, profession, professionRow);
                          
                          setState(() {
                            SharedAssignmentData.setAssignmentForYear(_currentYear, key, originalEmployee);
                          });
                          
                          // 🔥 INSTANT UI + DEBOUNCED CLOUD SAVE
                          _scheduleCloudSave();
                          
                          // 🔥 REMOVED SPAM: Silent restoration
                          print('WeekView: ↶ ${originalEmployee.name} restored to original position');
                        }
                      }
                      _dragOriginalAssignment = null;
                    },
                    feedback: Material(
                      child: Container(
                        width: 80,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.grey[600]?.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey[400]!, width: 1),
                        ),
                        child: Center(
                          child: Text(
                            employee.name,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[400]?.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
      ),
      child: _buildBlockContainer(employee),
    );
  }

  Widget _buildResizeModeBlock(Employee employee, String shiftTitle, int blockStartDay, int blockLane) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildBlockContainer(employee),
        ..._buildResizeHandles(employee, shiftTitle, blockStartDay, blockLane),
      ],
    );
  }

  Widget _buildBlockContainer(Employee employee) {
    final blockKey = '${employee.id}-${_currentTabIndex == 0 ? _getShiftTitlesForWeek(widget.weekNumber)[0] : _getShiftTitlesForWeek(widget.weekNumber)[1]}';
    final isInResizeMode = _resizeModeBlockKey?.startsWith('${employee.id}-') == true;
    final isBeingDragged = _dragStates?.containsKey(blockKey) == true;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: isInResizeMode 
            ? _getCategoryColor(employee.category).withOpacity(0.9)
            : _getCategoryColor(employee.category),
        borderRadius: BorderRadius.circular(isInResizeMode ? 6 : 4),
        border: Border.all(
          color: isInResizeMode 
              ? Colors.white 
              : Colors.grey[400]!, 
          width: isInResizeMode ? 2 : 1
        ),
        boxShadow: [
          BoxShadow(
            color: isInResizeMode 
                ? Colors.blue.withOpacity(0.3)
                : Colors.black12,
            blurRadius: isInResizeMode ? 6 : 2,
            offset: isInResizeMode 
                ? const Offset(0, 3)
                : const Offset(1, 1),
            spreadRadius: isInResizeMode ? 1 : 0,
          ),
        ],
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: isInResizeMode ? 1.05 : 1.0,
                    child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: isInResizeMode ? 12 : 11,
              color: _getTextColorForCategory(employee.category),
              fontWeight: isInResizeMode ? FontWeight.bold : FontWeight.w600,
            ),
                      child: Text(
                        employee.name,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
        ),
      ),
    );
  }



  void _handleBlockResize(DragUpdateDetails details, Employee employee, String shiftTitle) {
    // Find the assignment
    final allKeys = _assignments.entries
        .where((entry) => entry.value.id == employee.id && entry.key.startsWith('${widget.weekNumber}-$shiftTitle'))
        .map((e) => e.key)
        .toList();
    
    if (allKeys.isNotEmpty) {
      // 🔥 FIXED: Sort using NEW key format parsing
      allKeys.sort((a, b) {
        final dayA = _parseAssignmentKey(a)?['day'] ?? 0;
        final dayB = _parseAssignmentKey(b)?['day'] ?? 0;
        return dayA.compareTo(dayB);
      });
      
      final firstKey = allKeys.first;
      final lastKey = allKeys.last;
      final firstParsed = _parseAssignmentKey(firstKey);
      final lastParsed = _parseAssignmentKey(lastKey);
      
      if (firstParsed != null && lastParsed != null) {
        final startDay = firstParsed['day'] as int;
        final endDay = lastParsed['day'] as int;
        final profession = firstParsed['profession'] as EmployeeRole;
        final professionRow = firstParsed['professionRow'] as int;
        
        // Get current position
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final localPosition = renderBox.globalToLocal(details.globalPosition);
          // 🔥 USE ACCURATE WIDTH CALCULATION
          final dayWidth = _getActualDayWidth(context);
          final gridLeft = 32.0; // Profession column width
          final relativeX = localPosition.dx - gridLeft;
          final targetDay = (relativeX / dayWidth).round().clamp(0, 6); // 🔥 SNAP TO NEAREST CELL
          
          // Determine if resizing from left or right edge
          final blockLeft = startDay * dayWidth;
          final blockRight = (endDay + 1) * dayWidth;
          final distanceToLeft = (localPosition.dx - gridLeft - blockLeft).abs();
          final distanceToRight = (localPosition.dx - gridLeft - blockRight).abs();
          
          if (distanceToLeft < distanceToRight && distanceToLeft < 20) {
            // Resize from left (change start day)
            final newStartDay = targetDay.clamp(0, endDay);
            final newDuration = endDay - newStartDay + 1;
            if (newStartDay != startDay) {
              _handleResize(employee, shiftTitle, newStartDay, newDuration, profession, professionRow);
            }
          } else if (distanceToRight < 20) {
            // Resize from right (change duration)
            final newDuration = (targetDay - startDay + 1).clamp(1, 7 - startDay);
            if (newDuration != (endDay - startDay + 1)) {
              _handleResize(employee, shiftTitle, startDay, newDuration, profession, professionRow);
            }
          }
        }
      }
    }
  }

  double _calculateCalendarHeight() {
    const double rowHeight = 25.2;
    
    // Calculate total rows for current shift ONLY (not both!)
    int totalRows = 0;
    if (_currentTabIndex == 0) {
      // Day shift
      for (final profession in EmployeeRole.values.where((role) => _dayShiftProfessions[role] == true)) {
        totalRows += _dayShiftRows[profession] ?? 1;
      }
    } else {
      // Night shift  
      for (final profession in EmployeeRole.values.where((role) => _nightShiftProfessions[role] == true)) {
        totalRows += _nightShiftRows[profession] ?? 1;
      }
    }
    
    return (totalRows * rowHeight) + 2; // +2 for borders, no tab height needed
  }

  @override
  Widget build(BuildContext context) {
    final shiftTitles = _getShiftTitlesForWeek(widget.weekNumber);
    final dates = _getDatesForWeek(widget.weekNumber);

// Performance optimized with GPU acceleration

    return GestureDetector(
      onTap: () {
        // Exit resize mode when tapping outside
        if (_resizeModeBlockKey != null) {
          setState(() {
            _resizeModeBlockKey = null;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE0FBFC), // Light cyan background
                body: SafeArea(
          child: Center(
            child: Container(
              width: kIsWeb ? 800 : null, // A4 portrait width for PC/Web
              child: Column(
          children: [
              // Combined week navigation + tabs bar
          Container(
                height: 32, // Reduced from 40
                margin: const EdgeInsets.all(2), // Reduced from 4
            decoration: BoxDecoration(
                  color: const Color(0xFF253237), // Gunmetal
                  border: Border.all(color: const Color(0xFF9DB4C0), width: 1),
                ),
                child: Row(
                  children: [
                    // Menu button
                    SizedBox(
                      width: 32,
                      child: IconButton(
                        onPressed: () => _showMainMenu(context),
                        icon: const Icon(Icons.menu, size: 14, color: Colors.white),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    // Week navigation
                    SizedBox(
                      width: 32,
                      child: IconButton(
                        onPressed: widget.weekNumber > 1 
                            ? () => widget.onWeekChanged?.call(widget.weekNumber - 1)
                            : null,
                        icon: const Icon(Icons.arrow_back_ios, size: 12),
                        color: widget.weekNumber > 1 ? Colors.white : Colors.white38,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Center(
                        child: Text(
                          'EDIT MODE\n$_currentYear W${widget.weekNumber}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: IconButton(
                        onPressed: widget.weekNumber < 52 
                            ? () => widget.onWeekChanged?.call(widget.weekNumber + 1)
                            : null,
                        icon: const Icon(Icons.arrow_forward_ios, size: 12),
                        color: widget.weekNumber < 52 ? Colors.white : Colors.white38,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    // Current week button
                    SizedBox(
                      width: 32,
                      child: IconButton(
                        onPressed: _goToCurrentWeek,
                        icon: const Icon(Icons.today, size: 14, color: Colors.white),
                        padding: EdgeInsets.zero,
                        tooltip: 'Go to Current Week & Year',
                      ),
                    ),
                    // Day/Night shift tabs
                    Expanded(
            child: Row(
              children: [
                          // Day shift tab
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (_currentTabIndex != 0) {
                                  setState(() => _currentTabIndex = 0);
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _currentTabIndex == 0 ? const Color(0xFF5C6B73) : const Color(0xFF9DB4C0), 
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _currentTabIndex == 0 ? const Color(0xFFE0FBFC) : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    shiftTitles[0].split('/')[0].trim(), // Just show "A", "B", etc.
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _currentTabIndex == 0 ? Colors.white : const Color(0xFF253237),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Night shift tab
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (_currentTabIndex != 1) {
                                  setState(() => _currentTabIndex = 1);
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _currentTabIndex == 1 ? const Color(0xFF5C6B73) : const Color(0xFF9DB4C0),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _currentTabIndex == 1 ? const Color(0xFFE0FBFC) : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    shiftTitles[1].split('/')[0].trim(), // Just show "A", "B", etc.
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _currentTabIndex == 1 ? Colors.white : const Color(0xFF253237),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // YEARLY VIEW BUTTON - RIGHT SIDE OF BAR!
                    SizedBox(
                      width: 32,
                      child: IconButton(
                        onPressed: () {
                          // 🔥 FIX: Don't wait for async save during UI navigation
                          if (_hasPendingChanges) {
                            _forceSave();
                          }
                          widget.onViewChanged?.call('DISPLAY');
                          HapticFeedback.lightImpact();
                        },
                        icon: const Icon(Icons.calendar_view_month, size: 14, color: Colors.white),
                        padding: EdgeInsets.zero,
                        tooltip: 'Display Mode',
                      ),
                    ),
                  ],
                ),
              ),
              
              // Compact day header
                Container(
                height: 32, // Reduced from 40
                margin: const EdgeInsets.fromLTRB(2, 0, 2, 0), // Reduced margins
                decoration: BoxDecoration(
                  color: const Color(0xFFC2DFE3), // Light blue from palette
                  border: Border.all(color: const Color(0xFF9DB4C0), width: 1), // Cadet gray border
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32, // Reduced from 44
                      child: GestureDetector(
                        onLongPress: () {
                          // 🔧 DEBUG: Long press to force refresh profession data
                          print('🔧 Long press detected - forcing profession data refresh');
                          _forceRefreshProfessionData();
                        },
                        child: IconButton(
                          icon: const Icon(Icons.settings, size: 12, color: Colors.black87), // Smaller icon
                          onPressed: _showProfessionEditDialog,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: _buildDayHeaders(dates),
                      ),
                    ),
                  ],
                ),
              ),
          
              // Calendar section with dynamic height - no top margin
              Container(
                height: _calculateCalendarHeight(),
                margin: const EdgeInsets.fromLTRB(2, 0, 2, 0), // No top margin
              child: _buildUnifiedShiftView(shiftTitles),
          ),

          // Show workers button when section is hidden
          if (!_showWorkerSection) Container(
                height: 28, // Reduced from 32
                margin: const EdgeInsets.fromLTRB(2, 0, 2, 0), // FIXED: No bottom margin to remove gap
            decoration: BoxDecoration(
                  color: const Color(0xFFC2DFE3), // Light blue
                  border: Border.all(color: const Color(0xFF9DB4C0), width: 1), // Cadet gray border
            ),
            child: Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showWorkerSection = true),
                    icon: const Icon(Icons.visibility, size: 12), // Smaller icon
                    label: const Text('Show Workers', style: TextStyle(fontSize: 10)), // Smaller text
                style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF253237), // Gunmetal text
                      padding: EdgeInsets.zero, // Remove padding
                      minimumSize: const Size(0, 0), // Remove minimum size
                ),
              ),
            ),
          ),

              // Worker list - takes remaining space with strict overflow control
              if (_showWorkerSection) Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(2, 0, 2, 0), // No bottom margin to prevent overflow
            decoration: BoxDecoration(
              color: Colors.white,
                    border: Border.all(color: const Color(0xFF9DB4C0), width: 1),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        height: constraints.maxHeight - 4, // Reserve 4px for internal padding
                        child: ClipRect(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: _buildFullWidthEmployeeGrid(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                      ),
                    ],
                  ),
                ),
            ),
          ),
      ),
    );
  }

  // Add main menu function
  void _showMainMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF253237),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('EDIT MODE', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // 🔥 FIX: Don't wait for async save during UI navigation
                if (_hasPendingChanges) {
                  _forceSave();
                }
                widget.onViewChanged?.call('EDIT');
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.white),
              title: const Text('DISPLAY MODE', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // 🔥 FIX: Don't wait for async save during UI navigation
                if (_hasPendingChanges) {
                  _forceSave();
                }
                widget.onViewChanged?.call('DISPLAY');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.white),
              title: const Text('TYÖNTEKIJÄT', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _navigateToEmployeeSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen, color: Colors.white),
              title: const Text('FULLSCREEN', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _toggleFullscreen();
              },
            ),
            const Divider(color: Colors.white54),
            ListTile(
              leading: const Icon(Icons.account_circle, color: Colors.white),
              title: Text(AuthService.currentUser?.email ?? 'User', style: const TextStyle(color: Colors.white)),
              subtitle: const Text('Account', style: TextStyle(color: Colors.white70)),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
              onTap: () async {
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }





    List<Widget> _buildDayHeaders(List<DateTime> dates) {
    const List<String> weekdays = ['MA', 'TI', 'KE', 'TO', 'PE', 'LA', 'SU'];
    return dates.asMap().entries.map((entry) {
      final index = entry.key;
      final date = entry.value;
      // Since we start from Tuesday, map index 0->TI, 1->KE, 2->TO, 3->PE, 4->LA, 5->SU, 6->MA
      const dayOrder = ['TI', 'KE', 'TO', 'PE', 'LA', 'SU', 'MA'];
      
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 1), // Reduced from 2
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayOrder[index],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 10, // Reduced from 12
                  color: Color(0xFF253237), // Gunmetal
                ),
              ),
              Text(
                '${date.day}.${date.month}',
                style: const TextStyle(
                  fontSize: 8, // Reduced from 10
                  color: Color(0xFF5C6B73), // Payne's gray
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildResizeHandles(Employee employee, String shiftTitle, int blockStartDay, int blockLane) {
    // 🔥 FIX: Use THIS specific block's lane to get the correct profession info
    final professionInfo = _getAbsoluteLaneToProfession(blockLane, shiftTitle);
    if (professionInfo == null) return [];
    
    final profession = professionInfo['profession'] as EmployeeRole;
    final professionRow = professionInfo['row'] as int;
    final blockKey = _generateBlockKey(employee, shiftTitle, profession, professionRow);
    
    // 🔥 FIND THE SPAN USING PROFESSION-BASED KEYS!
    final thisBlockKeys = <String>[];
    
    // 🔥 FIX: Find ONLY this specific profession/row assignments, not ALL employee assignments
    final employeeKeys = _assignments.entries
        .where((entry) {
          final parsed = _parseAssignmentKey(entry.key);
          return parsed != null && 
                 parsed['weekNumber'] == widget.weekNumber && 
                 parsed['shiftTitle'] == shiftTitle && 
                 entry.value.id == employee.id &&
                 parsed['profession'] == profession &&
                 parsed['professionRow'] == professionRow;
        })
        .map((e) => e.key)
        .toList();
    
    if (employeeKeys.isNotEmpty) {
      // Sort by day to get the span
      employeeKeys.sort((a, b) {
        final parsedA = _parseAssignmentKey(a);
        final parsedB = _parseAssignmentKey(b);
        final dayA = parsedA?['day'] ?? 0;
        final dayB = parsedB?['day'] ?? 0;
        return dayA.compareTo(dayB);
      });
      thisBlockKeys.addAll(employeeKeys);
    }
    
    if (thisBlockKeys.isEmpty) return [];
    
    final dayIndices = thisBlockKeys
        .map((key) => _parseAssignmentKey(key)?['day'] ?? 0)
        .toList()..sort();
    
    final startIndex = dayIndices.first;
    final endIndex = dayIndices.last;
    final blockWidth = endIndex - startIndex + 1;
    
    final canResizeLeft = blockWidth > 1 || startIndex > 0;
    final canResizeRight = blockWidth > 1 || endIndex < 6;
    
    final handles = <Widget>[];
    
    // Check if we're currently resizing
    final dragState = _dragStates?[blockKey];
    final isLeftActive = dragState?.isLeftResize == true;
    final isRightActive = dragState?.isLeftResize == false;
    
    if (canResizeLeft) {
      handles.add(
        Positioned(
          left: -2.0,
          top: -4.0,
          bottom: -4.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _handleResizeStart(details, employee, shiftTitle, true),
            onPanUpdate: (details) => _handleLeftResize(details, employee, shiftTitle),
            onPanEnd: (details) => _handleResizeEnd(),
            child: Container(
              width: 24,
              decoration: BoxDecoration(
                color: isLeftActive 
                    ? Colors.green[600]  
                    : (dragState != null ? Colors.grey[400] : Colors.blue[800]),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                ),
                border: Border.all(
                  color: isLeftActive ? Colors.white : Colors.grey[300]!, 
                  width: isLeftActive ? 3 : 2
                ),
                boxShadow: isLeftActive ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
              child: Center(
                child: Icon(
                  Icons.keyboard_double_arrow_left, 
                  size: isLeftActive ? 18 : 16, 
                  color: isLeftActive ? Colors.white : (dragState != null ? Colors.grey[600] : Colors.white),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    if (canResizeRight) {
      handles.add(
        Positioned(
          right: -2.0,
          top: -4.0,
          bottom: -4.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _handleResizeStart(details, employee, shiftTitle, false),
            onPanUpdate: (details) => _handleRightResize(details, employee, shiftTitle),
            onPanEnd: (details) => _handleResizeEnd(),
            child: Container(
              width: 24,
              decoration: BoxDecoration(
                color: isRightActive 
                    ? Colors.green[600]  
                    : (dragState != null ? Colors.grey[400] : Colors.blue[800]),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
                border: Border.all(
                  color: isRightActive ? Colors.white : Colors.grey[300]!, 
                  width: isRightActive ? 3 : 2
                ),
                boxShadow: isRightActive ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
              child: Center(
                child: Icon(
                  Icons.keyboard_double_arrow_right, 
                  size: isRightActive ? 18 : 16, 
                  color: isRightActive ? Colors.white : (dragState != null ? Colors.grey[600] : Colors.white),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return handles;
  }

  /// Force refresh all profession data (debug/fix method)
  void _forceRefreshProfessionData() {
    print('🔧 FORCING PROFESSION DATA REFRESH for week ${widget.weekNumber}');
    
    // Clear current data
    _weekDayShiftProfessions.remove(widget.weekNumber);
    _weekNightShiftProfessions.remove(widget.weekNumber);
    _weekDayShiftRows.remove(widget.weekNumber);
    _weekNightShiftRows.remove(widget.weekNumber);
    
    // Reinitialize with defaults
    _weekDayShiftProfessions[widget.weekNumber] = Map.from(_getDefaultDayShiftProfessions());
    _weekNightShiftProfessions[widget.weekNumber] = Map.from(_getDefaultNightShiftProfessions());
    _weekDayShiftRows[widget.weekNumber] = Map.from(_getDefaultDayShiftRows());
    _weekNightShiftRows[widget.weekNumber] = Map.from(_getDefaultNightShiftRows());
    
    // Save to database
    _saveProfessionSettings();
    
    // Update UI
    if (mounted) {
      setState(() {});
    }
    
    print('✅ Profession data refreshed for week ${widget.weekNumber}');
  }

  /// Remove overlapping assignments in target area (for drag/resize operations)
  void _removeOverlappingAssignments({
    required String shiftTitle,
    required EmployeeRole profession,
    required int professionRow,
    required List<int> days,
    String? excludeEmployeeId, // Don't remove assignments from this employee
    String? excludeSpecificRow, // For same employee: don't remove from this specific row
  }) {
    final keysToRemove = <String>[];
    
    for (final day in days) {
      // 🔥 CRITICAL FIX: Remove ANY assignment of the same employee on this day (across ALL professions AND ALL SHIFTS)
      if (excludeEmployeeId != null) {
        // Find ALL assignments for this employee on this day across BOTH day and night shifts
        final conflictingKeys = _assignments.entries
            .where((entry) {
              final parsed = _parseAssignmentKey(entry.key);
              return parsed != null &&
                     parsed['weekNumber'] == widget.weekNumber &&
                     parsed['day'] == day &&
                     entry.value.id == excludeEmployeeId;
              // 🔥 REMOVED shiftTitle filter - now checks BOTH day and night shifts
            })
            .map((e) => e.key)
            .toList();
        
        for (final conflictKey in conflictingKeys) {
          final parsed = _parseAssignmentKey(conflictKey);
          if (parsed != null) {
            final conflictProfession = parsed['profession'] as EmployeeRole;
            final conflictRow = parsed['professionRow'] as int;
            final conflictShift = parsed['shiftTitle'] as String;
            final currentRowKey = '${profession.name}|$professionRow';
            final conflictRowKey = '${conflictProfession.name}|$conflictRow';
            
            // Don't remove from the same specific row being edited
            if (excludeSpecificRow != null && conflictRowKey == excludeSpecificRow && conflictShift == shiftTitle) {
              continue;
            }
            
            keysToRemove.add(conflictKey);
            print('🔥 CROSS-SHIFT CONFLICT: Removing ${excludeEmployeeId} from $conflictShift day $day, ${conflictProfession.name} row $conflictRow (can\'t work multiple shifts/professions same day)');
          }
        }
      }
      
      // Also remove the specific slot we're targeting (for other employees)
      final slotKey = _generateAssignmentKey(widget.weekNumber, shiftTitle, day, profession, professionRow);
      if (_assignments.containsKey(slotKey)) {
        final existingEmployee = _assignments[slotKey];
        
        // Only remove if it's a different employee (same employee conflicts handled above)
        if (excludeEmployeeId == null || existingEmployee?.id != excludeEmployeeId) {
          keysToRemove.add(slotKey);
          print('🔥 SLOT CONFLICT: Removing ${existingEmployee?.name} from $shiftTitle day $day, ${profession.name} row $professionRow (slot needed)');
        }
      }
    }
    
    // Remove all overlapping assignments
    for (final key in keysToRemove) {
      SharedAssignmentData.removeAssignmentForYear(_currentYear, key);
    }
    
    if (keysToRemove.isNotEmpty) {
      print('🔥 OVERLAP: Removed ${keysToRemove.length} conflicting assignments');
    }
  }

  // 🔥 PERFECTED WIDTH CALCULATION - Match Flutter's Expanded behavior exactly
  double _getActualDayWidth(BuildContext context) {
    final effectiveWidth = _getEffectiveWidth();
    
    // EXACT layout analysis:
    // 1. Main calendar container margins: 2px left + 2px right = 4px (from line 3511)
    // 2. Shift container border: 1px left + 1px right = 2px (from line 2557)  
    // 3. Profession column: 32px (from line 2565)
    // 4. Expanded widget takes remaining space and divides by 7 for day headers
    
    final outerMargins = 4.0;      // Calendar container margins
    final shiftBorder = 2.0;       // Shift container border  
    final professionWidth = 32.0;  // Profession labels column
    
    // This is the EXACT space that the Expanded widget sees
    final expandedAvailableWidth = effectiveWidth - outerMargins - shiftBorder - professionWidth;
    
    // Flutter's Expanded divides this space equally among 7 day columns
    final dayWidth = expandedAvailableWidth / 7.0;
    
    print('🎯 PERFECTED Width: screen=$effectiveWidth, expanded=$expandedAvailableWidth, dayWidth=$dayWidth');
    return dayWidth;
  }

} 