import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calendar_app/services/supabase_config.dart';
import 'package:calendar_app/services/user_tier_service.dart';
import 'package:calendar_app/models/user_tier.dart';

class AuthService {
  static SupabaseClient get _client => SupabaseConfig.client;

  // Get current user
  static User? get currentUser => _client.auth.currentUser;
  
  // Check if user is signed in
  static bool get isSignedIn => currentUser != null;

  // Get user ID
  static String? get userId => currentUser?.id;

  // Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    
    // Create user profile with default tier based on email
    if (response.user != null) {
      final defaultTier = UserTierService.getDefaultTierForEmail(email);
      try {
        await UserTierService.createUserProfile(
          response.user!.id,
          email,
          tier: defaultTier,
        );
      } catch (e) {
        print('Warning: Could not create user profile: $e');
      }
    }
    
    return response;
  }

  // Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Listen to auth state changes
  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // Reset password
  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // Get user profile (email, etc.)
  static Map<String, dynamic>? get userProfile {
    final user = currentUser;
    if (user == null) return null;
    
    return {
      'id': user.id,
      'email': user.email,
      'created_at': user.createdAt,
    };
  }

  // Get current user tier
  static Future<UserTier> getCurrentUserTier() async {
    return await UserTierService.getCurrentUserTier();
  }

  // Check if current user has access to specific features
  static Future<bool> canAccessWeekView() async {
    final tier = await getCurrentUserTier();
    return tier.canAccessWeekView;
  }

  static Future<bool> canAccessEmployeeSettings() async {
    final tier = await getCurrentUserTier();
    return tier.canAccessEmployeeSettings;
  }

  static Future<bool> canEditData() async {
    final tier = await getCurrentUserTier();
    return tier.canEditData;
  }

  static Future<bool> canAccessYearView() async {
    final tier = await getCurrentUserTier();
    return tier.canAccessYearView;
  }
} 