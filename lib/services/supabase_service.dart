// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _i = SupabaseService._();
  factory SupabaseService() => _i;
  SupabaseService._();

  static Future<void> init() async {
    await Supabase.initialize(
      url:     const String.fromEnvironment('SUPABASE_URL',
               defaultValue: 'https://qtdlwbtfwteidjldpyvf.supabase.co'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
               defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0ZGx3YnRmd3RlaWRqbGRweXZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4MjA2NzcsImV4cCI6MjA4OTM5NjY3N30.yvUDAfZ_4aMOPvOOoqrbGZGWyd4upLu6P15sdwKxN4M'),
    );
  }

  User? get currentUser => Supabase.instance.client.auth.currentUser;
  String? get userId     => currentUser?.id;
  bool   get isLoggedIn  => currentUser != null;
  Stream<AuthState> get authStateChanges => Supabase.instance.client.auth.onAuthStateChange;
}
