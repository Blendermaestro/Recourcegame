import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calendar_app/models/user_tier.dart';
import 'package:calendar_app/services/supabase_config.dart';

class UserTierService {
  static final _supabase = SupabaseConfig.client;

  // Get current user's tier
  static Future<UserTier> getCurrentUserTier() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return UserTier.tier1; // Default to tier 1

      final response = await _supabase
          .from('user_profiles')
          .select('tier')
          .eq('id', user.id)
          .single();
      
      if (response['tier'] != null) {
        return UserTier.values.byName(response['tier']);
      }
    } catch (e) {
      print('Error getting user tier: $e');
    }
    
    return UserTier.tier1; // Default to tier 1 if not found
  }

  // Create or update user profile
  static Future<void> createUserProfile(String userId, String email, {UserTier tier = UserTier.tier1}) async {
    try {
      await _supabase.from('user_profiles').upsert({
        'id': userId,
        'email': email,
        'tier': tier.name,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('User profile created: $email with tier ${tier.displayName}');
    } catch (e) {
      print('Error creating user profile: $e');
      throw e;
    }
  }

  // Update user tier (admin function)
  static Future<void> updateUserTier(String userId, UserTier tier) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({'tier': tier.name})
          .eq('id', userId);
      print('User tier updated: $userId -> ${tier.displayName}');
    } catch (e) {
      print('Error updating user tier: $e');
      throw e;
    }
  }

  // Get user profile
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();
      
      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Get all users (admin function)
  static Future<List<UserProfile>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .order('created_at');
      
      return (response as List<dynamic>)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  // Set default tier for email domains (helper method)
  static UserTier getDefaultTierForEmail(String email) {
    // You can customize this logic based on email domains
    if (email.endsWith('@admin.com') || email.endsWith('@manager.com')) {
      return UserTier.tier1;
    }
    return UserTier.tier2; // Default new users to tier 2
  }
} 