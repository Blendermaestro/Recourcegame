import 'package:flutter/material.dart';
import 'package:calendar_app/views/week_view/week_view.dart';
import 'package:calendar_app/views/employee_settings/employee_settings_view.dart';
import 'package:calendar_app/views/auth/auth_view.dart';
import 'package:calendar_app/services/auth_service.dart';
import 'package:supabase_flutter/supabase_config.dart';
import 'package:calendar_app/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  runApp(const CalendarApp());
}

class CalendarApp extends StatefulWidget {
  const CalendarApp({super.key});

  @override
  State<CalendarApp> createState() => _CalendarAppState();
}

class _CalendarAppState extends State<CalendarApp> {
  String _currentView = 'VIIKKO';
  int _currentWeek = 1;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Työaikakalenteri',
      theme: _buildTheme(),
      home: AuthWrapper(
        child: _MainView(
          currentView: _currentView,
          currentWeek: _currentWeek,
          onViewChanged: (view) => setState(() => _currentView = view),
          onWeekChanged: (week) => setState(() => _currentWeek = week),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData.light().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5C6B73), // Payne's gray from your palette
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFE0FBFC), // Light cyan background
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF253237), // Gunmetal - darkest from palette
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFFE0FBFC), // Light cyan to match scaffold
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    AuthService.authStateChanges.listen((AuthState data) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show auth view if not signed in, otherwise show main app
    if (AuthService.isSignedIn) {
      return widget.child;
    } else {
      return const AuthView();
    }
  }
}

class _MainView extends StatelessWidget {
  final String currentView;
  final int currentWeek;
  final Function(String) onViewChanged;
  final Function(int) onWeekChanged;

  const _MainView({
    required this.currentView,
    required this.currentWeek,
    required this.onViewChanged,
    required this.onWeekChanged,
  });

  void _navigateToWeek(int weekNumber) {
    onViewChanged('VIIKKO');
    onWeekChanged(weekNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: _buildCurrentView(),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (currentView) {
      case 'VIIKKO':
        return WeekView(
          weekNumber: currentWeek,
          onWeekChanged: onWeekChanged,
          onViewChanged: onViewChanged, // Add this callback
        );
      case 'VUOSI':
        return _YearView(
          currentWeek: currentWeek,
          onWeekSelected: _navigateToWeek,
        );
      default:
        return const Center(child: Text('Tuntematon näkymä'));
    }
  }
}

class _YearView extends StatelessWidget {
  final int currentWeek;
  final Function(int) onWeekSelected;
  
  const _YearView({
    required this.currentWeek,
    required this.onWeekSelected,
  });
  
  String _getShiftDisplayForWeek(int weekNumber) {
    final cyclePosition = (weekNumber - 1) % 4;
    switch (cyclePosition) {
      case 0: return 'A/B'; // Week 1: A=day, B=night
      case 1: return 'C/D'; // Week 2: C=day, D=night  
      case 2: return 'B/A'; // Week 3: B=day, A=night
      case 3: return 'D/C'; // Week 4: D=day, C=night
      default: return 'A/B';
    }
  }
  
  Color _getWeekColor(int weekNumber) {
    final cyclePosition = (weekNumber - 1) % 4;
    switch (cyclePosition) {
      case 0: return const Color(0xFFE0FBFC); // Light cyan
      case 1: return const Color(0xFFC2DFE3); // Light blue
      case 2: return const Color(0xFF9DB4C0); // Cadet gray
      case 3: return const Color(0xFF5C6B73); // Payne's gray
      default: return const Color(0xFFE0FBFC);
    }
  }
  
  Color _getTextColor(int weekNumber) {
    final cyclePosition = (weekNumber - 1) % 4;
    switch (cyclePosition) {
      case 0:
      case 1:
        return const Color(0xFF253237); // Dark text on light backgrounds
      case 2:
      case 3:
        return Colors.white; // White text on darker backgrounds
      default:
        return const Color(0xFF253237);
    }
  }
  
  DateTime _getDateForWeek(int weekNumber) {
    // Calculate first day of the week based on ISO week numbering for 2025
    final jan4_2025 = DateTime(2025, 1, 4);
    final firstMonday = jan4_2025.subtract(Duration(days: jan4_2025.weekday - 1));
    final weekStart = firstMonday.add(Duration(days: (weekNumber - 1) * 7));
    return weekStart.add(const Duration(days: 1)); // Start from Tuesday
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Year header
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF253237), // Gunmetal
              border: Border.all(color: const Color(0xFF9DB4C0), width: 1),
            ),
            child: const Center(
              child: Text(
                '2025 - All Weeks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          // Week grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // 4 weeks per row to show the 4-week cycle
                childAspectRatio: 1.2,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 52,
              itemBuilder: (context, index) {
                final weekNumber = index + 1;
                final isCurrentWeek = weekNumber == currentWeek;
                final weekDate = _getDateForWeek(weekNumber);
                
                return GestureDetector(
                  onTap: () => onWeekSelected(weekNumber),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getWeekColor(weekNumber),
                      border: Border.all(
                        color: isCurrentWeek 
                            ? const Color(0xFF253237) 
                            : const Color(0xFF9DB4C0),
                        width: isCurrentWeek ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Week $weekNumber',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getTextColor(weekNumber),
                            ),
                          ),
                          Text(
                            _getShiftDisplayForWeek(weekNumber),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getTextColor(weekNumber),
                            ),
                          ),
                          Text(
                            '${weekDate.day}.${weekDate.month}',
                            style: TextStyle(
                              fontSize: 10,
                              color: _getTextColor(weekNumber).withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}