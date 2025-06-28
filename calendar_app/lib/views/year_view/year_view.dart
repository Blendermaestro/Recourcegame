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
    
    print('Year View - Loading assignments...');
    
    if (assignmentsJson != null) {
      final Map<String, dynamic> assignmentsMap = json.decode(assignmentsJson);
      _assignments.clear();
      
      for (final entry in assignmentsMap.entries) {
        final employeeData = entry.value as Map<String, dynamic>;
        _assignments[entry.key] = Employee.fromJson(employeeData);
      }
      
      print('Year View - Loaded ${_assignments.length} assignments:');
      for (final key in _assignments.keys) {
        print('  $key -> ${_assignments[key]?.name}');
      }
      
      if (mounted) {
        setState(() {});
      }
    } else {
      print('Year View - No assignments found in SharedPreferences');
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
    switch (category) {
      case EmployeeCategory.ab:
        return Colors.green[400]!; // Light green
      case EmployeeCategory.cd:
        return Colors.blue[400]!; // Light blue
      case EmployeeCategory.huolto:
        return Colors.orange[400]!; // Light orange
      case EmployeeCategory.sijainen:
        return Colors.yellow[400]!; // Light yellow
    }
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
          // Profession header space
          Container(
            width: 60,
            child: const Center(
              child: Text(
                'ROLE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
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
    final dayWidth = (MediaQuery.of(context).size.width - 60 - 16) / 7; // 60px professions + margins
    
    final professions = isDayShift 
        ? _getDayShiftProfessions(weekNumber)
        : _getNightShiftProfessions(weekNumber);
    final rows = isDayShift 
        ? _getDayShiftRows(weekNumber)
        : _getNightShiftRows(weekNumber);
    
    // Get visible professions in order
    final visibleProfessions = EmployeeRole.values
        .where((role) => professions[role] == true)
        .toList();
    
    int totalRows = 0;
    for (final profession in visibleProfessions) {
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
            child: Row(
              children: [
                Container(width: 60), // Profession space
                Expanded(
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
              ],
            ),
          ),
          // Shift grid with profession labels
          Expanded(
            child: Row(
              children: [
                // Profession labels column
                Container(
                  width: 60,
                  child: Column(
                    children: _buildProfessionLabels(visibleProfessions, rows, rowHeight),
                  ),
                ),
                // Days grid with assignment blocks
                Expanded(
                  child: Stack(
                    children: [
                      // Grid background
                      Column(
                        children: List.generate(totalRows, (row) => 
                          Container(
                            height: rowHeight,
                            child: Row(
                              children: List.generate(7, (day) => 
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[200]!, width: 0.5),
                                    ),
                                  ),
                                ),
                              ),
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
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProfessionLabels(List<EmployeeRole> visibleProfessions, Map<EmployeeRole, int> rows, double rowHeight) {
    final List<Widget> labels = [];
    
    for (final profession in visibleProfessions) {
      final professionRows = rows[profession] ?? 1;
      
      for (int rowIndex = 0; rowIndex < professionRows; rowIndex++) {
        labels.add(
          Container(
            height: rowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
              ),
              color: rowIndex % 2 == 0 ? Colors.grey[100] : Colors.grey[50],
            ),
            child: Text(
              rowIndex == 0 ? _getRoleDisplayName(profession) : '${rowIndex + 1}',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: rowIndex == 0 ? Colors.black87 : Colors.black54,
              ),
            ),
          ),
        );
      }
    }
    
    return labels;
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

  List<Widget> _buildShiftAssignmentBlocks(int weekNumber, String shiftTitle, double dayWidth, double rowHeight) {
    List<Widget> blocks = [];
    Set<String> processedAssignments = {};
    
    // DEBUG: Print assignment keys to see what's available
    print('Year View Debug - Week $weekNumber, Shift: $shiftTitle');
    print('Available assignments: ${_assignments.keys.where((k) => k.startsWith('$weekNumber-')).toList()}');
    
    for (final entry in _assignments.entries) {
      final key = entry.key;
      
      // Parse key: should be like "1-A / Päivävuoro-2-1" (week-shift-day-lane)  
      // But shift title has "/" and spaces, so we need to be more careful
      if (key.startsWith('$weekNumber-') && key.contains(shiftTitle) && !processedAssignments.contains(key)) {
        // Split carefully - the shift title contains spaces and "/"
        final parts = key.split('-');
        if (parts.length >= 4) {
          final weekPart = parts[0];
          
          // Find where shift title ends and day begins  
          // Key format: week-shiftTitle-day-lane
          // But shiftTitle can have spaces/slashes
          final keyWithoutWeek = key.substring(weekPart.length + 1); // Remove "week-"
          
          if (keyWithoutWeek.startsWith(shiftTitle)) {
            final afterShift = keyWithoutWeek.substring(shiftTitle.length + 1); // Remove "shiftTitle-"
            final remainingParts = afterShift.split('-');
            
            if (remainingParts.length >= 2) {
              final startDay = int.tryParse(remainingParts[0]) ?? 0;
              final lane = int.tryParse(remainingParts[1]) ?? 0;
              
              print('Found assignment: $key -> ${entry.value.name} (day: $startDay, lane: $lane)');
              
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
                  left: startDay * dayWidth,
                  top: lane * rowHeight,
                  width: (dayWidth * duration) - 1,
                  height: rowHeight - 1,
                  child: _buildAssignmentBlock(entry.value),
                ),
              );
              processedAssignments.add(key);
            }
          }
        }
      }
    }
    
    print('Created ${blocks.length} blocks for $shiftTitle');
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
                  // Back to week view (preserve current week)
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      onPressed: () {
                        widget.onWeekChanged?.call(_currentWeek);
                        widget.onViewChanged?.call('VIIKKO');
                      },
                      icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white),
                      padding: EdgeInsets.zero,
                      tooltip: 'Back to Week $_currentWeek',
                    ),
                  ),
                  // Current week indicator
                  Expanded(
                    child: Center(
                      child: Text(
                        'WEEK $_currentWeek OVERVIEW',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // EDIT WEEK button - bright and obvious
                  Container(
                    width: 80,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C6B73),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: InkWell(
                      onTap: () {
                        widget.onWeekChanged?.call(_currentWeek);
                        widget.onViewChanged?.call('VIIKKO');
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: const Center(
                        child: Text(
                          'EDIT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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