import 'package:calendar_app/data/default_employees.dart';
import 'package:calendar_app/models/employee.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:calendar_app/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class YearView extends StatefulWidget {
  final int initialWeek;
  final Function(int)? onWeekChanged;
  final Function(String)? onViewChanged;
  
  const YearView({
    super.key, 
    this.initialWeek = 1, 
    this.onWeekChanged, 
    this.onViewChanged
  });

  @override
  State<YearView> createState() => _YearViewState();
}

class _YearViewState extends State<YearView> {
  late PageController _pageController;
  int _currentWeek = 1;
  final Map<String, Employee> _assignments = {};
  
  // Static maps for profession settings (shared with WeekView)
  static final Map<int, Map<EmployeeRole, bool>> _weekDayShiftProfessions = {};
  static final Map<int, Map<EmployeeRole, bool>> _weekNightShiftProfessions = {};
  static final Map<int, Map<EmployeeRole, int>> _weekDayShiftRows = {};
  static final Map<int, Map<EmployeeRole, int>> _weekNightShiftRows = {};

  @override
  void initState() {
    super.initState();
    _currentWeek = widget.initialWeek;
    _pageController = PageController(initialPage: widget.initialWeek - 1);
    _loadEmployees();
    _loadAssignments();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final employeesJson = prefs.getString('employees');
    
    if (employeesJson != null) {
      final List<dynamic> employeesList = json.decode(employeesJson);
      final loadedEmployees = employeesList.map((e) => Employee.fromJson(e)).toList();
      
      defaultEmployees.clear();
      defaultEmployees.addAll(loadedEmployees);
      
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadAssignments() async {
    // Load all assignments from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final assignmentsJson = prefs.getString('assignments');
    
    if (assignmentsJson != null) {
      final Map<String, dynamic> assignmentsMap = json.decode(assignmentsJson);
      _assignments.clear();
      
      for (final entry in assignmentsMap.entries) {
        final employeeData = entry.value as Map<String, dynamic>;
        _assignments[entry.key] = Employee.fromJson(employeeData);
      }
      
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

  Map<EmployeeRole, bool> _getDayShiftProfessions(int weekNumber) {
    if (!_weekDayShiftProfessions.containsKey(weekNumber)) {
      _weekDayShiftProfessions[weekNumber] = Map.from(_getDefaultDayShiftProfessions());
    }
    return _weekDayShiftProfessions[weekNumber]!;
  }
  
  Map<EmployeeRole, bool> _getNightShiftProfessions(int weekNumber) {
    if (!_weekNightShiftProfessions.containsKey(weekNumber)) {
      _weekNightShiftProfessions[weekNumber] = Map.from(_getDefaultNightShiftProfessions());
    }
    return _weekNightShiftProfessions[weekNumber]!;
  }
  
  Map<EmployeeRole, int> _getDayShiftRows(int weekNumber) {
    if (!_weekDayShiftRows.containsKey(weekNumber)) {
      _weekDayShiftRows[weekNumber] = Map.from(_getDefaultDayShiftRows());
    }
    return _weekDayShiftRows[weekNumber]!;
  }
  
  Map<EmployeeRole, int> _getNightShiftRows(int weekNumber) {
    if (!_weekNightShiftRows.containsKey(weekNumber)) {
      _weekNightShiftRows[weekNumber] = Map.from(_getDefaultNightShiftRows());
    }
    return _weekNightShiftRows[weekNumber]!;
  }

  List<String> _getShiftTitlesForWeek(int weekNumber) {
    final cyclePosition = (weekNumber - 1) % 4;
    switch (cyclePosition) {
      case 0: return ['A / Päivävuoro', 'B / Yövuoro'];
      case 1: return ['C / Päivävuoro', 'D / Yövuoro'];
      case 2: return ['B / Päivävuoro', 'A / Yövuoro'];
      case 3: return ['D / Päivävuoro', 'C / Yövuoro'];
      default: return ['A / Päivävuoro', 'B / Yövuoro'];
    }
  }

  List<DateTime> _getDatesForWeek(int weekNumber) {
    final year = 2025;
    final jan4 = DateTime(year, 1, 4);
    final firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final weekStart = firstMonday.add(Duration(days: (weekNumber - 1) * 7));
    final tuesdayStart = weekStart.add(const Duration(days: 1));
    return List.generate(7, (index) => tuesdayStart.add(Duration(days: index)));
  }

  Color _getCategoryColor(EmployeeCategory category) {
    return category.color;
  }

  Color _getTextColorForCategory(EmployeeCategory category) {
    switch (category) {
      case EmployeeCategory.ab:
      case EmployeeCategory.cd:
      case EmployeeCategory.huolto:
      case EmployeeCategory.sijainen:
        return Colors.black87;
    }
  }

  Widget _buildWeekPage(int weekNumber) {
    final shiftTitles = _getShiftTitlesForWeek(weekNumber);
    final dates = _getDatesForWeek(weekNumber);
    
    return Column(
      children: [
        // Week header with dates
        _buildWeekHeader(weekNumber, dates),
        // Vertically stacked shifts
        Expanded(
          child: Column(
            children: [
              // Day shift (top)
              Expanded(
                child: _buildShiftView(weekNumber, shiftTitles[0], true),
              ),
              // Night shift (bottom)
              Expanded(
                child: _buildShiftView(weekNumber, shiftTitles[1], false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekHeader(int weekNumber, List<DateTime> dates) {
    const List<String> weekdays = ['TI', 'KE', 'TO', 'PE', 'LA', 'SU', 'MA'];
    
    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
      decoration: BoxDecoration(
        color: const Color(0xFFC2DFE3),
        border: Border.all(color: const Color(0xFF9DB4C0), width: 1),
      ),
      child: Row(
        children: [
          // Week number
          Container(
            width: 50,
            child: Center(
              child: Text(
                'W$weekNumber',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF253237),
                ),
              ),
            ),
          ),
          // Day headers
          Expanded(
            child: Row(
              children: dates.asMap().entries.map((entry) {
                final index = entry.key;
                final date = entry.value;
                
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekdays[index],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: Color(0xFF253237),
                          ),
                        ),
                        Text(
                          date.day.toString(),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF5C6B73),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftView(int weekNumber, String shiftTitle, bool isDayShift) {
    const rowHeight = 20.0; // Smaller for year view
    final dayWidth = (MediaQuery.of(context).size.width - 50 - 16) / 7; // 50px for week number + margins
    
    final professions = isDayShift 
        ? _getDayShiftProfessions(weekNumber)
        : _getNightShiftProfessions(weekNumber);
    final rows = isDayShift 
        ? _getDayShiftRows(weekNumber)
        : _getNightShiftRows(weekNumber);
    
    int totalRows = 0;
    for (final profession in EmployeeRole.values.where((role) => professions[role] == true)) {
      totalRows += rows[profession] ?? 1;
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9DB4C0), width: 1),
      ),
      child: Column(
        children: [
          // Shift title
          Container(
            height: 24,
            color: isDayShift ? Colors.grey[200] : Colors.grey[300],
            child: Center(
              child: Text(
                shiftTitle,
                style: const TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.black87
                ),
              ),
            ),
          ),
          // Shift grid
          Expanded(
            child: Stack(
              children: [
                // Grid background
                Column(
                  children: List.generate(totalRows, (row) => 
                    Container(
                      height: rowHeight,
                      child: Row(
                        children: [
                          Container(width: 50), // Week number space
                          ...List.generate(7, (day) => 
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[200]!, width: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Assignment blocks
                ..._buildShiftAssignmentBlocks(weekNumber, shiftTitle, dayWidth, rowHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildShiftAssignmentBlocks(int weekNumber, String shiftTitle, double dayWidth, double rowHeight) {
    List<Widget> blocks = [];
    Set<String> processedAssignments = {};
    
    for (final entry in _assignments.entries) {
      if (entry.key.startsWith('$weekNumber-$shiftTitle') && !processedAssignments.contains(entry.key)) {
        final keyParts = entry.key.split('-');
        if (keyParts.length >= 4) {
          final weekNum = int.tryParse(keyParts[0]) ?? 0;
          final startDay = int.tryParse(keyParts[2]) ?? 0;
          final lane = int.tryParse(keyParts[3]) ?? 0;
          
          if (weekNum != weekNumber) continue;
          
          // Find contiguous assignment duration
          int duration = 1;
          for (int day = startDay + 1; day < 7; day++) {
            final nextKey = '$weekNumber-$shiftTitle-$day-$lane';
            if (_assignments.containsKey(nextKey) && _assignments[nextKey]?.id == entry.value.id) {
              duration++;
              processedAssignments.add(nextKey);
            } else {
              break;
            }
          }
          
          blocks.add(
            Positioned(
              left: 50 + (startDay * dayWidth), // Offset by week number width
              top: lane * rowHeight,
              width: (dayWidth * duration) - 1,
              height: rowHeight - 1,
              child: _buildAssignmentBlock(entry.value),
            ),
          );
          processedAssignments.add(entry.key);
        }
      }
    }
    
    return blocks;
  }

  Widget _buildAssignmentBlock(Employee employee) {
    return Container(
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: _getCategoryColor(employee.category),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.grey[400]!, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 1,
            offset: const Offset(0.5, 0.5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          employee.name,
          style: TextStyle(
            fontSize: 9, // Smaller for year view
            color: _getTextColorForCategory(employee.category),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0FBFC),
      body: SafeArea(
        child: Column(
          children: [
            // Year view header
            Container(
              height: 40,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF253237),
                border: Border.all(color: const Color(0xFF9DB4C0), width: 1),
              ),
              child: Row(
                children: [
                  // Back to week view
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      onPressed: () => widget.onViewChanged?.call('week'),
                      icon: const Icon(Icons.calendar_view_week, size: 16, color: Colors.white),
                      padding: EdgeInsets.zero,
                      tooltip: 'Week View',
                    ),
                  ),
                  // Current week indicator
                  Expanded(
                    child: Center(
                      child: Text(
                        'YEAR VIEW - Week $_currentWeek',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Jump to week button
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      onPressed: () {
                        widget.onWeekChanged?.call(_currentWeek);
                        widget.onViewChanged?.call('week');
                      },
                      icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                      padding: EdgeInsets.zero,
                      tooltip: 'Edit Week',
                    ),
                  ),
                ],
              ),
            ),
            // Swipeable weeks
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentWeek = page + 1;
                  });
                  widget.onWeekChanged?.call(_currentWeek);
                  HapticFeedback.lightImpact(); // Haptic feedback for smooth feel
                },
                itemCount: 52,
                itemBuilder: (context, index) {
                  return _buildWeekPage(index + 1);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 