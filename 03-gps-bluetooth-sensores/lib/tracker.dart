import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'models.dart';
import 'storage.dart';

/// Controlador central: GPS, sensores (acelerómetro/giroscopio) y escaneo BLE
class Tracker extends ChangeNotifier {
  // ---------- estado público ----------
  Position? position;
  Trip? trip; // recorrido activo
  bool moving = false;
  double accelMagnitude = 0; // m/s² sin gravedad (promedio)
  String orientation = 'Vertical';
  double turnDegrees = 0; // giro acumulado (eje Z) del giroscopio
  final List<SensorEvent> liveEvents = [];
  final Map<String, ScanResult> devices = {}; // dispositivos BLE detectados
  String? targetId, targetName; // dispositivo BLE seleccionado para registrar
  bool scanning = false;
  String? error;

  StreamSubscription<Position>? _posSub;
  StreamSubscription? _accSub, _userAccSub, _gyroSub, _scanSub;
  final _accWindow = <double>[];
  DateTime? _lastTurnEvent;
  DateTime _lastGyro = DateTime.now();
  DateTime? _lastTargetLog;
  Timer? _tick;

  // ---------- permisos ----------
  Future<bool> requestPermissions() async {
    final res = await [
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.sensors,
    ].request();
    if (!res[Permission.locationWhenInUse]!.isGranted) {
      error = 'Se requiere permiso de ubicación';
      notifyListeners();
      return false;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      error = 'Activa el GPS del dispositivo';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> init() async {
    if (!await requestPermissions()) return;
    error = null;
    position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    _startSensors();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 3),
    ).listen(_onPosition, onError: (e) {
      error = 'GPS: $e';
      notifyListeners();
    });
    notifyListeners();
  }

  // ---------- sensores ----------
  void _startSensors() {
    // Acelerómetro SIN gravedad -> detectar movimiento/detenido con datos reales
    _userAccSub = userAccelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
      final m = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      _accWindow.add(m);
      if (_accWindow.length > 25) _accWindow.removeAt(0);
      accelMagnitude = _accWindow.reduce((a, b) => a + b) / _accWindow.length;
      final nowMoving = accelMagnitude > 0.6; // umbral en m/s²
      if (nowMoving != moving) {
        moving = nowMoving;
        _event('movimiento', moving ? 'El usuario comenzó a moverse' : 'El usuario se detuvo');
      }
      notifyListeners();
    });
    // Acelerómetro CON gravedad -> orientación física del teléfono
    _accSub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
      final o = e.z.abs() > 8.5
          ? 'Plano (boca ${e.z > 0 ? 'arriba' : 'abajo'})'
          : (e.x.abs() > e.y.abs() ? 'Horizontal' : 'Vertical');
      if (o != orientation) {
        orientation = o;
        _event('orientación', 'Orientación: $o');
      }
    });
    // Giroscopio -> cambios de orientación (giros) integrando la velocidad angular
    _gyroSub = gyroscopeEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
      final now = DateTime.now();
      final dt = now.difference(_lastGyro).inMicroseconds / 1e6;
      _lastGyro = now;
      if (e.z.abs() > 0.3) turnDegrees += e.z * dt * 180 / pi;
      if (turnDegrees.abs() >= 45 && (_lastTurnEvent == null || now.difference(_lastTurnEvent!).inSeconds > 2)) {
        _event('giro', 'Giro de ${turnDegrees.abs().toStringAsFixed(0)}° a la ${turnDegrees > 0 ? 'izquierda' : 'derecha'}');
        _lastTurnEvent = now;
        turnDegrees = 0;
      }
    });
  }

  void _event(String type, String detail) {
    final ev = SensorEvent(type, detail, DateTime.now());
    liveEvents.insert(0, ev);
    if (liveEvents.length > 30) liveEvents.removeLast();
    trip?.events.add(ev);
  }

  // ---------- GPS / recorrido ----------
  void _onPosition(Position p) {
    position = p;
    final t = trip;
    if (t != null) {
      if (t.points.isNotEmpty) {
        final last = t.points.last;
        final d = Geolocator.distanceBetween(last.lat, last.lng, p.latitude, p.longitude);
        // filtra saltos por mala precisión
        if (p.accuracy < 30 && d > 1) t.distance += d;
      }
      t.points.add(TrackPoint(p.latitude, p.longitude, max(0, p.speed), DateTime.now(), moving));
    }
    notifyListeners();
  }

  bool get isTracking => trip != null;
  List<LatLng> get route => trip?.points.map((p) => LatLng(p.lat, p.lng)).toList() ?? [];
  double get currentSpeedKmh => max(0, position?.speed ?? 0) * 3.6;

  void startTrip() {
    trip = Trip(id: DateTime.now().millisecondsSinceEpoch.toString(), start: DateTime.now());
    if (position != null) {
      trip!.points.add(TrackPoint(position!.latitude, position!.longitude, 0, DateTime.now(), moving));
    }
    _event('recorrido', 'Recorrido iniciado');
    // actualiza duración en pantalla cada segundo y acumula tiempo en movimiento
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (moving && trip != null) trip!.movingTime += const Duration(seconds: 1);
      notifyListeners();
    });
    if (!scanning) startScan();
    notifyListeners();
  }

  Future<Trip?> stopTrip() async {
    final t = trip;
    if (t == null) return null;
    _event('recorrido', 'Recorrido finalizado');
    t.end = DateTime.now();
    _tick?.cancel();
    trip = null;
    await TripStorage.save(t);
    notifyListeners();
    return t;
  }

  // ---------- Bluetooth Low Energy ----------
  Future<void> startScan() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        error = 'Este dispositivo no soporta Bluetooth LE';
        notifyListeners();
        return;
      }
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn(); // solo Android
        } catch (_) {
          error = 'Enciende el Bluetooth';
          notifyListeners();
          return;
        }
      }
      _scanSub ??= FlutterBluePlus.onScanResults.listen(_onScan);
      await FlutterBluePlus.startScan(continuousUpdates: true, removeIfGone: const Duration(seconds: 15), androidUsesFineLocation: true);
      scanning = true;
      FlutterBluePlus.isScanning.where((s) => !s).first.then((_) {
        scanning = false;
        notifyListeners();
      });
      notifyListeners();
    } catch (e) {
      error = 'BLE: $e';
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    scanning = false;
    notifyListeners();
  }

  void _onScan(List<ScanResult> results) {
    devices
      ..clear()
      ..addEntries(results.map((r) => MapEntry(r.device.remoteId.str, r)));
    final t = trip;
    if (t != null) {
      final now = DateTime.now();
      for (final r in results) {
        final id = r.device.remoteId.str;
        final isTarget = targetId == null || id == targetId;
        // Registra hora y ubicación de la detección. Para el dispositivo seleccionado
        // se registra cada 5 s; sin selección, cada dispositivo una vez por recorrido.
        final already = t.ble.any((b) => b.deviceId == id);
        final throttleOk = _lastTargetLog == null || now.difference(_lastTargetLog!).inSeconds >= 5;
        if ((targetId != null && isTarget && throttleOk) || (targetId == null && !already)) {
          t.ble.add(BleDetection(id, deviceName(r), r.rssi, now, position?.latitude, position?.longitude));
          if (targetId != null) {
            _lastTargetLog = now;
            if (!already) _event('ble', 'Dispositivo ${deviceName(r)} detectado');
          }
        }
      }
    }
    notifyListeners();
  }

  void selectTarget(ScanResult? r) {
    targetId = r?.device.remoteId.str;
    targetName = r == null ? null : deviceName(r);
    notifyListeners();
  }

  static String deviceName(ScanResult r) {
    final n = r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : r.device.platformName;
    return n.isEmpty ? 'Desconocido (${r.device.remoteId.str.substring(0, 8)})' : n;
  }

  List<ScanResult> get sortedDevices => devices.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));

  @override
  void dispose() {
    _posSub?.cancel();
    _accSub?.cancel();
    _userAccSub?.cancel();
    _gyroSub?.cancel();
    _scanSub?.cancel();
    _tick?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}
