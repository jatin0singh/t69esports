import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://ardyrrwjhgrpeiltgrdl.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFyZHlycndqaGdycGVpbHRncmRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcwNzQyOTQsImV4cCI6MjEwMjY1MDI5NH0.GGFCWzXMm9krqcQ1v8BvgQiAwwzHYyYTlNBPUuxfyvE';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
