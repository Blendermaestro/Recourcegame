import 'package:flutter/material.dart';
import 'package:calendar_app/views/week_view/week_view.dart';
import 'package:calendar_app/views/year_view/year_view.dart';
import 'package:calendar_app/views/auth/auth_view.dart';
import 'package:calendar_app/services/auth_service.dart';
import 'package:calendar_app/services/supabase_config.dart';
import 'package:calendar_app/services/shared_assignment_data.dart';
import 'package:calendar_app/models/user_tier.dart';
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
  UserTier _userTier = UserTier.tier1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentWeek = widget.initialWeek;
    _loadUserTier();
  }

  Future<void> _loadUserTier() async {
    try {
      final tier = await AuthService.getCurrentUserTier();
      setState(() {
        _userTier = tier;
        _isLoading = false;
        
        // If user is Tier 2, force them to year view
        if (tier == UserTier.tier2) {
          _currentView = 'VUOSI';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _userTier = UserTier.tier1; // Default to tier 1 on error
      });
    }
  }

  void _handleViewChange(String newView) {
    // Prevent Tier 2 users from accessing week view
    if (_userTier == UserTier.tier2 && newView == 'VIIKKO') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access denied: Tier 2 users can only access the yearly view'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _currentView = newView;
    });
    
    // 🔥 FORCE YEAR VIEW REFRESH - Ensure it shows current data when switching to it
    if (newView == 'VUOSI') {
      // Trigger a refresh after the view has been built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SharedAssignmentData.forceRefresh();
      });
    }
  }

  void _handleWeekChange(int newWeek) {
    setState(() {
      _currentWeek = newWeek;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking user tier
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF253237),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Loading user permissions...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show view based on current selection and user tier
    switch (_currentView) {
      case 'VIIKKO':
        if (_userTier.canAccessWeekView) {
          return WeekView(
            weekNumber: _currentWeek,
            onWeekChanged: _handleWeekChange,
            onViewChanged: _handleViewChange,
          );
        } else {
          // Fallback to year view for restricted users
          return YearView(
            initialWeek: _currentWeek,
            onWeekChanged: _handleWeekChange,
            onViewChanged: _handleViewChange,
          );
        }
      case 'VUOSI':
        return YearView(
          initialWeek: _currentWeek,
          onWeekChanged: _handleWeekChange,
          onViewChanged: _handleViewChange,
        );
      default:
        if (_userTier.canAccessWeekView) {
          return WeekView(
            weekNumber: _currentWeek,
            onWeekChanged: _handleWeekChange,
            onViewChanged: _handleViewChange,
          );
        } else {
          return YearView(
            initialWeek: _currentWeek,
            onWeekChanged: _handleWeekChange,
            onViewChanged: _handleViewChange,
          );
        }
    }
  }
}

