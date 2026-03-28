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
import 'package:flutter/services.dart';
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

  static const _healthChannel = MethodChannel('com.fitkart.app/health_connect');

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

  // ── Battery: pause heavy sensors when app goes to background ─────────────
  void pauseHeavySensors() {
    _accelSub?.pause();
    _gyroSub?.pause();
    _gpsSub?.pause();
  }

  void resumeHeavySensors() {
    _accelSub?.resume();
    _gyroSub?.resume();
    _gpsSub?.resume();
  }

  // Stop GPS entirely when not in a workout session (called by session manager)
  void stopGps() {
    _gpsSub?.cancel();
    _gpsSub = null;
  }

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
  bool _healthConnected = false;
  bool get isHealthConnected => _healthConnected;


  // ── Request Health Connect permissions via native Android SDK ────────────
  // Uses MethodChannel → MainActivity.kt → PermissionController
  // This is the CORRECT way — triggers the real Health Connect permission screen
  Future<bool> requestHealthConnectPermissions() async {
    if (kIsWeb) return false;
    try {
      // First check if already granted
      final alreadyGranted = await _healthChannel.invokeMethod<bool>('checkPermissions') ?? false;
      if (alreadyGranted) {
        _healthConnected = true;
        debugPrint('Health Connect: already granted ✅');
        _initGoogleFitBackground();
        return true;
      }

      // Request via native permission screen
      final granted = await _healthChannel.invokeMethod<bool>('requestPermissions') ?? false;
      _healthConnected = granted;

      if (granted) {
        debugPrint('Health Connect: permissions granted ✅');
        _initGoogleFitBackground();
      } else {
        debugPrint('Health Connect: permissions denied — using raw pedometer');
      }
      return granted;
    } catch (e) {
      debugPrint('Health Connect native request error: $e — falling back to health package');
      // Fallback: try via health package
      return await _requestHealthPackageFallback();
    }
  }

  Future<bool> _requestHealthPackageFallback() async {
    try {
      final health = Health();
      final types = [
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.HEART_RATE,
      ];
      final permissions = types.map((_) => HealthDataAccess.READ).toList();
      final granted = await health.requestAuthorization(types, permissions: permissions);
      _healthConnected = granted;
      if (granted) _initGoogleFitBackground();
      return granted;
    } catch (e) {
      debugPrint('Health package fallback error: $e');
      return false;
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<bool> init() async {
    if (_initialized) return true;
    _initialized = true;

    if (kIsWeb) { _startWebMock(); return true; }

    await _requestPermissions();

    // Always start raw pedometer for INSTANT per-step updates
    _startRawPedometer();

    // Request Health Connect permissions and start background sync
    _initGoogleFitBackground();

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

  Future<void> _initGoogleFitBackground() async {
    try {
      final health = Health();

final types = [
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.HEART_RATE,
      ];

      final permissions = types.map((_) => HealthDataAccess.READ).toList();
      final granted = await health.requestAuthorization(types, permissions: permissions);
      if (!granted) {
        debugPrint('Google Fit authorization denied — raw pedometer continues');
        return;
      }

      _dataSource = defaultTargetPlatform == TargetPlatform.iOS
          ? 'apple_health' : 'google_fit';

      debugPrint('Connected to: $_dataSource');

      // Initial sync
      await _syncFromFit(health);

      // Sync every 30 seconds during active session
      _syncTimer = Timer.periodic(const Duration(minutes: 3), (_) async { // Battery: 30s→3min
        await _syncFromFit(health);
      });

    } catch (e) {
      debugPrint('Google Fit init error — raw pedometer continues: $e');
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

      // Only update if Google Fit reports MORE steps than our live counter
      // This corrects the total without resetting live session progress
      if (total > _todaySteps) {
        _todaySteps = total;
        _stepsCtrl.add(total);
        debugPrint('Google Fit correction: $total steps');
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
    _stepSub?.cancel();
    _dataSource = 'pedometer';
    int? _pedometerBase;

    _stepSub = Pedometer.stepCountStream.listen(
      (event) {
        // Set base on first reading or if steps reset (device reboot)
        if (_pedometerBase == null || event.steps < (_pedometerBase ?? 0)) {
          _pedometerBase = event.steps - _todaySteps; // preserve any existing count
        }
        final live = event.steps - (_pedometerBase ?? event.steps);
        if (live >= 0 && live != _todaySteps) {
          _todaySteps = live;
          _stepsCtrl.add(_todaySteps); // fires on EVERY step
        }
      },
      onError: (e) => debugPrint('Pedometer error: $e'),
    );
  }

  // ── Accelerometer + Gyroscope ─────────────────────────────────────────────

  void _initMotionSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 500), // Battery: 50ms→500ms
    ).listen((e) {
      _lastAccel = e;
      _emitMotion();
    }, onError: (e) => debugPrint('Accel error: $e'));

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 500), // Battery: 50ms→500ms
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
          accuracy: LocationAccuracy.low, // Battery: medium→low
          distanceFilter: 50,             // Battery: 20m→50m
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
    _batchTimer = Timer.periodic(const Duration(minutes: 10), (_) => _upload()); // Battery: 5→10min
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


  // ── Sync session data from Health Connect at session end ──────────────────
  // Called at session stop to get accurate summary even if Dart was killed
  Future<Map<String,dynamic>> syncSessionData(DateTime startTime, DateTime endTime) async {
    final durationSecs = endTime.difference(startTime).inSeconds;
    final result = <String,dynamic>{
      'steps': _todaySteps,
      'distance_km': _distanceKm,
      'calories': _todaySteps * 0.04,
      'duration_seconds': durationSecs,
      'source': 'pedometer',
    };

    try {
      final health = Health();
      final types = [
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.HEART_RATE,
      ];

      final permissions = types.map((_) => HealthDataAccess.READ).toList();
      final granted = await health.requestAuthorization(types, permissions: permissions);
      if (!granted) return result;

      // Steps for this exact session window
      final stepData = await health.getHealthDataFromTypes(
        startTime: startTime, endTime: endTime,
        types: [HealthDataType.STEPS]);
      int sessionSteps = 0;
      for (final d in stepData) {
        if (d.value is NumericHealthValue) {
          sessionSteps += (d.value as NumericHealthValue).numericValue.toInt();
        }
      }

      // Distance
      final distData = await health.getHealthDataFromTypes(
        startTime: startTime, endTime: endTime,
        types: [HealthDataType.DISTANCE_WALKING_RUNNING]);
      double sessionDist = 0;
      for (final d in distData) {
        if (d.value is NumericHealthValue) {
          sessionDist += (d.value as NumericHealthValue).numericValue;
        }
      }

      // Calories
      final calData = await health.getHealthDataFromTypes(
        startTime: startTime, endTime: endTime,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED]);
      double sessionCal = 0;
      for (final d in calData) {
        if (d.value is NumericHealthValue) {
          sessionCal += (d.value as NumericHealthValue).numericValue;
        }
      }

      if (sessionSteps > 0) {
        result['steps']  = sessionSteps;
        result['source'] = 'health_connect';
      }
      if (sessionDist > 0) result['distance_km'] = sessionDist / 1000;
      if (sessionCal > 0)  result['calories']    = sessionCal;
      result['duration_seconds'] = durationSecs;

      debugPrint('Health session sync: ${result['steps']} steps, ${result['distance_km']}km, ${result['calories']}kcal, ${durationSecs}s');
    } catch (e) {
      debugPrint('Health session sync error: $e');
    }
    return result;
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
