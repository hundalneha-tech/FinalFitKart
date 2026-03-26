// lib/services/pedometer_service.dart
// Step tracking priority:
//   1. Google Fit (FITNESS API) — primary on Android
//   2. Apple Health — primary on iOS
//   3. Raw Pedometer sensor — fallback on both
// Motion: Accelerometer + Gyroscope via sensors_plus
// GPS: Geolocator for distance correlation

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Motion sample ────────────────────────────────────────────────────────────

class MotionSample {
  final DateTime timestamp;
  final double accelX, accelY, accelZ;
  final double gyroX,  gyroY,  gyroZ;
  final double accelMagnitude;
  final bool   isMoving;

  MotionSample({
    required this.timestamp,
    required this.accelX, required this.accelY, required this.accelZ,
    required this.gyroX,  required this.gyroY,  required this.gyroZ,
  }) : accelMagnitude = sqrt(accelX*accelX + accelY*accelY + accelZ*accelZ),
       isMoving = sqrt(accelX*accelX + accelY*accelY + accelZ*accelZ) > 1.5;
}

// ─── GPS sample ───────────────────────────────────────────────────────────────

class GpsSample {
  final DateTime timestamp;
  final double lat, lng, accuracy;
  final double? speed;
  GpsSample({required this.timestamp, required this.lat,
    required this.lng, required this.accuracy, this.speed});
}

// ─── PedometerService ─────────────────────────────────────────────────────────

class PedometerService {
  static final PedometerService _i = PedometerService._();
  factory PedometerService() => _i;
  PedometerService._();

  // Public streams
  final _stepsCtrl  = StreamController<int>.broadcast();
  final _motionCtrl = StreamController<MotionSample>.broadcast();

  Stream<int>          get stepsStream  => _stepsCtrl.stream;
  Stream<MotionSample> get motionStream => _motionCtrl.stream;

  // State
  int    _todaySteps = 0;
  int    _baseSteps  = 0;
  double _distanceKm = 0;
  String _dataSource = 'pedometer';

  int    get todaySteps  => _todaySteps;
  double get distanceKm  => _distanceKm;
  String get dataSource  => _dataSource;
  List<GpsSample> get routePoints => List.unmodifiable(_gpsSamples);
  Position? get lastPosition => _lastPos;

  // Buffers
  final List<MotionSample> _motionBuf = [];
  final List<GpsSample>    _gpsSamples = [];
  AccelerometerEvent? _lastAccel;
  GyroscopeEvent?     _lastGyro;
  Position?           _lastPos;

  // Subscriptions
  StreamSubscription<StepCount>?          _stepSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>?     _gyroSub;
  StreamSubscription<Position>?           _gpsSub;
  Timer? _syncTimer;
  Timer? _batchTimer;

  bool _initialized = false;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<bool> init() async {
    if (_initialized) return true;
    _initialized = true;

    if (kIsWeb) { _startWebMock(); return true; }

    await _requestPermissions();

    // Try Google Fit / Apple Health first, fall back to raw pedometer
    final healthConnected = await _initGoogleFit();
    if (!healthConnected) {
      debugPrint('Google Fit unavailable — using raw pedometer');
      _startRawPedometer();
    }

    _initMotionSensors();
    await _initGps();
    _startBatchUpload();
    return true;
  }

  Future<void> _requestPermissions() async {
    await Permission.activityRecognition.request();
    await Permission.locationWhenInUse.request();
  }

  // ── Google Fit (Android) / Apple Health (iOS) ─────────────────────────────

  Future<bool> _initGoogleFit() async {
    try {
      final health = Health();

final types = [
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_WALKING_RUNNING,
      ];

      final granted = await health.requestAuthorization(types);
      if (!granted) {
        debugPrint('Google Fit authorization denied');
        return false;
      }

      _dataSource = defaultTargetPlatform == TargetPlatform.iOS
          ? 'apple_health' : 'google_fit';

      debugPrint('Connected to: $_dataSource');

      // Initial sync
      await _syncFromFit(health);

      // Sync every 30 seconds during active session
      _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        await _syncFromFit(health);
      });

      return true;
    } catch (e) {
      debugPrint('Google Fit init error: $e');
      return false;
    }
  }

  Future<void> _syncFromFit(Health health) async {
    final now     = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      // Steps
      final stepData = await health.getHealthDataFromTypes(
        startTime: midnight, endTime: now,
        types: [HealthDataType.STEPS]);

      int total = 0;
      for (final d in stepData) {
        if (d.value is NumericHealthValue) {
          total += (d.value as NumericHealthValue).numericValue.toInt();
        }
      }

      if (total > 0) {
        _todaySteps = total;
        _stepsCtrl.add(total);
        debugPrint('Google Fit steps: $total');
      }

      // Distance
      final distData = await health.getHealthDataFromTypes(
        startTime: midnight, endTime: now,
        types: [HealthDataType.DISTANCE_WALKING_RUNNING]);

      double dist = 0;
      for (final d in distData) {
        if (d.value is NumericHealthValue) {
          dist += (d.value as NumericHealthValue).numericValue;
        }
      }
      if (dist > 0) _distanceKm = dist / 1000;

    } catch (e) {
      debugPrint('Google Fit sync error: $e');
    }
  }

  // ── Raw pedometer fallback ────────────────────────────────────────────────

  void _startRawPedometer() {
    _dataSource = 'pedometer';
    _stepSub = Pedometer.stepCountStream.listen(
      (event) {
        if (_baseSteps == 0) _baseSteps = event.steps;
        _todaySteps = event.steps - _baseSteps;
        _stepsCtrl.add(_todaySteps);
      },
      onError: (e) => debugPrint('Pedometer error: $e'),
    );
  }

  // ── Accelerometer + Gyroscope ─────────────────────────────────────────────

  void _initMotionSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((e) {
      _lastAccel = e;
      _emitMotion();
    }, onError: (e) => debugPrint('Accel error: $e'));

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((e) {
      _lastGyro = e;
    }, onError: (e) => debugPrint('Gyro error: $e'));
  }

  void _emitMotion() {
    if (_lastAccel == null) return;
    final s = MotionSample(
      timestamp: DateTime.now(),
      accelX: _lastAccel!.x, accelY: _lastAccel!.y, accelZ: _lastAccel!.z,
      gyroX: _lastGyro?.x ?? 0, gyroY: _lastGyro?.y ?? 0, gyroZ: _lastGyro?.z ?? 0,
    );
    _motionBuf.add(s);
    if (_motionBuf.length > 3000) _motionBuf.removeAt(0);
    _motionCtrl.add(s);
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _initGps() async {
    try {
      final ok = await Geolocator.isLocationServiceEnabled();
      if (!ok) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 20,
        ),
      ).listen((pos) {
        if (_lastPos != null) {
          final d = Geolocator.distanceBetween(
            _lastPos!.latitude, _lastPos!.longitude,
            pos.latitude, pos.longitude);
          if (d < 200) _distanceKm += d / 1000;
        }
        _lastPos = pos;
        _gpsSamples.add(GpsSample(
          timestamp: DateTime.now(),
          lat: pos.latitude, lng: pos.longitude,
          accuracy: pos.accuracy, speed: pos.speed));
        if (_gpsSamples.length > 200) _gpsSamples.removeAt(0);
      });
    } catch (e) {
      debugPrint('GPS init error: $e');
    }
  }

  // ── Batch upload ──────────────────────────────────────────────────────────

  void _startBatchUpload() {
    _batchTimer = Timer.periodic(const Duration(minutes: 5), (_) => _upload());
  }

  Future<void> _upload() async {
    if (_todaySteps == 0) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final now     = DateTime.now();
      final today   = DateTime(now.year, now.month, now.day);
      final recent  = _motionBuf.length > 500 ? _motionBuf.sublist(_motionBuf.length - 500) : _motionBuf;
      final moving  = recent.where((s) => s.isMoving).length;
      final motionPct   = recent.isEmpty ? 0.0 : moving / recent.length;
      final avgAccel    = recent.isEmpty ? 0.0 : recent.map((s) => s.accelMagnitude).reduce((a,b) => a+b) / recent.length;
      final mismatch    = _todaySteps > 5000 && _distanceKm == 0;

      await Supabase.instance.client.from('step_batches').upsert({
        'user_id':                  uid,
        'session_id':               uid, // use uid as daily session id
        'device_id':                _dataSource,
        'timestamp_start':          today.toIso8601String(),
        'timestamp_end':            now.toIso8601String(),
        'step_count':               _todaySteps,
        'distance_km':              _distanceKm,
        'data_source':              _dataSource,
        'motion_consistency':       motionPct,
        'avg_accel_magnitude':      avgAccel,
        'gps_point_count':          _gpsSamples.length,
        'distance_steps_mismatch':  mismatch,
        'updated_at':               now.toIso8601String(),
      }, onConflict: 'user_id,session_id');

      // Trigger anti-cheat validation
      await Supabase.instance.client.functions.invoke('validate-steps', body: {
        'user_id':                  uid,
        'steps':                    _todaySteps,
        'distance_km':              _distanceKm,
        'motion_consistency':       motionPct,
        'avg_accel_magnitude':      avgAccel,
        'gps_point_count':          _gpsSamples.length,
        'distance_steps_mismatch':  mismatch,
        'data_source':              _dataSource,
        'date':                     today.toIso8601String().split('T')[0],
      });
    } catch (e) {
      debugPrint('Batch upload error: $e');
    }
  }

  // ── Web mock ──────────────────────────────────────────────────────────────

  void _startWebMock() {
    int mock = 0; double dist = 0;
    Timer.periodic(const Duration(seconds: 5), (_) {
      mock += 10; dist += 0.0076;
      _todaySteps = mock; _distanceKm = dist;
      _stepsCtrl.add(mock);
    });
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  void dispose() {
    _stepSub?.cancel(); _accelSub?.cancel();
    _gyroSub?.cancel(); _gpsSub?.cancel();
    _syncTimer?.cancel(); _batchTimer?.cancel();
    _stepsCtrl.close(); _motionCtrl.close();
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

double stepsToCoinEarned(int steps) => steps * 0.001; // 1,000 steps = 1 FKC
double coinsToInr(double coins) => coins * 0.25;       // 1 FKC = ₹0.25
