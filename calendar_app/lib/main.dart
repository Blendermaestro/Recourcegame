import 'package:flutter/material.dart';
import 'package:calendar_app/views/week_view/week_view.dart';
import 'package:calendar_app/views/year_view/year_view.dart';
import 'package:calendar_app/views/auth/auth_view.dart';
import 'package:calendar_app/services/auth_service.dart';
import 'package:calendar_app/services/supabase_config.dart';
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
        return YearView(
          initialWeek: currentWeek,
          onWeekChanged: onWeekChanged,
          onViewChanged: onViewChanged,
        );
      default:
        return const Center(child: Text('Tuntematon näkymä'));
    }
  }
}

