import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://vhcetpgqhmxhrnucdzqg.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoY2V0cGdxaG14aHJudWNkenFnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEwNTQyOTIsImV4cCI6MjA2NjYzMDI5Mn0.WBuTkiBjK8vhoJ5B84L0QtFrwAtHjXkDh5One0b-icI';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: false, // Set to true for debugging
    );
  }
} 