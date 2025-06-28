import 'package:calendar_app/data/default_employees.dart';
import 'package:calendar_app/models/employee.dart';
import 'package:calendar_app/views/employee_settings/employee_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:calendar_app/services/auth_service.dart';
import 'package:flutter/foundation.dart';
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
    _loadEmployees();
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
    // DO ALL HEAVY COMPUTATION OUTSIDE setState TO AVOID UI BLOCKING
    final weekPrefix = '${widget.weekNumber}-';
    
    // Pre-compute lane emptiness check (faster than inside setState)
    bool isLaneCompletelyEmpty = true;
    for (int day = 0; day < 7; day++) {
      final checkKey = '$weekPrefix$shiftTitle-$day-$lane';
      if (_assignments.containsKey(checkKey)) {
        isLaneCompletelyEmpty = false;
        break;
      }
    }
    
    // Pre-compute existing assignments for this employee (cache lookup)
    final employeeKeys = <String>{};
    for (final entry in _assignments.entries) {
      if (entry.key.startsWith(weekPrefix) && entry.value.id == employee.id) {
        employeeKeys.add(entry.key);
      }
    }
    
    // Pre-compute what assignments to add (outside setState)
    final newAssignments = <String, Employee>{};
    
    if (isLaneCompletelyEmpty) {
      // LANE IS EMPTY - FILL ENTIRE WEEK
      for (int day = 0; day < 7; day++) {
        final key = '$weekPrefix$shiftTitle-$day-$lane';
        
        // Fast check using pre-computed set
        final hasExistingAssignment = employeeKeys.any((k) => k.contains('-$day-'));
        
        if (!hasExistingAssignment) {
          newAssignments[key] = employee;
        }
      }
    } else {
      // LANE HAS SOME ASSIGNMENTS - FILL ONLY EMPTY SLOTS
      for (int day = 0; day < 7; day++) {
        final key = '$weekPrefix$shiftTitle-$day-$lane';
        
        if (!_assignments.containsKey(key)) {
          // Fast check using pre-computed set
          final hasExistingAssignment = employeeKeys.any((k) => k.contains('-$day-'));
          
          if (!hasExistingAssignment) {
            newAssignments[key] = employee;
          }
        }
      }
    }
    
    // SINGLE setState call with all changes batched
    if (newAssignments.isNotEmpty) {
      setState(() {
        _assignments.addAll(newAssignments);
      });
    }
  }

  void _handleResize(Employee employee, String shiftTitle, int startDay, int duration, int lane) {
    setState(() {
      // SMART RESIZE WITH CONFLICT RESOLUTION
      
      // FIRST: Find and remove ONLY the original block being resized (exact same lane)
      final originalKeys = _assignments.keys
          .where((key) => key.startsWith('${widget.weekNumber}-$shiftTitle') && 
                         _assignments[key]?.id == employee.id &&
                         key.split('-')[3] == lane.toString()) // Updated index for week-shift-day-lane
          .toList();
      
      // Remove the original block being resized
      for (final key in originalKeys) {
        _assignments.remove(key);
      }
      
      // SECOND: For resizing, remove overlapping assignments from other blocks 
      for (int day = startDay; day < startDay + duration && day < 7; day++) {
        final conflictingKeys = _assignments.keys
            .where((key) => key.startsWith('${widget.weekNumber}-') && key.contains('-$day-') && _assignments[key]?.id == employee.id)
            .toList();
        
        for (final key in conflictingKeys) {
          _assignments.remove(key);
        }
      }
      
      // THIRD: Add new resized block
      for (int day = startDay; day < startDay + duration && day < 7; day++) {
        final key = '${widget.weekNumber}-$shiftTitle-$day-$lane'; // Week-specific
        _assignments[key] = employee;
      }
    });
  }

  void _handleRemove(Employee employee, String shiftTitle) {
    setState(() {
      _removeEmployeeFromShift(employee, shiftTitle);
    });
  }

  void _removeEmployeeFromShift(Employee employee, String shiftTitle) {
    final keysToRemove = _assignments.keys
        .where((key) => key.startsWith('${widget.weekNumber}-$shiftTitle') && _assignments[key]?.id == employee.id)
        .toList();
    
    for (final key in keysToRemove) {
      _assignments.remove(key);
    }
  }

  void _removeSpecificBlock(Employee employee, String shiftTitle, int blockStartDay, int blockLane) {
    // Pre-compute keys to remove (outside setState for better performance)
    final thisBlockKeys = <String>[];
    for (int day = blockStartDay; day < 7; day++) {
      final key = '${widget.weekNumber}-$shiftTitle-$day-$blockLane';
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
    final shiftTitles = _getShiftTitlesForWeek(widget.weekNumber);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return DefaultTabController(
              length: 2,
              child: AlertDialog(
                title: Text('Ammatit - Viikko ${widget.weekNumber}'),
                backgroundColor: Colors.white,
                content: SizedBox(
                  width: 400,
                  height: 500,
                  child: Column(
                    children: [
                      // Tab bar for day/night shifts
                      TabBar(
                        labelColor: Colors.black87,
                        tabs: [
                          Tab(text: shiftTitles[0]),
                          Tab(text: shiftTitles[1]),
                        ],
                      ),
                      // Tab views
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Day shift settings
                            _buildProfessionSettings(setDialogState, true),
                            // Night shift settings
                            _buildProfessionSettings(setDialogState, false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Peruuta'),
                  ),
                  TextButton(
                    onPressed: () {
                      // Reset to defaults for this week
                      setDialogState(() {
                        _weekDayShiftProfessions[widget.weekNumber] = Map.from(_getDefaultDayShiftProfessions());
                        _weekNightShiftProfessions[widget.weekNumber] = Map.from(_getDefaultNightShiftProfessions());
                        _weekDayShiftRows[widget.weekNumber] = Map.from(_getDefaultDayShiftRows());
                        _weekNightShiftRows[widget.weekNumber] = Map.from(_getDefaultNightShiftRows());
                      });
                    },
                    child: const Text('Palauta oletukset'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {}); // Refresh main view
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
                      setDialogState(() {
                        professions[role] = value ?? false;
                      });
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
    }
  }

  void _toggleResizeMode(Employee employee, String shiftTitle, int blockStartDay, int blockLane) {
    final blockKey = '${employee.id}-$shiftTitle-$blockLane-$blockStartDay';
    setState(() {
      _resizeModeBlockKey = _resizeModeBlockKey == blockKey ? null : blockKey;
    });
  }

  void _handleLeftResize(DragUpdateDetails details, Employee employee, String shiftTitle) {
    final blockKey = '${employee.id}-$shiftTitle-${_getEmployeeLane(employee, shiftTitle)}-${_getEmployeeStartDay(employee, shiftTitle)}';
    
    // Get current employee span for originalStartDay and originalDuration
    final currentKeys = _assignments.entries
        .where((entry) => entry.key.startsWith('${widget.weekNumber}-$shiftTitle') && entry.value.id == employee.id)
        .map((e) => e.key)
        .toList();
    
    currentKeys.sort((a, b) {
      final dayA = int.tryParse(a.split('-')[2]) ?? 0;
      final dayB = int.tryParse(b.split('-')[2]) ?? 0;
      return dayA.compareTo(dayB);
    });
    
    final originalStartDay = currentKeys.isNotEmpty ? int.tryParse(currentKeys.first.split('-')[2]) ?? 0 : 0;
    final originalEndDay = currentKeys.isNotEmpty ? int.tryParse(currentKeys.last.split('-')[2]) ?? 0 : 0;
    final originalDuration = originalEndDay - originalStartDay + 1;
    
    // Set the drag state for visual feedback
    setState(() {
      _dragStates ??= {};
      _dragStates![blockKey] = DragState(
        startX: details.globalPosition.dx,
        currentX: details.globalPosition.dx,
        isLeftResize: true,
        originalStartDay: originalStartDay,
        originalDuration: originalDuration,
      );
    });
    
    // Calculate new resize position
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final localPosition = renderBox.globalToLocal(details.globalPosition);
      final dayWidth = (MediaQuery.of(context).size.width - 32 - 8) / 7;
      final gridLeft = 32; // Profession column width
      final relativeX = localPosition.dx - gridLeft;
      final targetDay = (relativeX / dayWidth).floor().clamp(0, 6);
      
      _performResize(employee, shiftTitle, targetDay, true);
    }
  }

  void _handleRightResize(DragUpdateDetails details, Employee employee, String shiftTitle) {
    final blockKey = '${employee.id}-$shiftTitle-${_getEmployeeLane(employee, shiftTitle)}-${_getEmployeeStartDay(employee, shiftTitle)}';
    
    // Get current employee span for originalStartDay and originalDuration
    final currentKeys = _assignments.entries
        .where((entry) => entry.key.startsWith('${widget.weekNumber}-$shiftTitle') && entry.value.id == employee.id)
        .map((e) => e.key)
        .toList();
    
    currentKeys.sort((a, b) {
      final dayA = int.tryParse(a.split('-')[2]) ?? 0;
      final dayB = int.tryParse(b.split('-')[2]) ?? 0;
      return dayA.compareTo(dayB);
    });
    
    final originalStartDay = currentKeys.isNotEmpty ? int.tryParse(currentKeys.first.split('-')[2]) ?? 0 : 0;
    final originalEndDay = currentKeys.isNotEmpty ? int.tryParse(currentKeys.last.split('-')[2]) ?? 0 : 0;
    final originalDuration = originalEndDay - originalStartDay + 1;
    
    // Set the drag state for visual feedback
    setState(() {
      _dragStates ??= {};
      _dragStates![blockKey] = DragState(
        startX: details.globalPosition.dx,
        currentX: details.globalPosition.dx,
        isLeftResize: false,
        originalStartDay: originalStartDay,
        originalDuration: originalDuration,
      );
    });
    
    // Calculate new resize position
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final localPosition = renderBox.globalToLocal(details.globalPosition);
      final dayWidth = (MediaQuery.of(context).size.width - 32 - 8) / 7;
      final gridLeft = 32; // Profession column width
      final relativeX = localPosition.dx - gridLeft;
      final targetDay = (relativeX / dayWidth).floor().clamp(0, 6);
      
      _performResize(employee, shiftTitle, targetDay, false);
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

  int _getEmployeeLane(Employee employee, String shiftTitle) {
    final entry = _assignments.entries
        .firstWhere((e) => e.key.startsWith('${widget.weekNumber}-$shiftTitle') && e.value.id == employee.id,
                   orElse: () => MapEntry('0-0-0-0', Employee(id: '', name: '', category: EmployeeCategory.ab, type: EmployeeType.vakityontekija, role: EmployeeRole.varu1, shiftCycle: ShiftCycle.none)));
    return int.tryParse(entry.key.split('-')[3]) ?? 0;
  }

  int _getEmployeeStartDay(Employee employee, String shiftTitle) {
    final entries = _assignments.entries
        .where((e) => e.key.startsWith('${widget.weekNumber}-$shiftTitle') && e.value.id == employee.id)
        .toList();
    if (entries.isEmpty) return 0;
    
    entries.sort((a, b) {
      final dayA = int.tryParse(a.key.split('-')[2]) ?? 0;
      final dayB = int.tryParse(b.key.split('-')[2]) ?? 0;
      return dayA.compareTo(dayB);
    });
    
    return int.tryParse(entries.first.key.split('-')[2]) ?? 0;
  }

  void _updateResizeAssignments(Employee employee, String shiftTitle, int startDay, int duration, int lane) {
    // Update assignments directly without setState to avoid rebuilds during drag
    
    // FIRST: Find and remove ONLY the original block being resized (exact same lane)
    final originalKeys = _assignments.keys
        .where((key) => key.startsWith('${widget.weekNumber}-$shiftTitle') && 
                       _assignments[key]?.id == employee.id &&
                       key.split('-')[3] == lane.toString()) // Updated index for week-shift-day-lane
        .toList();
    
    // Remove the original block being resized
    for (final key in originalKeys) {
      _assignments.remove(key);
    }
    
    // SECOND: For resizing, remove overlapping assignments from other blocks 
    for (int day = startDay; day < startDay + duration && day < 7; day++) {
      final conflictingKeys = _assignments.keys
          .where((key) => key.startsWith('${widget.weekNumber}-') && key.contains('-$day-') && _assignments[key]?.id == employee.id)
          .toList();
      
      for (final key in conflictingKeys) {
        _assignments.remove(key);
      }
    }
    
    // THIRD: Add new resized block
    for (int day = startDay; day < startDay + duration && day < 7; day++) {
      final key = '${widget.weekNumber}-$shiftTitle-$day-$lane'; // Week-specific
      _assignments[key] = employee;
    }
  }

  void _handleResizeEnd() {
    if (_resizeModeBlockKey == null || _dragStates == null) return;
    
    final blockKey = _resizeModeBlockKey!;
    final dragState = _dragStates![blockKey];
    
    if (dragState != null) {
      // Calculate snap-to-grid position
      final dayWidth = (MediaQuery.of(context).size.width - 40 - 16 - 8) / 7;
      final gridLeft = 40;
      
      // Get employee and shift info from block key
      final keyParts = blockKey.split('-');
      final employeeId = keyParts[0];
      final shiftTitle = keyParts[1];
      final blockLane = int.tryParse(keyParts[2]) ?? 0;
      
      // Find the employee
      final employee = _assignments.values.firstWhere((e) => e.id == employeeId);
      
      if (dragState.isLeftResize) {
        // Left resize - snap start position (use LEFT EDGE of left handle)
        final handleLeftEdge = dragState.currentX - 12; // 12px = half width of 24px handle
        final relativeX = handleLeftEdge - gridLeft;
        final targetDay = (relativeX / dayWidth).round().clamp(0, 6);
        final originalEnd = dragState.originalStartDay + dragState.originalDuration - 1;
        final newStartDay = targetDay.clamp(0, originalEnd);
        final newDuration = originalEnd - newStartDay + 1;
        
        if (newDuration > 0) {
          _updateResizeAssignments(employee, shiftTitle, newStartDay, newDuration, blockLane);
        }
      } else {
        // Right resize - snap end position (use RIGHT EDGE of right handle)
        final handleRightEdge = dragState.currentX + 12; // 12px = half width of 24px handle
        final relativeX = handleRightEdge - gridLeft;
        final targetDay = (relativeX / dayWidth).round().clamp(0, 6);
        final newDuration = (targetDay - dragState.originalStartDay + 1).clamp(1, 7 - dragState.originalStartDay).toInt();
        
        if (newDuration > 0) {
          _updateResizeAssignments(employee, shiftTitle, dragState.originalStartDay, newDuration, blockLane);
        }
      }
    }
    
    // Clear drag and resize state
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

  // Add fullscreen toggle function
  void _toggleFullscreen() {
    // For now, show a message - fullscreen requires platform-specific implementation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fullscreen: Use browser F11 or mobile browser fullscreen options'),
        duration: Duration(seconds: 3),
      ),
    );
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
                            _getCategoryDisplayName(category),
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
              // Show empty state
              allGroupWidgets.add(
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Ei työntekijöitä tässä kategoriassa',
                    style: const TextStyle(
                      color: Color(0xFF5C6B73), // Payne's gray
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
      if (entry.key.startsWith('${widget.weekNumber}-$shiftTitle') && !processedAssignments.contains(entry.key)) {
        final keyParts = entry.key.split('-');
        if (keyParts.length >= 4) { // Now we have week-shift-day-lane
          final weekNum = int.tryParse(keyParts[0]) ?? 0;
          final startDay = int.tryParse(keyParts[2]) ?? 0;
          final lane = int.tryParse(keyParts[3]) ?? 0;
          
          // Only process if it's for current week
          if (weekNum != widget.weekNumber) continue;
          
          // Check if this block is being dragged
          final blockKey = '${entry.value.id}-$shiftTitle-$lane-$startDay';
          final dragState = _dragStates?[blockKey];
          
          // Find contiguous assignment duration
          int duration = 1;
          for (int day = startDay + 1; day < 7; day++) {
            final nextKey = '${widget.weekNumber}-$shiftTitle-$day-$lane'; // Week-specific
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
            final gridLeft = 40;
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
              top: lane * rowHeight,
              width: visualWidth,
              height: rowHeight - 1,
              child: _buildAssignmentBlock(entry.value, shiftTitle, startDay, lane),
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
      if (entry.key.startsWith(shiftTitles[0]) && !processedAssignments.contains(entry.key)) {
        final keyParts = entry.key.split('-');
        if (keyParts.length >= 3) {
          final startDay = int.tryParse(keyParts[1]) ?? 0;
          final lane = int.tryParse(keyParts[2]) ?? 0;
          
          // Check if this block is being dragged
          final blockKey = '${entry.value.id}-${shiftTitles[0]}-$lane-$startDay';
          final dragState = _dragStates?[blockKey];
          
          // Find contiguous assignment duration
          int duration = 1;
          for (int day = startDay + 1; day < 7; day++) {
            final nextKey = '${shiftTitles[0]}-$day-$lane';
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
              top: 20 + (lane * rowHeight), // 20 for header
              width: visualWidth,
              height: rowHeight - 1,
              child: _buildAssignmentBlock(entry.value, shiftTitles[0], startDay, lane),
            ),
          );
          processedAssignments.add(entry.key);
        }
      }
    }
    
    // Add night shift blocks (offset by day shift rows + header)
    processedAssignments.clear();
    for (final entry in _assignments.entries) {
      if (entry.key.startsWith(shiftTitles[1]) && !processedAssignments.contains(entry.key)) {
        final keyParts = entry.key.split('-');
        if (keyParts.length >= 3) {
          final startDay = int.tryParse(keyParts[1]) ?? 0;
          final lane = int.tryParse(keyParts[2]) ?? 0;
          
          // Check if this block is being dragged
          final blockKey = '${entry.value.id}-${shiftTitles[1]}-$lane-$startDay';
          final dragState = _dragStates?[blockKey];
          
          // Find contiguous assignment duration
          int duration = 1;
          for (int day = startDay + 1; day < 7; day++) {
            final nextKey = '${shiftTitles[1]}-$day-$lane';
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
              top: 20 + (dayShiftOffset * rowHeight) + 20 + (lane * rowHeight), // Day rows + night header
              width: visualWidth,
              height: rowHeight - 1,
              child: _buildAssignmentBlock(entry.value, shiftTitles[1], startDay, lane),
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
          if (!isInResizeMode) {
            _toggleResizeMode(employee, shiftTitle, blockStartDay, blockLane);
          }
        },
        onTap: () {
          if (isInResizeMode) {
            _toggleResizeMode(employee, shiftTitle, blockStartDay, blockLane);
          } else {
            _showAssignmentMenu(context, employee, shiftTitle);
          }
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
    return Container(
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: _getCategoryColor(employee.category),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[400]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          employee.name,
          style: TextStyle(
            fontSize: 11,
            color: _getTextColorForCategory(employee.category),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showAssignmentMenu(BuildContext context, Employee employee, String shiftTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(employee.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_with, color: Colors.blue),
                title: const Text('Move'),
                onTap: () {
                  Navigator.pop(context);
                  // Remove current assignment for moving
                  _handleRemove(employee, shiftTitle);
                  // Show snackbar to indicate employee is ready to be placed
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${employee.name} removed. Drag from employee list to new position.'),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.unfold_more, color: Colors.green),
                title: const Text('Extend to 7 days'),
                onTap: () {
                  Navigator.pop(context);
                  // Remove current assignment and assign for all 7 days
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
                    final keyParts = firstKey.split('-');
                    if (keyParts.length >= 4) { // Week-shift-day-lane format
                      final lane = int.tryParse(keyParts[3]) ?? 0;
                      // Remove current assignment
                      _handleRemove(employee, shiftTitle);
                      // Assign for all 7 days starting from day 0
                      _handleResize(employee, shiftTitle, 0, 7, lane);
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.compress, color: Colors.orange),
                title: const Text('Make single day'),
                onTap: () {
                  Navigator.pop(context);
                  // Remove all assignments and keep only the first day
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
                    final keyParts = firstKey.split('-');
                    if (keyParts.length >= 4) { // Week-shift-day-lane format
                      final startDay = int.tryParse(keyParts[2]) ?? 0; // Day is now index 2
                      final lane = int.tryParse(keyParts[3]) ?? 0; // Lane is now index 3
                      // Remove current assignment
                      _handleRemove(employee, shiftTitle);
                      // Add back just one day
                      setState(() {
                        final key = '${widget.weekNumber}-$shiftTitle-$startDay-$lane'; // Week-specific
                        _assignments[key] = employee;
                      });
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove'),
                onTap: () {
                  Navigator.pop(context);
                  _handleRemove(employee, shiftTitle);
                },
              ),
            ],
          ),
        );
      },
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
                margin: const EdgeInsets.fromLTRB(2, 0, 2, 2), // Reduced margins
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

              // Worker list - takes remaining space
              if (_showWorkerSection) Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(2, 0, 2, 2), // Reduced margins
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF9DB4C0), width: 1), // Cadet gray border
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2), // Reduced from 4
                    child: _buildFullWidthEmployeeGrid(),
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
                date.day.toString(),
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
    
    // Find the span of this block
    final thisBlockKeys = <String>[];
    for (int day = blockStartDay; day < 7; day++) {
      final key = '${widget.weekNumber}-$shiftTitle-$day-$blockLane';
      if (_assignments.containsKey(key) && _assignments[key]?.id == employee.id) {
        thisBlockKeys.add(key);
      } else {
        break;
      }
    }
    
    if (thisBlockKeys.isEmpty) return [];
    
    final dayIndices = thisBlockKeys
        .map((key) => int.tryParse(key.split('-')[2]) ?? 0)
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