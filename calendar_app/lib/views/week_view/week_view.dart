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
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'fullscreen_stub.dart' 
  if (dart.library.html) 'fullscreen_web.dart' 
  if (dart.library.io) 'fullscreen_mobile.dart' as fullscreen;
// Platform-specific import removed - will use conditional web APIs

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
  final Map<String, Employee> _assignments = {};
  
  static final Map<int, Map<EmployeeRole, bool>> _weekDayShiftProfessions = {};
  static final Map<int, Map<EmployeeRole, bool>> _weekNightShiftProfessions = {};
  static final Map<int, Map<EmployeeRole, int>> _weekDayShiftRows = {};
  static final Map<int, Map<EmployeeRole, int>> _weekNightShiftRows = {};
  
  // Collapsible employee groups
  final Map<EmployeeCategory, bool> _collapsedGroups = {
    EmployeeCategory.ab: false,
    EmployeeCategory.cd: false,
    EmployeeCategory.huolto: false,
    EmployeeCategory.sijainen: false,
  };

  // Toggle for hiding worker section
  bool _showWorkerSection = true;
  
  // Tab state - 0 for day shift, 1 for night shift
  int _currentTabIndex = 0;
  
  // Resize mode - tracks which employee is in resize mode
  String? _resizeModeBlockKey; // Format: "employeeId-lane"
  
  // Visual drag state for smooth resizing
  Map<String, DragState>? _dragStates;
  


  @override
  void initState() {
    super.initState();
    
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
    
    _loadCustomProfessions(); // Load custom professions first
    _loadEmployees();
    _loadAssignments(); // LOAD GLOBAL ASSIGNMENTS
    _loadProfessionSettings(); // LOAD GLOBAL PROFESSION SETTINGS
    VacationManager.loadVacations(); // Load vacation data
  }

  Future<void> _loadEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final employeesJson = prefs.getString('employees');
    
    if (employeesJson != null) {
      final List<dynamic> employeesList = json.decode(employeesJson);
      final loadedEmployees = employeesList.map((e) => Employee.fromJson(e)).toList();
      
      // Update global list
      defaultEmployees.clear();
      defaultEmployees.addAll(loadedEmployees);
      
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
    EmployeeRole.varu4: true,
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
    // We'll check vacation days individually during assignment, not block entire week
    
    // 🔥 CONVERT ABSOLUTE LANE TO PROFESSION + ROW (NO MORE MISALIGNMENT!)
    final professionInfo = _getAbsoluteLaneToProfession(lane, shiftTitle);
    if (professionInfo == null) return; // Invalid lane
    
    final profession = professionInfo['profession'] as EmployeeRole;
    final professionRow = professionInfo['row'] as int;
    
    // Pre-compute profession row emptiness check (faster than inside setState)
    bool isProfessionRowCompletelyEmpty = true;
    for (int day = 0; day < 7; day++) {
      final checkKey = _generateAssignmentKey(widget.weekNumber, shiftTitle, day, profession, professionRow);
      if (_assignments.containsKey(checkKey)) {
        isProfessionRowCompletelyEmpty = false;
        break;
      }
    }
    
    // Pre-compute existing assignments for this employee (cache lookup)
    final employeeKeys = <String>{};
    for (final entry in _assignments.entries) {
      final parsed = _parseAssignmentKey(entry.key);
      if (parsed != null && 
          parsed['weekNumber'] == widget.weekNumber && 
          entry.value.id == employee.id) {
        employeeKeys.add(entry.key);
      }
    }
    
    // Pre-compute what assignments to add (outside setState)
    final newAssignments = <String, Employee>{};
    
    // Get week dates for vacation checking
    final weekDates = _getDatesForWeek(widget.weekNumber);
    
    if (isProfessionRowCompletelyEmpty) {
      // PROFESSION ROW IS EMPTY - FILL ENTIRE WEEK (except vacation days)
      for (int day = 0; day < 7; day++) {
        final key = _generateAssignmentKey(widget.weekNumber, shiftTitle, day, profession, professionRow);
        
        // Check if employee is on vacation for this specific day
        final dayDate = weekDates[day];
        if (VacationManager.isEmployeeOnVacation(employee.id, dayDate)) {
          continue; // Skip this day - employee is on vacation
        }
        
        // Fast check using pre-computed set - check if employee has assignment on this day
        final hasExistingAssignment = employeeKeys.any((k) {
          final parsed = _parseAssignmentKey(k);
          return parsed != null && parsed['day'] == day;
        });
        
        if (!hasExistingAssignment) {
          newAssignments[key] = employee;
        }
      }
    } else {
      // PROFESSION ROW HAS SOME ASSIGNMENTS - FILL ONLY EMPTY SLOTS (except vacation days)
      for (int day = 0; day < 7; day++) {
        final key = _generateAssignmentKey(widget.weekNumber, shiftTitle, day, profession, professionRow);
        
        if (!_assignments.containsKey(key)) {
          // Check if employee is on vacation for this specific day
          final dayDate = weekDates[day];
          if (VacationManager.isEmployeeOnVacation(employee.id, dayDate)) {
            continue; // Skip this day - employee is on vacation
          }
          
          // Fast check using pre-computed set - check if employee has assignment on this day
          final hasExistingAssignment = employeeKeys.any((k) {
            final parsed = _parseAssignmentKey(k);
            return parsed != null && parsed['day'] == day;
          });
          
          if (!hasExistingAssignment) {
            newAssignments[key] = employee;
          }
        }
      }
    }
    
    // Check if some days were skipped due to vacation
    final totalDaysInWeek = 7;
    final assignedDays = newAssignments.length;
    final skippedDueToVacation = totalDaysInWeek - assignedDays - employeeKeys.length;
    
    // SINGLE setState call with all changes batched
    if (newAssignments.isNotEmpty) {
      setState(() {
        _assignments.addAll(newAssignments);
      });
      _saveAssignments(); // SAVE TO PERSISTENT STORAGE
      
      // Show notification if some days were skipped
      if (skippedDueToVacation > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${employee.name} sijoitettu ${assignedDays} päivälle. ${skippedDueToVacation} päivää ohitettu loman/poissaolon vuoksi.'),
            backgroundColor: const Color(0xFF9DB4C0),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (skippedDueToVacation > 0) {
      // All days were skipped due to vacation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${employee.name} on lomalla/poissaolossa koko viikon - ei voida sijoittaa'),
          backgroundColor: const Color(0xFF5C6B73),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleResize(Employee employee, String shiftTitle, int startDay, int duration, int lane) {
    // 🔥 CONVERT ABSOLUTE LANE TO PROFESSION + ROW (NO MORE MISALIGNMENT!)
    final professionInfo = _getAbsoluteLaneToProfession(lane, shiftTitle);
    if (professionInfo == null) return; // Invalid lane
    
    final profession = professionInfo['profession'] as EmployeeRole;
    final professionRow = professionInfo['row'] as int;
    
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
      for (final key in originalKeys) {
        _assignments.remove(key);
      }
      
      // SECOND: For resizing, remove overlapping assignments from other blocks 
      for (int day = startDay; day < startDay + duration && day < 7; day++) {
        final conflictingKeys = _assignments.keys
            .where((key) {
              final parsed = _parseAssignmentKey(key);
              return parsed != null &&
                     parsed['weekNumber'] == widget.weekNumber &&
                     parsed['day'] == day &&
                     _assignments[key]?.id == employee.id;
            })
            .toList();
        
        for (final key in conflictingKeys) {
          _assignments.remove(key);
        }
      }
      
      // THIRD: Add new resized block
      for (int day = startDay; day < startDay + duration && day < 7; day++) {
        final key = _generateAssignmentKey(widget.weekNumber, shiftTitle, day, profession, professionRow);
        _assignments[key] = employee;
      }
    });
    _saveAssignments(); // SAVE TO PERSISTENT STORAGE
  }

  void _handleRemove(Employee employee, String shiftTitle) {
    setState(() {
      _removeEmployeeFromShift(employee, shiftTitle);
    });
    _saveAssignments(); // SAVE TO PERSISTENT STORAGE
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
      _assignments.remove(key);
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
          _assignments.remove(key);
        }
      });
      _saveAssignments(); // SAVE TO PERSISTENT STORAGE
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
          return currentLane + professionRow;
        }
        return -1; // Invalid row
      }
      
      final rows = isDay ? _dayShiftRows[visibleProfession] ?? 1 : _nightShiftRows[visibleProfession] ?? 1;
      currentLane += rows;
    }
    
    return -1; // Profession not visible
  }
  
  /// Generate new profession-based assignment key
  String _generateAssignmentKey(int weekNumber, String shiftTitle, int day, EmployeeRole profession, int professionRow) {
    return '$weekNumber-$shiftTitle-$day-${profession.name}-$professionRow';
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

  // GLOBAL ASSIGNMENT SAVING/LOADING - NOT USER SPECIFIC!
  Future<void> _saveAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assignmentsMap = <String, Map<String, dynamic>>{};
      
      for (final entry in _assignments.entries) {
        assignmentsMap[entry.key] = entry.value.toJson();
      }
      
      final assignmentsJson = json.encode(assignmentsMap);
      await prefs.setString('assignments', assignmentsJson);
      print('WeekView: Saved ${_assignments.length} assignments to SharedPreferences');
    } catch (e) {
      print('WeekView: Error saving assignments: $e');
    }
  }

  Future<void> _loadAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assignmentsJson = prefs.getString('assignments');
      
      if (assignmentsJson != null) {
        final Map<String, dynamic> assignmentsMap = json.decode(assignmentsJson);
        _assignments.clear();
        
        for (final entry in assignmentsMap.entries) {
          final employeeData = entry.value as Map<String, dynamic>;
          _assignments[entry.key] = Employee.fromJson(employeeData);
        }
        
        print('WeekView: Loaded ${_assignments.length} assignments from SharedPreferences');
        if (mounted) {
          setState(() {});
        }
      } else {
        print('WeekView: No assignments found in SharedPreferences');
      }
    } catch (e) {
      print('WeekView: Error loading assignments: $e');
    }
  }

  // SAVE PROFESSION SETTINGS GLOBALLY TOO
  Future<void> _saveProfessionSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save day/night profession settings for all weeks
      final dayProfessionsJson = json.encode(_weekDayShiftProfessions.map(
        (week, profs) => MapEntry(week.toString(), profs.map((k, v) => MapEntry(k.name, v)))
      ));
      final nightProfessionsJson = json.encode(_weekNightShiftProfessions.map(
        (week, profs) => MapEntry(week.toString(), profs.map((k, v) => MapEntry(k.name, v)))
      ));
      final dayRowsJson = json.encode(_weekDayShiftRows.map(
        (week, rows) => MapEntry(week.toString(), rows.map((k, v) => MapEntry(k.name, v)))
      ));
      final nightRowsJson = json.encode(_weekNightShiftRows.map(
        (week, rows) => MapEntry(week.toString(), rows.map((k, v) => MapEntry(k.name, v)))
      ));
      
      await prefs.setString('week_day_professions', dayProfessionsJson);
      await prefs.setString('week_night_professions', nightProfessionsJson);
      await prefs.setString('week_day_rows', dayRowsJson);
      await prefs.setString('week_night_rows', nightRowsJson);
      
      print('WeekView: Saved profession settings for ${_weekDayShiftProfessions.length} weeks');
    } catch (e) {
      print('WeekView: Error saving profession settings: $e');
    }
  }

  Future<void> _loadProfessionSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load profession settings
      final dayProfessionsJson = prefs.getString('week_day_professions');
      final nightProfessionsJson = prefs.getString('week_night_professions');
      final dayRowsJson = prefs.getString('week_day_rows');
      final nightRowsJson = prefs.getString('week_night_rows');
      
      if (dayProfessionsJson != null) {
        final Map<String, dynamic> data = json.decode(dayProfessionsJson);
        _weekDayShiftProfessions.clear();
        for (final entry in data.entries) {
          final week = int.parse(entry.key);
          final Map<String, dynamic> profs = entry.value;
          _weekDayShiftProfessions[week] = Map.fromEntries(
            profs.entries.map((e) => MapEntry(EmployeeRole.values.byName(e.key), e.value as bool))
          );
        }
      }
      
      if (nightProfessionsJson != null) {
        final Map<String, dynamic> data = json.decode(nightProfessionsJson);
        _weekNightShiftProfessions.clear();
        for (final entry in data.entries) {
          final week = int.parse(entry.key);
          final Map<String, dynamic> profs = entry.value;
          _weekNightShiftProfessions[week] = Map.fromEntries(
            profs.entries.map((e) => MapEntry(EmployeeRole.values.byName(e.key), e.value as bool))
          );
        }
      }
      
      if (dayRowsJson != null) {
        final Map<String, dynamic> data = json.decode(dayRowsJson);
        _weekDayShiftRows.clear();
        for (final entry in data.entries) {
          final week = int.parse(entry.key);
          final Map<String, dynamic> rows = entry.value;
          _weekDayShiftRows[week] = Map.fromEntries(
            rows.entries.map((e) => MapEntry(EmployeeRole.values.byName(e.key), e.value as int))
          );
        }
      }
      
      if (nightRowsJson != null) {
        final Map<String, dynamic> data = json.decode(nightRowsJson);
        _weekNightShiftRows.clear();
        for (final entry in data.entries) {
          final week = int.parse(entry.key);
          final Map<String, dynamic> rows = entry.value;
          _weekNightShiftRows[week] = Map.fromEntries(
            rows.entries.map((e) => MapEntry(EmployeeRole.values.byName(e.key), e.value as int))
          );
        }
      }
      
      print('WeekView: Loaded profession settings');
    } catch (e) {
      print('WeekView: Error loading profession settings: $e');
    }
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
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: controller.text.trim(),
                  category: category,
                  type: EmployeeType.vakityontekija, // Default type
                  role: EmployeeRole.varu1, // Default role
                  shiftCycle: ShiftCycle.none, // Default shift cycle
                );
                
                // Add to global list
                defaultEmployees.add(newEmployee);
                
                // Save to storage
                await _saveEmployees();
                
                // Refresh UI
                setState(() {});
                
                Navigator.of(context).pop();
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
    final prefs = await SharedPreferences.getInstance();
    final employeesJson = json.encode(defaultEmployees.map((e) => e.toJson()).toList());
    await prefs.setString('employees', employeesJson);
  }

  void _showProfessionEditDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Profession Settings', style: TextStyle(fontSize: 16, color: Colors.black87)),
              content: Container(
                width: 400,
                height: 500,
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
                      // Add custom profession button
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddCustomProfessionDialog(setDialogState),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Custom Profession'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C6B73),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.black87)),
                ),
              ],
            );
          },
        );
      },
    );
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
      final prefs = await SharedPreferences.getInstance();
      final json = CustomProfessionManager.toJson();
      await prefs.setString('custom_professions', jsonEncode(json));
    } catch (e) {
      print('Error saving custom professions: $e');
    }
  }

  Future<void> _loadCustomProfessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('custom_professions');
      if (jsonString != null) {
        final json = jsonDecode(jsonString);
        CustomProfessionManager.fromJson(json);
      }
    } catch (e) {
      print('Error loading custom professions: $e');
    }
  }

  Widget _buildProfessionSettings(StateSetter setDialogState, bool isDayShift) {
    final professions = isDayShift ? _dayShiftProfessions : _nightShiftProfessions;
    final rows = isDayShift ? _dayShiftRows : _nightShiftRows;
    
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: EmployeeRole.values.map((role) {
          return Card(
            color: Colors.grey[50],
            margin: const EdgeInsets.symmetric(vertical: 2),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  // Checkbox for visibility
                  Checkbox(
                    value: professions[role],
                    onChanged: (bool? value) {
                      final wasVisible = professions[role] ?? false;
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
                  // Profession name
                  Expanded(
                    child: Text(
                      _getRoleDisplayName(role),
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  // Row count controls
                  const Text('Rivejä: ', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  // Decrease button
                  IconButton(
                    onPressed: rows[role]! > 1 ? () {
                      setDialogState(() {
                        rows[role] = (rows[role]! - 1).clamp(1, 4);
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
                      '${rows[role]}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  // Increase button
                  IconButton(
                    onPressed: rows[role]! < 4 ? () {
                      setDialogState(() {
                        rows[role] = (rows[role]! + 1).clamp(1, 4);
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
        }).toList(),
      ),
    );
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
      _assignments.remove(key);
    }
    
    // Save the updated assignments
    _saveAssignments();
    
    // Update UI
    if (mounted) {
      setState(() {});
    }
    
    print('Moved ${assignmentsToRemove.length} assignments back to workers for hidden profession: ${hiddenRole.name}');
  }

  String _getRoleDisplayName(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.tj: return 'TJ';
      case EmployeeRole.varu1: return 'VARU1';
      case EmployeeRole.varu2: return 'VARU2';
      case EmployeeRole.varu3: return 'VARU3';
      case EmployeeRole.varu4: return 'VARU4';
      case EmployeeRole.pasta1: return 'PASTA1';
      case EmployeeRole.pasta2: return 'PASTA2';
      case EmployeeRole.ict: return 'ICT';
      case EmployeeRole.tarvike: return 'TARVIKE';
      case EmployeeRole.pora: return 'PORA';
      case EmployeeRole.huolto: return 'HUOLTO';
      case EmployeeRole.custom: return 'CUSTOM';
    }
  }

  void _toggleResizeMode(Employee employee, String shiftTitle, int blockStartDay, int blockLane) {
    final blockKey = '${employee.id}-$shiftTitle-$blockLane-$blockStartDay';
    setState(() {
      _resizeModeBlockKey = _resizeModeBlockKey == blockKey ? null : blockKey;
    });
  }

  void _handleResizeStart(DragStartDetails details, Employee employee, String shiftTitle, bool isLeftResize) {
    // 🔥 USE PROFESSION-BASED KEYS FOR RESIZE!
    final employeeAbsoluteLane = _getEmployeeAbsoluteLane(employee, shiftTitle);
    final employeeStartDay = _getEmployeeStartDay(employee, shiftTitle);
    final blockKey = '${employee.id}-$shiftTitle-$employeeAbsoluteLane-$employeeStartDay';
    
    // Get current employee span for originalStartDay and originalDuration using profession-based parsing
    final currentKeys = _assignments.entries
        .where((entry) {
          final parsed = _parseAssignmentKey(entry.key);
          return parsed != null && 
                 parsed['weekNumber'] == widget.weekNumber && 
                 parsed['shiftTitle'] == shiftTitle && 
                 entry.value.id == employee.id;
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
    
    // Add haptic feedback for that "juicy" feel
    HapticFeedback.lightImpact();
  }

  void _handleLeftResize(DragUpdateDetails details, Employee employee, String shiftTitle) {
    // 🔥 USE PROFESSION-BASED KEYS FOR RESIZE!
    final employeeAbsoluteLane = _getEmployeeAbsoluteLane(employee, shiftTitle);
    final employeeStartDay = _getEmployeeStartDay(employee, shiftTitle);
    final blockKey = '${employee.id}-$shiftTitle-$employeeAbsoluteLane-$employeeStartDay';
    
    // Update only the current position for smooth visual feedback
    final currentDragState = _dragStates?[blockKey];
    if (currentDragState != null) {
      setState(() {
        _dragStates![blockKey] = DragState(
          startX: currentDragState.startX,
          currentX: details.globalPosition.dx,
          isLeftResize: true,
          originalStartDay: currentDragState.originalStartDay,
          originalDuration: currentDragState.originalDuration,
        );
      });
    }
  }

  void _handleRightResize(DragUpdateDetails details, Employee employee, String shiftTitle) {
    // 🔥 USE PROFESSION-BASED KEYS FOR RESIZE!
    final employeeAbsoluteLane = _getEmployeeAbsoluteLane(employee, shiftTitle);
    final employeeStartDay = _getEmployeeStartDay(employee, shiftTitle);
    final blockKey = '${employee.id}-$shiftTitle-$employeeAbsoluteLane-$employeeStartDay';
    
    // Update only the current position for smooth visual feedback
    final currentDragState = _dragStates?[blockKey];
    if (currentDragState != null) {
      setState(() {
        _dragStates![blockKey] = DragState(
          startX: currentDragState.startX,
          currentX: details.globalPosition.dx,
          isLeftResize: false,
          originalStartDay: currentDragState.originalStartDay,
          originalDuration: currentDragState.originalDuration,
        );
      });
    }
  }



  void _performResize(Employee employee, String shiftTitle, int targetDay, bool isLeftResize) {
    // Find current employee assignments for this shift
    final currentKeys = _assignments.entries
        .where((entry) => entry.key.startsWith('${widget.weekNumber}-$shiftTitle') && entry.value.id == employee.id)
        .map((e) => e.key)
        .toList();
    
    if (currentKeys.isEmpty) return;
    
    // Sort to get the span
    currentKeys.sort((a, b) {
      final dayA = int.tryParse(a.split('-')[2]) ?? 0;
      final dayB = int.tryParse(b.split('-')[2]) ?? 0;
          return dayA.compareTo(dayB);
        });
        
    final firstKey = currentKeys.first;
    final lastKey = currentKeys.last;
    final currentStartDay = int.tryParse(firstKey.split('-')[2]) ?? 0;
    final currentEndDay = int.tryParse(lastKey.split('-')[2]) ?? 0;
    final lane = int.tryParse(firstKey.split('-')[3]) ?? 0;
    
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
      _handleResize(employee, shiftTitle, newStartDay, newDuration, lane);
    }
  }

  // 🔥 NEW: Get employee's absolute lane using profession-based system
  int _getEmployeeAbsoluteLane(Employee employee, String shiftTitle) {
    final entry = _assignments.entries
        .where((e) {
          final parsed = _parseAssignmentKey(e.key);
          return parsed != null && 
                 parsed['weekNumber'] == widget.weekNumber && 
                 parsed['shiftTitle'] == shiftTitle && 
                 e.value.id == employee.id;
        })
        .firstOrNull;
    
    if (entry == null) return 0;
    
    final parsed = _parseAssignmentKey(entry.key);
    if (parsed == null) return 0;
    
    final profession = parsed['profession'] as EmployeeRole;
    final professionRow = parsed['professionRow'] as int;
    
    return _getProfessionToAbsoluteLane(profession, professionRow, shiftTitle);
  }

  int _getEmployeeStartDay(Employee employee, String shiftTitle) {
    final entries = _assignments.entries
        .where((e) {
          final parsed = _parseAssignmentKey(e.key);
          return parsed != null && 
                 parsed['weekNumber'] == widget.weekNumber && 
                 parsed['shiftTitle'] == shiftTitle && 
                 e.value.id == employee.id;
        })
        .toList();
    if (entries.isEmpty) return 0;
    
    entries.sort((a, b) {
      final parsedA = _parseAssignmentKey(a.key);
      final parsedB = _parseAssignmentKey(b.key);
      final dayA = parsedA?['day'] ?? 0;
      final dayB = parsedB?['day'] ?? 0;
      return dayA.compareTo(dayB);
    });
    
    final parsed = _parseAssignmentKey(entries.first.key);
    return parsed?['day'] ?? 0;
  }



  void _handleResizeEnd() {
    if (_resizeModeBlockKey == null || _dragStates == null) return;
    
    final blockKey = _resizeModeBlockKey!;
    final dragState = _dragStates![blockKey];
    
    if (dragState != null) {
      // 🔥 USE SAME GRID SNAPPING AS WORKING DROP LOGIC!
      final dayWidth = (MediaQuery.of(context).size.width - 40 - 16 - 8) / 7; // Match working calculation
      final gridLeft = 40; // Profession column width
      
      // Get employee and shift info from block key (format: employeeId-shiftTitle-lane-startDay)
      final keyParts = blockKey.split('-');
      final employeeId = keyParts[0];
      final shiftTitle = keyParts[1];
      final blockLane = int.tryParse(keyParts[2]) ?? 0;
      
      // Find the employee
      final employee = _assignments.values.firstWhere((e) => e.id == employeeId, 
          orElse: () => Employee(id: '', name: '', category: EmployeeCategory.ab, type: EmployeeType.vakityontekija, role: EmployeeRole.varu1, shiftCycle: ShiftCycle.none));
      
      if (employee.id.isEmpty) return;
      
      // 🔥 SIMPLE GRID SNAPPING - NO COMPLEX TOLERANCE BULLSHIT!
      final relativeX = dragState.currentX - gridLeft;
      final targetDay = (relativeX / dayWidth).floor().clamp(0, 6); // Same as working drop logic!
      
      if (dragState.isLeftResize) {
        // LEFT RESIZE - change start day, keep original end
        final originalEnd = dragState.originalStartDay + dragState.originalDuration - 1;
        final newStartDay = targetDay.clamp(0, originalEnd);
        final newDuration = originalEnd - newStartDay + 1;
        
        // Update only if start day actually changed
        if (newStartDay != dragState.originalStartDay && newDuration > 0) {
          _handleResize(employee, shiftTitle, newStartDay, newDuration, blockLane);
        }
      } else {
        // RIGHT RESIZE - keep original start, change duration
        final newDuration = (targetDay - dragState.originalStartDay + 1).clamp(1, 7 - dragState.originalStartDay);
        
        // Update only if duration actually changed
        if (newDuration != dragState.originalDuration) {
          _handleResize(employee, shiftTitle, dragState.originalStartDay, newDuration, blockLane);
        }
      }
    }
    
    // Add haptic feedback for completion
    HapticFeedback.mediumImpact();
    
    // Clear drag and resize state with smooth transition
    setState(() {
      _dragStates = null;
      _resizeModeBlockKey = null;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

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
                     height: 24, // Fixed height for each row
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
                                 height: 24,
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
    switch (category) {
      case EmployeeCategory.ab:
        return const Color(0xFFE0FBFC); // Light cyan
      case EmployeeCategory.cd:
        return const Color(0xFFC2DFE3); // Light blue
      case EmployeeCategory.huolto:
        return const Color(0xFF9DB4C0); // Cadet gray
      case EmployeeCategory.sijainen:
        return const Color(0xFF5C6B73); // Payne's gray
    }
  }

  Color _getTextColorForCategory(EmployeeCategory category) {
    switch (category) {
      case EmployeeCategory.ab:
      case EmployeeCategory.cd:
        return const Color(0xFF253237); // Dark text on light backgrounds
      case EmployeeCategory.huolto:
      case EmployeeCategory.sijainen:
        return Colors.white; // White text on darker backgrounds
    }
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
    switch (role) {
      case EmployeeRole.tj:
        return 'TJ';
      case EmployeeRole.varu1:
        return 'V1';
      case EmployeeRole.varu2:
        return 'V2';
      case EmployeeRole.varu3:
        return 'V3';
      case EmployeeRole.varu4:
        return 'V4';
      case EmployeeRole.pasta1:
        return 'P1';
      case EmployeeRole.pasta2:
        return 'P2';
      case EmployeeRole.ict:
        return 'ICT';
      case EmployeeRole.tarvike:
        return 'TR';
      case EmployeeRole.pora:
        return 'PR';
      case EmployeeRole.huolto:
        return 'HU';
      case EmployeeRole.custom:
        return 'CU';
    }
  }



  Widget _buildSingleShiftCalendarGrid(String shiftTitle) {
    const rowHeight = 25.2; // 1.4x larger (18 * 1.4)
    final dayWidth = (MediaQuery.of(context).size.width - 32 - 8) / 7; // 32px profession column + 8px margins
    
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
    Set<String> processedAssignments = {};
    
    for (final entry in _assignments.entries) {
      if (!processedAssignments.contains(entry.key)) {
        final parsed = _parseAssignmentKey(entry.key);
        if (parsed != null && 
            parsed['weekNumber'] == widget.weekNumber && 
            parsed['shiftTitle'] == shiftTitle) {
          
          final startDay = parsed['day'] as int;
          final profession = parsed['profession'] as EmployeeRole;
          final professionRow = parsed['professionRow'] as int;
          
          // 🔥 CONVERT PROFESSION + ROW TO ABSOLUTE LANE FOR RENDERING
          final absoluteLane = _getProfessionToAbsoluteLane(profession, professionRow, shiftTitle);
          if (absoluteLane == -1) continue; // Profession not visible or invalid row
          
          // Check if this block is being dragged
          final blockKey = '${entry.value.id}-$shiftTitle-$absoluteLane-$startDay';
          final dragState = _dragStates?[blockKey];
          
          // Find contiguous assignment duration using profession-based keys
          int duration = 1;
          for (int day = startDay + 1; day < 7; day++) {
            final nextKey = _generateAssignmentKey(widget.weekNumber, shiftTitle, day, profession, professionRow);
            if (_assignments.containsKey(nextKey) && _assignments[nextKey]?.id == entry.value.id) {
              duration++;
              processedAssignments.add(nextKey);
            } else {
              break;
            }
          }
          
          // Calculate visual position during drag
          double visualLeft = startDay * dayWidth;
          double visualWidth = (dayWidth * duration) - 1;
          
          if (dragState != null && _resizeModeBlockKey == blockKey) {
            final deltaX = dragState.currentX - dragState.startX;
            
            if (dragState.isLeftResize) {
              // Left resize - adjust start position and width
              visualLeft = (dragState.originalStartDay * dayWidth) + deltaX;
              final originalEnd = dragState.originalStartDay + dragState.originalDuration - 1;
              visualWidth = (originalEnd * dayWidth + dayWidth) - visualLeft - 1;
            } else {
              // Right resize - adjust width only
              visualWidth = ((dragState.originalStartDay * dayWidth) + (dragState.originalDuration * dayWidth) + deltaX) - visualLeft - 1;
            }
            
            // Clamp to grid boundaries
            visualLeft = visualLeft.clamp(0, 6 * dayWidth);
            visualWidth = visualWidth.clamp(dayWidth * 0.2, (7 * dayWidth) - visualLeft);
          }
          
          blocks.add(
            Positioned(
              left: visualLeft,
              top: absoluteLane * rowHeight,
              width: visualWidth,
              height: rowHeight - 1,
              child: _buildAssignmentBlock(entry.value, shiftTitle, startDay, absoluteLane),
            ),
          );
          processedAssignments.add(entry.key);
        }
      }
    }
    
    return blocks;
  }

  Widget _buildUnifiedCalendarGrid(List<String> shiftTitles) {
    const rowHeight = 25.2; // 1.4x larger (18 * 1.4)
    final dayWidth = (MediaQuery.of(context).size.width - 40 - 16 - 8) / 7; // 40px profession column + 16px scrollbar + 8px margins
    
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
        ..._buildAllAssignmentBlocks(shiftTitles, dayWidth, rowHeight, dayShiftRows),
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
          
          // Find contiguous assignment duration using profession-based keys
          int duration = 1;
          for (int day = startDay + 1; day < 7; day++) {
            final nextKey = _generateAssignmentKey(widget.weekNumber, shiftTitles[0], day, profession, professionRow);
            if (_assignments.containsKey(nextKey) && _assignments[nextKey]?.id == entry.value.id) {
              duration++;
              processedAssignments.add(nextKey);
            } else {
              break;
            }
          }
          
          // Calculate visual position during drag
          double visualLeft = startDay * dayWidth;
          double visualWidth = (dayWidth * duration) - 1;
          
          if (dragState != null && _resizeModeBlockKey == blockKey) {
            final deltaX = dragState.currentX - dragState.startX;
            
            if (dragState.isLeftResize) {
              // Left resize - adjust start position and width
              visualLeft = (dragState.originalStartDay * dayWidth) + deltaX;
              final originalEnd = dragState.originalStartDay + dragState.originalDuration - 1;
              visualWidth = (originalEnd * dayWidth + dayWidth) - visualLeft - 1;
            } else {
              // Right resize - adjust width only
              visualWidth = ((dragState.originalStartDay * dayWidth) + (dragState.originalDuration * dayWidth) + deltaX) - visualLeft - 1;
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
          
          // Find contiguous assignment duration using profession-based keys
          int duration = 1;
          for (int day = startDay + 1; day < 7; day++) {
            final nextKey = _generateAssignmentKey(widget.weekNumber, shiftTitles[1], day, profession, professionRow);
            if (_assignments.containsKey(nextKey) && _assignments[nextKey]?.id == entry.value.id) {
              duration++;
              processedAssignments.add(nextKey);
            } else {
              break;
            }
          }
          
          // Calculate visual position during drag
          double visualLeft = startDay * dayWidth;
          double visualWidth = (dayWidth * duration) - 1;
          
          if (dragState != null && _resizeModeBlockKey == blockKey) {
            final deltaX = dragState.currentX - dragState.startX;
            
            if (dragState.isLeftResize) {
              // Left resize - adjust start position and width
              visualLeft = (dragState.originalStartDay * dayWidth) + deltaX;
              final originalEnd = dragState.originalStartDay + dragState.originalDuration - 1;
              visualWidth = (originalEnd * dayWidth + dayWidth) - visualLeft - 1;
            } else {
              // Right resize - adjust width only
              visualWidth = ((dragState.originalStartDay * dayWidth) + (dragState.originalDuration * dayWidth) + deltaX) - visualLeft - 1;
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
    final blockKey = '${employee.id}-$shiftTitle-$blockLane-$blockStartDay';
    final isInResizeMode = _resizeModeBlockKey == blockKey;
    
    return RepaintBoundary(
      key: ValueKey(blockKey),
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
                            );
                          }
                          
  Widget _buildDraggableBlock(Employee employee, String shiftTitle, int blockStartDay, int blockLane) {
    return Draggable<Employee>(
                    data: employee,
                    onDragStarted: () {
                      _removeSpecificBlock(employee, shiftTitle, blockStartDay, blockLane);
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
                        color: Colors.grey[400],
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
      allKeys.sort((a, b) {
        final dayA = int.tryParse(a.split('-')[2]) ?? 0; // Week-shift-day-lane format
        final dayB = int.tryParse(b.split('-')[2]) ?? 0;
        return dayA.compareTo(dayB);
      });
      
      final firstKey = allKeys.first;
      final lastKey = allKeys.last;
      final firstKeyParts = firstKey.split('-');
      final lastKeyParts = lastKey.split('-');
      
      if (firstKeyParts.length >= 4) { // Week-shift-day-lane format
        final startDay = int.tryParse(firstKeyParts[2]) ?? 0; // Day is index 2
        final endDay = int.tryParse(lastKeyParts[2]) ?? 0;
        final lane = int.tryParse(firstKeyParts[3]) ?? 0; // Lane is index 3
        
        // Get current position
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final localPosition = renderBox.globalToLocal(details.globalPosition);
          final dayWidth = (MediaQuery.of(context).size.width - 40 - 16 - 8) / 7; // 40px profession column + 16px scrollbar + 8px margins
          final gridLeft = 40; // Profession column width
          final relativeX = localPosition.dx - gridLeft;
          final targetDay = (relativeX / dayWidth).floor().clamp(0, 6);
          
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
              _handleResize(employee, shiftTitle, newStartDay, newDuration, lane);
            }
          } else if (distanceToRight < 20) {
            // Resize from right (change duration)
            final newDuration = (targetDay - startDay + 1).clamp(1, 7 - startDay);
            if (newDuration != (endDay - startDay + 1)) {
              _handleResize(employee, shiftTitle, startDay, newDuration, lane);
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
                          'W${widget.weekNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
                    // Fullscreen button
                    SizedBox(
                      width: 32,
                      child: IconButton(
                        onPressed: _toggleFullscreen,
                        icon: const Icon(Icons.fullscreen, size: 14, color: Colors.white),
                        padding: EdgeInsets.zero,
                        tooltip: 'Fullscreen',
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
                          widget.onViewChanged?.call('VUOSI'); // FIXED PARAMETER!
                          HapticFeedback.lightImpact();
                        },
                        icon: const Icon(Icons.calendar_view_month, size: 14, color: Colors.white),
                        padding: EdgeInsets.zero,
                        tooltip: 'Year Overview',
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
                      child: IconButton(
                        icon: const Icon(Icons.settings, size: 12, color: Colors.black87), // Smaller icon
                        onPressed: _showProfessionEditDialog,
                        padding: EdgeInsets.zero,
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
              leading: const Icon(Icons.calendar_view_week, color: Colors.white),
              title: const Text('VIIKKO', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                widget.onViewChanged?.call('VIIKKO');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month, color: Colors.white),
              title: const Text('VUOSI', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                widget.onViewChanged?.call('VUOSI');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.white),
              title: const Text('TYÖNTEKIJÄT', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmployeeSettingsView()),
                );
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
    final blockKey = '${employee.id}-$shiftTitle-$blockLane-$blockStartDay';
    
    // 🔥 FIND THE SPAN USING PROFESSION-BASED KEYS!
    final thisBlockKeys = <String>[];
    
    // Find this employee's assignment keys for this shift using profession-based parsing
    final employeeKeys = _assignments.entries
        .where((entry) {
          final parsed = _parseAssignmentKey(entry.key);
          return parsed != null && 
                 parsed['weekNumber'] == widget.weekNumber && 
                 parsed['shiftTitle'] == shiftTitle && 
                 entry.value.id == employee.id;
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


} 