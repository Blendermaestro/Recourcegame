import 'package:flutter/material.dart';
import 'package:calendar_app/views/week_view/week_view.dart';
import 'package:calendar_app/views/year_view/year_view.dart';
import 'package:calendar_app/views/auth/auth_view.dart';
import 'package:calendar_app/services/auth_service.dart';
import 'package:calendar_app/services/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase using the config
  await SupabaseConfig.initialize();

  runApp(const MyApp());
}

// Calculate current week of year
int getCurrentWeek() {
  final now = DateTime.now();
  final startOfYear = DateTime(now.year, 1, 1);
  final firstMonday = startOfYear.subtract(Duration(days: startOfYear.weekday - 1));
  final difference = now.difference(firstMonday).inDays;
  final currentWeek = (difference / 7).floor() + 1;
  return currentWeek.clamp(1, 52);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    AuthService.authStateChanges.listen((AuthState data) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isSignedIn) {
      return const AuthView();
    } else {
      return MainNavigationView(initialWeek: getCurrentWeek()); // Start from current week
    }
  }
}

class MainNavigationView extends StatefulWidget {
  final int initialWeek;
  
  const MainNavigationView({super.key, this.initialWeek = 1});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  String _currentView = 'VIIKKO';
  int _currentWeek = 1;

  @override
  void initState() {
    super.initState();
    _currentWeek = widget.initialWeek;
  }

  void _handleViewChange(String newView) {
    setState(() {
      _currentView = newView;
    });
  }

  void _handleWeekChange(int newWeek) {
    setState(() {
      _currentWeek = newWeek;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentView) {
      case 'VIIKKO':
        return WeekView(
          weekNumber: _currentWeek,
          onWeekChanged: _handleWeekChange,
          onViewChanged: _handleViewChange,
        );
      case 'VUOSI':
        return YearView(
          initialWeek: _currentWeek,
          onWeekChanged: _handleWeekChange,
          onViewChanged: _handleViewChange,
        );
      default:
        return WeekView(
          weekNumber: _currentWeek,
          onWeekChanged: _handleWeekChange,
          onViewChanged: _handleViewChange,
        );
    }
  }
}

