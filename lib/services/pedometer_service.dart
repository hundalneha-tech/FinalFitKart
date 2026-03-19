// lib/services/pedometer_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class PedometerService {
  static final PedometerService _instance = PedometerService._();
  factory PedometerService() => _instance;
  PedometerService._();

  final _stepsController = StreamController<int>.broadcast();
  Stream<int> get stepsStream => _stepsController.stream;

  StreamSubscription<StepCount>? _stepSub;
  int _baseSteps = 0;
  int _todaySteps = 0;
  int get todaySteps => _todaySteps;

  Future<bool> init() async {
    // Skip on web — pedometer not supported
    if (kIsWeb) {
      _startMockStepsForWeb();
      return true;
    }

    final activityStatus = await Permission.activityRecognition.request();
    if (!activityStatus.isGranted) return false;

    // Try Health package (health v10+ uses Health() not HealthFactory())
    try {
      final health = Health();
      final types  = [HealthDataType.STEPS];
      final granted = await health.requestAuthorization(types);
      if (granted) {
        await _syncFromHealth(health);
        Timer.periodic(const Duration(seconds: 60), (_) async {
          await _syncFromHealth(health);
        });
        return true;
      }
    } catch (e) {
      debugPrint('Health package failed: $e');
    }

    // Fall back to raw pedometer
    _subscribePedometer();
    return true;
  }

  Future<void> _syncFromHealth(Health health) async {
    final now     = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final data = await health.getHealthDataFromTypes(
        startTime: midnight, endTime: now, types: [HealthDataType.STEPS]);
      int total = 0;
      for (final d in data) {
        total += (d.value as NumericHealthValue).numericValue.toInt();
      }
      _todaySteps = total;
      _stepsController.add(total);
    } catch (e) {
      debugPrint('Health sync error: $e');
    }
  }

  void _subscribePedometer() {
    _stepSub = Pedometer.stepCountStream.listen(
      (event) {
        if (_baseSteps == 0) _baseSteps = event.steps;
        _todaySteps = event.steps - _baseSteps;
        _stepsController.add(_todaySteps);
      },
      onError: (e) => debugPrint('Pedometer error: $e'),
    );
  }

  // Mock steps for web browser testing
  void _startMockStepsForWeb() {
    int mockSteps = 0;
    Timer.periodic(const Duration(seconds: 5), (_) {
      mockSteps += 10;
      _todaySteps = mockSteps;
      _stepsController.add(mockSteps);
    });
  }

  void dispose() {
    _stepSub?.cancel();
    _stepsController.close();
  }
}

double stepsToCoinEarned(int steps) => steps * 0.01;
double coinsToInr(double coins) => coins * 0.33;
