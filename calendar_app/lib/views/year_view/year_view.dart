import 'package:calendar_app/data/default_employees.dart';
import 'package:calendar_app/models/employee.dart';
import 'package:calendar_app/models/vacation_absence.dart';
import 'package:calendar_app/data/vacation_manager.dart';
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
  UserTier _userTier = UserTier.tier1;
  
  // 🔥 SHARED DATA - Use truly shared data class
  Map<String, Employee> get _assignments => SharedAssignmentData.assignments;
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
    
    _loadUserTier(); // Load user tier for permissions
    _loadCustomProfessions(); // Load custom professions first
    _loadEmployees();
    // Note: YearView is read-only, assignments loaded via SharedAssignmentData listener
    _loadProfessionSettings(); // LOAD GLOBAL PROFESSION SETTINGS
    VacationManager.loadVacations(); // Load vacation data
  }
  
  @override
  void dispose() {
    SharedAssignmentData.removeListener(_onAssignmentDataChanged);
    _pageController.dispose();
    super.dispose();
  }
  
  void _onAssignmentDataChanged() {
    if (mounted) {
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

  // 🔥 YEAR VIEW IS READ-ONLY - Just display what's already loaded by WeekView
  void _loadAssignments() async {
    // Clear old SharedPreferences data (migration) - one time only
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('assignments');
    
    // 🔥 FORCE IMMEDIATE REFRESH - Ensure we show current assignments
    if (mounted) {
      setState(() {});
      print('Year View - Read-only mode: Displaying ${SharedAssignmentData.assignmentCount} assignments already loaded by WeekView');
    }
  }

  Future<void> _loadProfessionSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load profession settings - using same keys as WeekView
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
      
      print('Year View: Loaded profession settings from SharedPreferences');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Year View: Error loading profession settings: $e');
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
      print('Year View: Error loading custom professions: $e');
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
    final year = 2025;
    final jan4 = DateTime(year, 1, 4);
    final firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final weekStart = firstMonday.add(Duration(days: (weekNumber - 1) * 7));
    final tuesdayStart = weekStart.add(const Duration(days: 1));
    return List.generate(7, (index) => tuesdayStart.add(Duration(days: index)));
  }

  // 🔥 EXACT SAME CATEGORY COLORS AS WEEK VIEW!
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
            width: 50, // Reduced from 75 for more compact design
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
    final screenWidth = MediaQuery.of(context).size.width;
    final professionColumnWidth = 50.0;
    final containerMargins = 4.0; // 2px left + 2px right from container margins
    final borderWidth = 2.0; // 1px left + 1px right from container borders
    final availableGridWidth = screenWidth - professionColumnWidth - containerMargins - borderWidth;
    final dayWidth = availableGridWidth / 7; // Precise calculation
    
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
                Container(width: 50), // Reduced from 75 to match header
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
                  width: 50, // Reduced from 75 for more compact design
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
                    onPressed: () => widget.onViewChanged?.call('VIIKKO'),
                    icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white), // Smaller icon
                    padding: EdgeInsets.zero,
                    tooltip: 'Back to Week View',
                  ),
                  const SizedBox(width: 8), // Reduced spacing
                  Expanded(
                      child: Text(
                      '2025 - VIIKKO $_currentWeek', // New format
                        style: const TextStyle(
                        fontSize: 14, // Reduced from 18
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
                      setState(() {
                        _currentWeek = currentWeek;
                      });
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
                    tooltip: 'Go to Current Week',
                  ),

                  const SizedBox(width: 8), // Reduced spacing
                  
                  // Fullscreen button
                  IconButton(
                    onPressed: _toggleFullscreen,
                    icon: const Icon(Icons.fullscreen, size: 16, color: Colors.white),
                    padding: EdgeInsets.zero,
                    tooltip: 'Fullscreen',
                  ),
                  
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
                child: PageView.builder(
                  controller: _pageController,
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
          ],
        ),
      ),
    );
  }
} 