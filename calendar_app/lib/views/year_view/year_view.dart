import 'package:calendar_app/data/default_employees.dart';
import 'package:calendar_app/models/employee.dart';
import 'package:calendar_app/models/vacation_absence.dart';
import 'package:calendar_app/data/vacation_manager.dart';
import 'package:calendar_app/views/employee_settings/employee_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:calendar_app/services/auth_service.dart';
import 'package:calendar_app/services/shared_data_service.dart';
import 'package:calendar_app/services/shared_assignment_data.dart';
import 'package:calendar_app/models/user_tier.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Platform-specific fullscreen imports
import 'fullscreen_stub.dart'
if (dart.library.html) 'fullscreen_web.dart'
if (dart.library.io) 'fullscreen_mobile.dart' as fullscreen;

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
  int _selectedYear = 2025; // Default year, can be changed
  UserTier _userTier = UserTier.tier1;
  
  // 🔥 SHARED DATA - Use truly shared data class with year awareness
  Map<String, Employee> get _assignments => SharedAssignmentData.getAssignmentsForYear(_selectedYear);
  Map<int, Map<EmployeeRole, bool>> get _weekDayShiftProfessions => SharedAssignmentData.weekDayShiftProfessions;
  Map<int, Map<EmployeeRole, bool>> get _weekNightShiftProfessions => SharedAssignmentData.weekNightShiftProfessions;
  Map<int, Map<EmployeeRole, int>> get _weekDayShiftRows => SharedAssignmentData.weekDayShiftRows;
  Map<int, Map<EmployeeRole, int>> get _weekNightShiftRows => SharedAssignmentData.weekNightShiftRows;

  @override
  void initState() {
    super.initState();
    _currentWeek = widget.initialWeek > 0 ? widget.initialWeek : _getCurrentWeek(); // Start from current week if no initial week specified
    _pageController = PageController(initialPage: _currentWeek - 1);
    
    // Listen for assignment data changes
    SharedAssignmentData.addListener(_onAssignmentDataChanged);
    
    // 🔥 LISTEN FOR YEAR CHANGES FROM OTHER VIEWS
    SharedAssignmentData.addYearChangeListener(_onYearChanged);
    
    _loadUserTier(); // Load user tier for permissions
    _loadSelectedYear(); // Load saved year selection
    _loadCustomProfessions(); // Load custom professions first
    _loadEmployees();
    // 🚀 ACTIVE LOADING: Load assignment data independently
    _loadAssignments();
    _loadProfessionSettings(); // LOAD GLOBAL PROFESSION SETTINGS
    VacationManager.loadVacations(); // Load vacation data
    
    // 🔥 FIX LOADING TIMING - Force a proper refresh after everything is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        SharedAssignmentData.forceRefresh();
        setState(() {});
      }
    });
  }
  
  @override
  void dispose() {
    SharedAssignmentData.removeListener(_onAssignmentDataChanged);
    SharedAssignmentData.removeYearChangeListener(_onYearChanged);
    _pageController.dispose();
    super.dispose();
  }
  
  // 🔥 HANDLE YEAR CHANGES FROM OTHER VIEWS
  void _onYearChanged(int newYear) {
    if (mounted && newYear != _selectedYear) {
      setState(() {
        _selectedYear = newYear;
      });
      _saveSelectedYear(); // Save the new year
      print('Year View - Year changed from other view to: $newYear');
    }
  }
  
  void _onAssignmentDataChanged() {
    if (mounted) {
      // Reload profession settings to sync with any changes from WeekView
      _loadProfessionSettings();
      
      // Force immediate UI refresh when assignment data changes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
      print('Year View - Refreshed due to assignment data change: ${SharedAssignmentData.assignmentCount} assignments');
    }
  }

  Future<void> _loadUserTier() async {
    try {
      final tier = await AuthService.getCurrentUserTier();
      if (mounted) {
        setState(() {
          _userTier = tier;
        });
      }
    } catch (e) {
      print('Error loading user tier: $e');
    }
  }

  Future<void> _loadSelectedYear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedYear = prefs.getInt('selected_year');
      if (savedYear != null && mounted) {
        setState(() {
          _selectedYear = savedYear;
          SharedAssignmentData.currentYear = savedYear; // Update shared year
        });
      }
    } catch (e) {
      print('Error loading selected year: $e');
    }
  }

  Future<void> _saveSelectedYear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_year', _selectedYear);
    } catch (e) {
      print('Error saving selected year: $e');
    }
  }

  void _showYearPicker() {
    const currentYear = 2025;
    const startYear = 2020;
    const endYear = 2035; // 15 years range
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Year'),
        content: Container(
          width: 300,
          height: 400,
          child: ListView.builder(
            itemCount: endYear - startYear + 1,
            itemBuilder: (context, index) {
              final year = startYear + index;
              final isSelected = year == _selectedYear;
              final isCurrent = year == currentYear;
              
              return ListTile(
                title: Text(
                  year.toString(),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? Colors.blue : null,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                selected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedYear = year;
                  });
                  SharedAssignmentData.setCurrentYear(year); // 🔥 NOTIFY ALL VIEWS
                  _saveSelectedYear();
                  Navigator.pop(context);
                },
              );
            },
          ),
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

  void _navigateToWeek(int weekNumber) {
    setState(() {
      _currentWeek = weekNumber.clamp(1, 52);
    });
    
    _pageController.animateToPage(
      _currentWeek - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    widget.onWeekChanged?.call(_currentWeek);
    HapticFeedback.lightImpact();
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
      print('Year View - Error loading employees: $e');
      // Fallback to empty list if database fails
      defaultEmployees.clear();
      if (mounted) {
        setState(() {});
      }
    }
  }

  // 🚀 YEAR VIEW ACTIVE LOADING - Load data independently like WeekView
  Future<void> _loadAssignments() async {
    try {
      // Clear old SharedPreferences data (migration) - one time only
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('assignments');
      
      print('Year View - 🔄 Loading assignments for current week $_currentWeek...');
      
      // 🚀 LOAD CURRENT WEEK FIRST (what user sees immediately)
      if (SharedAssignmentData.getWeekAssignmentCount(_currentWeek) == 0) {
        final currentWeekAssignments = await SharedDataService.loadAssignments(_currentWeek);
        SharedAssignmentData.updateAssignmentsForWeek(_currentWeek, currentWeekAssignments);
        print('Year View - ✅ Loaded current week $_currentWeek: ${currentWeekAssignments.length} assignments');
        
        if (mounted) {
          setState(() {});
        }
      }
      
      // 🔮 BACKGROUND LOADING: Load adjacent weeks for smooth navigation
      final List<int> priorityWeeks = [
        _currentWeek - 1,
        _currentWeek + 1,
        _currentWeek - 2,
        _currentWeek + 2,
      ].where((week) => week >= 1 && week <= 52).toList();
      
      for (final week in priorityWeeks) {
        if (SharedAssignmentData.getWeekAssignmentCount(week) == 0) {
          Future.delayed(Duration(milliseconds: 100 * priorityWeeks.indexOf(week)), () async {
            try {
              final weekAssignments = await SharedDataService.loadAssignments(week);
              SharedAssignmentData.updateAssignmentsForWeek(week, weekAssignments);
              print('Year View - 🔮 Background loaded week $week: ${weekAssignments.length} assignments');
              if (mounted) {
                setState(() {});
              }
            } catch (e) {
              print('Year View - ⚠️ Background load failed for week $week: $e');
            }
          });
        }
      }
      
      print('Year View - ✅ Active loading complete: ${SharedAssignmentData.assignmentCount} total assignments');
      
    } catch (e) {
      print('Year View - ❌ Error loading assignments: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadProfessionSettings() async {
    try {
      // 🔥 100% SUPABASE STORAGE - Load settings for current week
      final supabaseData = await SharedDataService.loadProfessionSettings(_currentWeek);
      
      if (supabaseData.isNotEmpty) {
        final dayProfessions = supabaseData['dayProfessions'] as Map<EmployeeRole, bool>?;
        final nightProfessions = supabaseData['nightProfessions'] as Map<EmployeeRole, bool>?;
        final dayRows = supabaseData['dayRows'] as Map<EmployeeRole, int>?;
        final nightRows = supabaseData['nightRows'] as Map<EmployeeRole, int>?;
        
        if (dayProfessions != null && dayProfessions.isNotEmpty) {
          _weekDayShiftProfessions[_currentWeek] = Map.from(dayProfessions);
        }
        if (nightProfessions != null && nightProfessions.isNotEmpty) {
          _weekNightShiftProfessions[_currentWeek] = Map.from(nightProfessions);
        }
        if (dayRows != null && dayRows.isNotEmpty) {
          _weekDayShiftRows[_currentWeek] = Map.from(dayRows);
        }
        if (nightRows != null && nightRows.isNotEmpty) {
          _weekNightShiftRows[_currentWeek] = Map.from(nightRows);
        }
        
        print('YearView: ✅ Loaded profession settings from Supabase for week $_currentWeek');
      } else {
        print('YearView: No settings found in Supabase for week $_currentWeek, using defaults');
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('YearView: ❌ Error loading profession settings from Supabase: $e');
    }
  }

  Future<void> _loadCustomProfessions() async {
    try {
      // 🔥 100% SUPABASE STORAGE - Load custom professions from cloud
      await CustomProfessionManager.loadFromSupabase(SharedDataService.supabase);
      print('YearView: ✅ Loaded ${CustomProfessionManager.allCustomProfessions.length} custom professions from Supabase');
    } catch (e) {
      print('YearView: ❌ Error loading custom professions from Supabase: $e');
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
    final jan4 = DateTime(_selectedYear, 1, 4);
    final firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final weekStart = firstMonday.add(Duration(days: (weekNumber - 1) * 7));
    final tuesdayStart = weekStart.add(const Duration(days: 1));
    return List.generate(7, (index) => tuesdayStart.add(Duration(days: index)));
  }

  // 🔥 USE CUSTOM CATEGORY COLORS FROM SHARED DATA!
  Color _getCategoryColor(EmployeeCategory category) {
    return SharedAssignmentData.getCategoryColor(category);
  }

  Color _getTextColorForCategory(EmployeeCategory category) {
    return SharedAssignmentData.getTextColorForCategory(category);
  }

  Widget _buildWeekPage(int weekNumber) {
    final shiftTitles = _getShiftTitlesForWeek(weekNumber);
    final dates = _getDatesForWeek(weekNumber); // GET THE DATES!
    
    // Calculate day shift total rows first
    final dayProfessions = _getDayShiftProfessions(weekNumber);
    final dayRows = _getDayShiftRows(weekNumber);
    final dayVisibleProfessions = EmployeeRole.values
        .where((role) => dayProfessions[role] == true)
        .toList();
    
    int dayTotalRows = 0;
    for (final profession in dayVisibleProfessions) {
      dayTotalRows += dayRows[profession] ?? 1;
    }
    
    // Calculate night shift total rows
    final nightProfessions = _getNightShiftProfessions(weekNumber);
    final nightRows = _getNightShiftRows(weekNumber);
    final nightVisibleProfessions = EmployeeRole.values
        .where((role) => nightProfessions[role] == true)
        .toList();
    
    int nightTotalRows = 0;
    for (final profession in nightVisibleProfessions) {
      nightTotalRows += nightRows[profession] ?? 1;
    }
    
    const rowHeight = 20.0;
    final dayShiftHeight = (dayTotalRows * rowHeight) + 30; // 30px for header
    final nightShiftHeight = (nightTotalRows * rowHeight) + 30; // 30px for header
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // 🔥 ADD THE MISSING DATE HEADER!
          _buildWeekHeader(weekNumber, dates),
          // Day shift
          Container(
            height: dayShiftHeight,
            child: _buildShiftView(weekNumber, shiftTitles[0], true),
          ),
          // Night shift - NO GAP, starts immediately after day shift
          Container(
            height: nightShiftHeight,
            child: _buildShiftView(weekNumber, shiftTitles[1], false),
          ),
          // Add some bottom padding for scroll
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWeekHeader(int weekNumber, List<DateTime> dates) {
    const List<String> weekdays = ['TI', 'KE', 'TO', 'PE', 'LA', 'SU', 'MA'];
    
    return Container(
      height: 32, // Reduced from 40 to match week view
      margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
      decoration: BoxDecoration(
        color: const Color(0xFFC2DFE3),
        border: Border.all(color: const Color(0xFF9DB4C0), width: 1),
      ),
      child: Row(
        children: [
          // Profession header space - REMOVED "ROLE" TEXT
          Container(
            width: 32, // 🔥 MATCH WEEK VIEW: Consistent with week view profession column
            child: const Center(
              child: Text(
                '', // Empty - no more "ROLE" text
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
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
                            fontSize: 10, // Reduced from 11
                            color: Color(0xFF253237),
                          ),
                        ),
                        Text(
                          '${date.day}.${date.month}',
                          style: const TextStyle(
                            fontSize: 8, // Reduced from 9
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
    const rowHeight = 20.0; // Reduced from 24.0 to fit more content
    final effectiveWidth = _getEffectiveWidth();
    final professionColumnWidth = 32.0; // 🔥 MATCH WEEK VIEW: Same as week view for consistency
    final containerMargins = 4.0; // 2px left + 2px right from container margins
    final borderWidth = 2.0; // 1px left + 1px right from container borders
    final availableGridWidth = effectiveWidth - professionColumnWidth - containerMargins - borderWidth;
    final dayWidth = availableGridWidth / 7; // Precise calculation matching week view
    
    final professions = isDayShift 
        ? _getDayShiftProfessions(weekNumber)
        : _getNightShiftProfessions(weekNumber);
    final rows = isDayShift 
        ? _getDayShiftRows(weekNumber)
        : _getNightShiftRows(weekNumber);
    
    // Use EXACT same ordering as week view
    final visibleProfessions = EmployeeRole.values
        .where((role) => professions[role] == true)
        .toList();
    
    int totalRows = 0;
    for (final profession in visibleProfessions) {
      totalRows += rows[profession] ?? 1;
    }
    
    // Ensure minimum height to prevent overlap
    final minShiftHeight = (totalRows * rowHeight) + 30; // Add 30px for header + spacing
    
    return Container(
      height: minShiftHeight, // Fixed height based on content
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9DB4C0), width: 1),
      ),
      child: Column(
        children: [
          // Shift title - MATCH WEEK VIEW COLORS!
          Container(
            height: 24, // Reduced from 28 for more compact design
            color: const Color(0xFF5C6B73), // MATCH WEEK VIEW ACTIVE TAB COLOR!
            child: Row(
              children: [
                Container(width: 32), // 🔥 MATCH WEEK VIEW: Consistent profession column width
                Expanded(
                  child: Center(
                      child: Text(
                      shiftTitle,
                      style: const TextStyle(
                        fontSize: 10, // Reduced from 11 for more compact
                        fontWeight: FontWeight.bold, 
                        color: Colors.white // WHITE TEXT ON DARK BACKGROUND!
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
                SizedBox(
                  width: 32, // 🔥 MATCH WEEK VIEW: Consistent with week view and calculations
                  child: Column( // Remove scroll for profession labels to prevent misalignment
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
                                      color: Colors.white, // White background for year view
                                      border: Border.all(color: Colors.grey[400]!, width: 1), // Thicker borders for better alignment reference
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
    // Use the EXACT same logic as week view with EmployeeRole.values ordering
    return EmployeeRole.values.where((role) => visibleProfessions.contains(role)).expand((profession) {
      final professionRows = rows[profession] ?? 1;
      return List.generate(professionRows, (index) => Container(
        height: rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF5C6B73), // SAME COLOR AS SHIFT HEADERS
          border: Border(bottom: BorderSide(color: const Color(0xFF253237), width: 0.5)), // Darker border
        ),
        child: Text(
          _getCompactRoleName(profession), // Use EXACT same naming as week view
          style: const TextStyle(
            color: Colors.white, // White text on dark background
            fontSize: 7, // Reduced from 8 to fit narrower column
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ));
    }).toList();
  }

  // EXACT same function as week view
  String _getCompactRoleName(EmployeeRole role) {
    // Use shared compact role name method
    return SharedAssignmentData.getCompactRoleName(role);
  }

  String _getRoleDisplayName(EmployeeRole role) {
    // Use shared role display name method
    return SharedAssignmentData.getRoleDisplayName(role);
  }

  // 🔥 PROFESSION-BASED STORAGE SYSTEM - NO MORE LANE MISALIGNMENT! 🔥
  
  /// Convert profession + profession row to absolute lane
  /// Returns -1 if profession is not visible or row is invalid
  int _getProfessionToAbsoluteLane(EmployeeRole profession, int professionRow, String shiftTitle, Map<EmployeeRole, int> rows, int weekNumber) {
    final isDay = !shiftTitle.toLowerCase().contains('yö');
    
    // Get profession visibility for this specific week
    final dayProfessions = _weekDayShiftProfessions[weekNumber] ?? _getDefaultDayShiftProfessions();
    final nightProfessions = _weekNightShiftProfessions[weekNumber] ?? _getDefaultNightShiftProfessions();
    
    final visibleProfessions = EmployeeRole.values
        .where((role) => isDay ? dayProfessions[role] == true : nightProfessions[role] == true)
        .toList();
    
    int currentLane = 0;
    for (final visibleProfession in visibleProfessions) {
      if (visibleProfession == profession) {
        final maxRows = rows[profession] ?? 1;
        if (professionRow >= 0 && professionRow < maxRows) {
          return currentLane + professionRow;
        }
        return -1; // Invalid row
      }
      
      final professionRows = rows[visibleProfession] ?? 1;
      currentLane += professionRows;
    }
    
    return -1; // Profession not visible
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
  
  /// Generate new profession-based assignment key
  String _generateAssignmentKey(int weekNumber, String shiftTitle, int day, EmployeeRole profession, int professionRow) {
    return '$weekNumber-$shiftTitle-$day-${profession.name}-$professionRow';
  }

  List<Widget> _buildShiftAssignmentBlocks(int weekNumber, String shiftTitle, double dayWidth, double rowHeight) {
    List<Widget> blocks = [];
    Set<String> processedAssignments = {};
    
    // Get profession rows for this shift and week
    final isDay = !shiftTitle.toLowerCase().contains('yö');
    final rows = isDay 
        ? (_weekDayShiftRows[weekNumber] ?? _getDefaultDayShiftRows())
        : (_weekNightShiftRows[weekNumber] ?? _getDefaultNightShiftRows());
    
    for (final entry in _assignments.entries) {
      if (!processedAssignments.contains(entry.key)) {
        final parsed = _parseAssignmentKey(entry.key);
        if (parsed != null && 
            parsed['weekNumber'] == weekNumber && 
            parsed['shiftTitle'] == shiftTitle) {
          
          final startDay = parsed['day'] as int;
          final profession = parsed['profession'] as EmployeeRole;
          final professionRow = parsed['professionRow'] as int;
          
          // 🔥 BACK TO ORIGINAL POSITIONING SYSTEM!
          final absoluteLane = _getProfessionToAbsoluteLane(profession, professionRow, shiftTitle, rows, weekNumber);
          if (absoluteLane == -1) continue; // Profession not visible or invalid row
          
          // Find contiguous assignment duration using profession-based keys
          int duration = 1;
          for (int day = startDay + 1; day < 7; day++) {
            final nextKey = _generateAssignmentKey(weekNumber, shiftTitle, day, profession, professionRow);
            if (_assignments.containsKey(nextKey) && _assignments[nextKey]?.id == entry.value.id) {
              duration++;
              processedAssignments.add(nextKey);
            } else {
              break;
            }
          }
          
          blocks.add(
            Positioned(
              left: startDay * dayWidth + 1, // Account for left border of first cell
              top: absoluteLane * rowHeight + 1, // Account for top border of cell
              width: (dayWidth * duration) - 2, // Account for both side borders
              height: rowHeight - 2, // Account for both top/bottom borders  
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
      width: double.infinity, // Ensure full width
      height: double.infinity, // Ensure full height
      decoration: BoxDecoration(
        color: _getCategoryColor(employee.category),
        borderRadius: BorderRadius.circular(1), // Minimal radius for sharp edges
        border: Border.all(color: Colors.grey[800]!, width: 0.3), // Thin, dark border
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1), // Minimal padding
          child: Text(
            employee.name,
            style: TextStyle(
              fontSize: 8, // Appropriate size for compact view
              color: _getTextColorForCategory(employee.category),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  // Calculate current week of year
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

  // Fullscreen toggle functionality
  void _toggleFullscreen() {
    try {
      fullscreen.toggleFullscreen();
    } catch (e) {
      print('Fullscreen not supported on this platform');
    }
  }



  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0FBFC),
      body: SafeArea(
        child: Center(
          child: Container(
            width: kIsWeb ? 800 : null, // A4 portrait width for PC/Web
            child: Column(
          children: [
            // Fixed header with navigation
            Container(
              height: 40, // Reduced from 60 to match week view compactness
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
                decoration: BoxDecoration(
                color: const Color(0xFF253237),
                border: Border.all(color: const Color(0xFF9DB4C0), width: 1),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _showMainMenu(context),
                    icon: const Icon(Icons.menu, size: 16, color: Colors.white), // Menu icon
                    padding: EdgeInsets.zero,
                    tooltip: 'Main Menu',
                  ),
                  const SizedBox(width: 8), // Reduced spacing
                  // Year selector button
                  GestureDetector(
                    onTap: _showYearPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_selectedYear',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                      'W$_currentWeek',
                        style: const TextStyle(
                        fontSize: 10, // Tiny size to match phone screen
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Current week button
                  IconButton(
                    onPressed: () {
                      final currentWeek = _getCurrentWeek();
                      final currentYear = DateTime.now().year;
                      setState(() {
                        _currentWeek = currentWeek;
                        _selectedYear = currentYear;
                        SharedAssignmentData.currentYear = currentYear;
                      });
                      _saveSelectedYear();
                      _pageController.animateToPage(
                        currentWeek - 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      widget.onWeekChanged?.call(currentWeek);
                      HapticFeedback.lightImpact();
                    },
                    icon: const Icon(Icons.today, size: 16, color: Colors.white),
                    padding: EdgeInsets.zero,
                    tooltip: 'Go to Current Week & Year',
                  ),
                  
                  // 🔥 ADD WEEK NAVIGATION BUTTONS FOR PC
                  if (kIsWeb) ...[
                    const SizedBox(width: 4),
                    // Previous week button
                    IconButton(
                      onPressed: _currentWeek > 1 ? () => _navigateToWeek(_currentWeek - 1) : null,
                      icon: const Icon(Icons.chevron_left, size: 18, color: Colors.white),
                      padding: EdgeInsets.zero,
                      tooltip: 'Previous Week',
                    ),
                    // Next week button  
                    IconButton(
                      onPressed: _currentWeek < 52 ? () => _navigateToWeek(_currentWeek + 1) : null,
                      icon: const Icon(Icons.chevron_right, size: 18, color: Colors.white),
                      padding: EdgeInsets.zero,
                      tooltip: 'Next Week',
                    ),
                  ],

                  const SizedBox(width: 8), // Reduced spacing
                  
                  // Only show EDIT button for Tier 1 users
                  if (_userTier.canAccessWeekView) ...[
                    const SizedBox(width: 8), // Reduced spacing
                    TextButton(
                      onPressed: () => widget.onViewChanged?.call('VIIKKO'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Compact padding
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        'EDIT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12, // Smaller text
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8), // Reduced spacing
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VIEW ONLY',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Scrollable content area
            Expanded(
              child: Container(
                color: const Color(0xFFE0FBFC),
                child: Focus(
                  autofocus: true,
                  onKey: (node, event) {
                    if (event is RawKeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        _navigateToWeek(_currentWeek - 1);
                        return KeyEventResult.handled;
                      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                        _navigateToWeek(_currentWeek + 1);
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(), // Better for PC scrolling
                    onPageChanged: (index) {
                      final newWeek = index + 1;
                      setState(() {
                        _currentWeek = newWeek;
                      });
                      widget.onWeekChanged?.call(_currentWeek);
                      HapticFeedback.lightImpact();
                    },
                    itemCount: 52,
                    itemBuilder: (context, index) {
                      final weekNumber = index + 1;
                      return _buildWeekPage(weekNumber);
                    },
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // Main menu function
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
                widget.onViewChanged?.call('EDIT');
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.white),
              title: const Text('DISPLAY MODE', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
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

  void _navigateToEmployeeSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmployeeSettingsView(),
      ),
    );
  }
} 