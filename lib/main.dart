// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/supabase_service.dart';
import 'services/pedometer_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await SupabaseService.init();
  runApp(const ProviderScope(child: FitKartApp()));
}

class FitKartApp extends StatefulWidget {
  const FitKartApp({super.key});
  @override
  State<FitKartApp> createState() => _FitKartAppState();
}

class _FitKartAppState extends State<FitKartApp> {
  bool? _showMain; // null = loading

  @override
  void initState() {
    super.initState();
    _determineStartScreen();

    // Listen for sign-out only — sign-in is handled by _determineStartScreen
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) setState(() => _showMain = false);
      }
    });
  }

  Future<void> _determineStartScreen() async {
    // Small delay to let Supabase process OAuth ?code= from URL
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;

    debugPrint('isLoggedIn: \$isLoggedIn, onboardingDone: \$onboardingDone');

    if (mounted) {
      setState(() => _showMain = isLoggedIn && onboardingDone);
    }
  }

  Future<void> _onOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) setState(() => _showMain = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showMain == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF0F4FF),
          body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB))),
        ),
      );
    }
    return MaterialApp(
      title: 'FitKart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: _showMain!
        ? const _AppWithPedometer()
        : OnboardingScreen(
            onGetStarted: _onOnboardingComplete,
            onLogin: _onOnboardingComplete,
          ),
    );
  }
}

class _AppWithPedometer extends StatefulWidget {
  const _AppWithPedometer();
  @override
  State<_AppWithPedometer> createState() => _AppWithPedometerState();
}

class _AppWithPedometerState extends State<_AppWithPedometer> {
  @override
  void initState() {
    super.initState();
    PedometerService().init();
  }

  @override
  Widget build(BuildContext context) => const MainShell();
}
