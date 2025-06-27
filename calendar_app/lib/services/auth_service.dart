import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calendar_app/services/supabase_config.dart';

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
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
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
} 