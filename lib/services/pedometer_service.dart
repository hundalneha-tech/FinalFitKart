// lib/services/pedometer_service.dart
// Multi-source step tracking with motion sensor + GPS validation
// Sources: Google Fit / Health Connect (Android), Apple Health (iOS)
// Validation: Accelerometer + Gyroscope + GPS distance correlation

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Data models ───────────────────────────────────────────────────────────

class MotionSample {
  final DateTime timestamp;
  final double accelX, accelY, accelZ;    // m/s²
  final double gyroX, gyroY, gyroZ;       // rad/s
  final double accelMagnitude;            // √(x²+y²+z²)
  final bool isMoving;                    // true if magnitude > threshold

  MotionSample({
    required this.timestamp,
    required this.accelX, required this.accelY, required this.accelZ,
    required this.gyroX,  required this.gyroY,  required this.gyroZ,
  })  : accelMagnitude = sqrt(accelX*accelX + accelY*accelY + accelZ*accelZ),
        isMoving = sqrt(accelX*accelX + accelY*accelY + accelZ*accelZ) > 1.5;
}

class GpsSample {
  final DateTime timestamp;
  final double lat, lng, accuracy;
  final double? speed; // m/s

  GpsSample({required this.timestamp, required this.lat, required this.lng,
    required this.accuracy, this.speed});
}

class SessionData {
  final int steps;
  final double distanceKm;
  final double avgAccelMagnitude;
  final double motionConsistency;   // 0–1: % of time sensor shows movement
  final List<GpsSample> gpsSamples;
  final DateTime startTime;
  final DateTime endTime;
  final String dataSource; // 'health_connect' | 'apple_health' | 'pedometer'

  SessionData({
    required this.steps, required this.distanceKm,
    required this.avgAccelMagnitude, required this.motionConsistency,
    required this.gpsSamples, required this.startTime,
    required this.endTime, required this.dataSource,
  });

  // Key anti-cheat metric: expected km range for given steps
  // Average step = 0.762m → 10,000 steps ≈ 7.62 km
  // Flag if distance is wildly inconsistent with steps
  double get expectedMinKm => steps * 0.0005;   // ~0.5m/step min
  double get expectedMaxKm => steps * 0.001;     // ~1.0m/step max
  bool get distanceStepsMismatch {
    if (distanceKm == 0 && steps > 5000) return true; // 5k+ steps, 0 distance
    if (distanceKm > 0 && steps > 0) {
      return distanceKm < expectedMinKm * 0.5 || distanceKm > expectedMaxKm * 2;
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'distance_km': distanceKm,
    'avg_accel_magnitude': avgAccelMagnitude,
    'motion_consistency': motionConsistency,
    'gps_point_count': gpsSamples.length,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'duration_minutes': endTime.difference(startTime).inMinutes,
    'data_source': dataSource,
    'distance_steps_mismatch': distanceStepsMismatch,
    'gps_samples': gpsSamples.map((g) => {
      'lat': g.lat, 'lng': g.lng, 'accuracy': g.accuracy,
      'speed': g.speed, 'ts': g.timestamp.toIso8601String(),
    }).toList(),
  };
}

// ─── PedometerService ───────────────────────────────────────────────────────

class PedometerService {
  static final PedometerService _instance = PedometerService._();
  factory PedometerService() => _instance;
  PedometerService._();

  // Streams
  final _stepsController   = StreamController<int>.broadcast();
  final _motionController  = StreamController<MotionSample>.broadcast();
  final _gpsController     = StreamController<GpsSample>.broadcast();

  Stream<int>          get stepsStream  => _stepsController.stream;
  Stream<MotionSample> get motionStream => _motionController.stream;
  Stream<GpsSample>    get gpsStream    => _gpsController.stream;

  // State
  int _todaySteps     = 0;
  int _baseSteps      = 0;
  double _distanceKm  = 0;
  String _dataSource  = 'pedometer';

  // Motion sensor buffers
  final List<MotionSample> _motionBuffer = [];
  AccelerometerEvent? _lastAccel;
  GyroscopeEvent?     _lastGyro;

  // GPS
  final List<GpsSample> _gpsSamples = [];
  Position? _lastPosition;
  StreamSubscription? _gpsStream;

  // Subscriptions
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _syncTimer;
  Timer? _batchTimer;

  int  get todaySteps  => _todaySteps;
  double get distanceKm => _distanceKm;

  // ─── Init ───────────────────────────────────────────────────────────────

  Future<bool> init() async {
    if (kIsWeb) { _startMockWeb(); return true; }

    await _requestPermissions();
    await _initHealthSource();
    _initMotionSensors();
    await _initGps();
    _startBatchUpload();
    return true;
  }

  Future<void> _requestPermissions() async {
    await Permission.activityRecognition.request();
    await Permission.locationWhenInUse.request();
    await Permission.sensors.request();
  }

  // ─── Health: Google Fit / Health Connect (Android) + Apple Health (iOS) ─

  Future<void> _initHealthSource() async {
    try {
      final health = Health();
      final types = [
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_WALKING_RUNNING,
      ];

      final granted = await health.requestAuthorization(types);
      if (!granted) {
        debugPrint('Health permission denied — falling back to pedometer');
        _subscribePedometer();
        return;
      }

      // Determine source name for anti-cheat logging
      _dataSource = defaultTargetPlatform == TargetPlatform.iOS
          ? 'apple_health'
          : 'health_connect';

      await _syncFromHealth(health);

      // Sync every 60 seconds
      _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
        await _syncFromHealth(health);
      });

      debugPrint('Health source: $_dataSource');
    } catch (e) {
      debugPrint('Health init failed: $e — using pedometer');
      _subscribePedometer();
    }
  }

  Future<void> _syncFromHealth(Health health) async {
    final now      = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      // Steps
      final stepData = await health.getHealthDataFromTypes(
        startTime: midnight, endTime: now, types: [HealthDataType.STEPS]);
      int total = 0;
      for (final d in stepData) {
        total += (d.value as NumericHealthValue).numericValue.toInt();
      }
      _todaySteps = total;
      _stepsController.add(total);

      // Distance
      final distData = await health.getHealthDataFromTypes(
        startTime: midnight, endTime: now,
        types: [HealthDataType.DISTANCE_WALKING_RUNNING]);
      double totalDist = 0;
      for (final d in distData) {
        totalDist += (d.value as NumericHealthValue).numericValue;
      }
      _distanceKm = totalDist / 1000; // metres → km
    } catch (e) {
      debugPrint('Health sync error: $e');
    }
  }

  // ─── Fallback: raw pedometer sensor ─────────────────────────────────────

  void _subscribePedometer() {
    _dataSource = 'pedometer';
    _stepSub = Pedometer.stepCountStream.listen(
      (event) {
        if (_baseSteps == 0) _baseSteps = event.steps;
        _todaySteps = event.steps - _baseSteps;
        _stepsController.add(_todaySteps);
      },
      onError: (e) => debugPrint('Pedometer error: $e'),
    );
  }

  // ─── Motion sensors: Accelerometer + Gyroscope ──────────────────────────

  void _initMotionSensors() {
    // Sample accelerometer at ~50Hz
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen((event) {
      _lastAccel = event;
      _emitMotionSample();
    }, onError: (e) => debugPrint('Accel error: $e'));

    // Sample gyroscope at ~50Hz
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen((event) {
      _lastGyro = event;
    }, onError: (e) => debugPrint('Gyro error: $e'));
  }

  void _emitMotionSample() {
    if (_lastAccel == null) return;
    final sample = MotionSample(
      timestamp: DateTime.now(),
      accelX: _lastAccel!.x, accelY: _lastAccel!.y, accelZ: _lastAccel!.z,
      gyroX:  _lastGyro?.x ?? 0,
      gyroY:  _lastGyro?.y ?? 0,
      gyroZ:  _lastGyro?.z ?? 0,
    );
    _motionBuffer.add(sample);
    // Keep only last 3,000 samples (~60s at 50Hz)
    if (_motionBuffer.length > 3000) _motionBuffer.removeAt(0);
    _motionController.add(sample);
  }

  // ─── GPS: distance correlation ───────────────────────────────────────────

  Future<void> _initGps() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.balanced,
      distanceFilter: 20, // emit every 20m of movement
    );

    _gpsStream = Geolocator.getPositionStream(locationSettings: settings)
      .listen((pos) {
        final sample = GpsSample(
          timestamp: DateTime.now(),
          lat: pos.latitude, lng: pos.longitude,
          accuracy: pos.accuracy, speed: pos.speed,
        );

        // Accumulate distance
        if (_lastPosition != null) {
          final dist = Geolocator.distanceBetween(
            _lastPosition!.latitude, _lastPosition!.longitude,
            pos.latitude, pos.longitude,
          );
          // Sanity check: ignore jumps > 200m (teleport / GPS error)
          if (dist < 200) _distanceKm += dist / 1000;
        }

        _lastPosition = pos;
        _gpsSamples.add(sample);
        // Keep last 200 GPS points
        if (_gpsSamples.length > 200) _gpsSamples.removeAt(0);
        _gpsController.add(sample);
      },
      onError: (e) => debugPrint('GPS error: $e'),
    );
  }

  // ─── Batch upload to Supabase (with anti-cheat data) ────────────────────

  void _startBatchUpload() {
    // Upload a session snapshot every 5 minutes
    _batchTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _uploadBatch();
    });
  }

  Future<void> _uploadBatch() async {
    if (_todaySteps == 0) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final now   = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);

      // Compute motion consistency — % of last 500 samples showing movement
      final recentMotion = _motionBuffer.length > 500
          ? _motionBuffer.sublist(_motionBuffer.length - 500)
          : _motionBuffer;
      final movingCount = recentMotion.where((s) => s.isMoving).length;
      final motionConsistency = recentMotion.isEmpty
          ? 0.0 : movingCount / recentMotion.length;

      // Average accelerometer magnitude
      final avgMagnitude = recentMotion.isEmpty ? 0.0
          : recentMotion.map((s) => s.accelMagnitude)
              .reduce((a, b) => a + b) / recentMotion.length;

      final session = SessionData(
        steps: _todaySteps,
        distanceKm: _distanceKm,
        avgAccelMagnitude: avgMagnitude,
        motionConsistency: motionConsistency,
        gpsSamples: List.from(_gpsSamples),
        startTime: start,
        endTime: now,
        dataSource: _dataSource,
      );

      // Upload step batch
      await Supabase.instance.client.from('step_batches').upsert({
        'user_id': uid,
        'date': start.toIso8601String().split('T')[0],
        'step_count': _todaySteps,
        'distance_km': _distanceKm,
        'data_source': _dataSource,
        'motion_consistency': motionConsistency,
        'avg_accel_magnitude': avgMagnitude,
        'gps_point_count': _gpsSamples.length,
        'distance_steps_mismatch': session.distanceStepsMismatch,
        'session_metadata': session.toJson(),
        'updated_at': now.toIso8601String(),
      }, onConflict: 'user_id,date');

      // Trigger server-side anti-cheat validation
      await Supabase.instance.client.functions.invoke('validate-steps', body: {
        'user_id': uid,
        'steps': _todaySteps,
        'distance_km': _distanceKm,
        'motion_consistency': motionConsistency,
        'avg_accel_magnitude': avgMagnitude,
        'gps_point_count': _gpsSamples.length,
        'distance_steps_mismatch': session.distanceStepsMismatch,
        'data_source': _dataSource,
        'date': start.toIso8601String().split('T')[0],
      });

      debugPrint('Batch uploaded: $_todaySteps steps, ${_distanceKm.toStringAsFixed(2)}km, '
          'motion: ${(motionConsistency * 100).toStringAsFixed(0)}%');
    } catch (e) {
      debugPrint('Batch upload error: $e');
    }
  }

  // ─── Web mock ────────────────────────────────────────────────────────────

  void _startMockWeb() {
    int mockSteps = 0;
    double mockDist = 0;
    Timer.periodic(const Duration(seconds: 5), (_) {
      mockSteps += 10;
      mockDist += 0.0076; // 7.6m per 10 steps
      _todaySteps = mockSteps;
      _distanceKm = mockDist;
      _stepsController.add(mockSteps);
    });
  }

  // ─── Dispose ─────────────────────────────────────────────────────────────

  void dispose() {
    _stepSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _gpsStream?.cancel();
    _syncTimer?.cancel();
    _batchTimer?.cancel();
    _stepsController.close();
    _motionController.close();
    _gpsController.close();
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

double stepsToCoinEarned(int steps) => steps * 0.001; // 1,000 steps = 1 FKC
double coinsToInr(double coins) => coins * 0.25;       // 1 FKC = ₹0.25
