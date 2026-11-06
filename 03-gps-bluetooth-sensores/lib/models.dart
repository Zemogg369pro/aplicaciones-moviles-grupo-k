import 'dart:math';

class TrackPoint {
  final double lat, lng, speed; // speed m/s
  final DateTime time;
  final bool moving;
  TrackPoint(this.lat, this.lng, this.speed, this.time, this.moving);
  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'speed': speed, 't': time.toIso8601String(), 'moving': moving};
  factory TrackPoint.fromJson(Map j) =>
      TrackPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble(), (j['speed'] as num).toDouble(), DateTime.parse(j['t']), j['moving'] ?? false);
}

/// Detección de un dispositivo BLE durante el recorrido (hora + ubicación)
class BleDetection {
  final String deviceId, name;
  final int rssi;
  final DateTime time;
  final double? lat, lng;
  BleDetection(this.deviceId, this.name, this.rssi, this.time, this.lat, this.lng);
  Map<String, dynamic> toJson() => {'id': deviceId, 'name': name, 'rssi': rssi, 't': time.toIso8601String(), 'lat': lat, 'lng': lng};
  factory BleDetection.fromJson(Map j) =>
      BleDetection(j['id'], j['name'], j['rssi'], DateTime.parse(j['t']), (j['lat'] as num?)?.toDouble(), (j['lng'] as num?)?.toDouble());
  double get distance => estimateDistance(rssi);
}

/// Evento de sensores (inicio/fin de movimiento, giro detectado por giroscopio, etc.)
class SensorEvent {
  final String type, detail;
  final DateTime time;
  SensorEvent(this.type, this.detail, this.time);
  Map<String, dynamic> toJson() => {'type': type, 'detail': detail, 't': time.toIso8601String()};
  factory SensorEvent.fromJson(Map j) => SensorEvent(j['type'], j['detail'], DateTime.parse(j['t']));
}

class Trip {
  final String id;
  final DateTime start;
  DateTime? end;
  final List<TrackPoint> points;
  final List<BleDetection> ble;
  final List<SensorEvent> events;
  double distance; // metros
  Duration movingTime;

  Trip({required this.id, required this.start, this.end, List<TrackPoint>? points, List<BleDetection>? ble,
      List<SensorEvent>? events, this.distance = 0, this.movingTime = Duration.zero})
      : points = points ?? [],
        ble = ble ?? [],
        events = events ?? [];

  Duration get duration => (end ?? DateTime.now()).difference(start);
  double get avgSpeedKmh => duration.inSeconds == 0 ? 0 : distance / duration.inSeconds * 3.6;
  double get maxSpeedKmh => points.isEmpty ? 0 : points.map((p) => p.speed).reduce(max) * 3.6;

  Map<String, dynamic> toJson() => {
        'id': id, 'start': start.toIso8601String(), 'end': end?.toIso8601String(), 'distance': distance,
        'movingTime': movingTime.inSeconds,
        'points': points.map((e) => e.toJson()).toList(),
        'ble': ble.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
      };
  factory Trip.fromJson(Map j) => Trip(
        id: j['id'],
        start: DateTime.parse(j['start']),
        end: j['end'] == null ? null : DateTime.parse(j['end']),
        distance: (j['distance'] as num).toDouble(),
        movingTime: Duration(seconds: j['movingTime'] ?? 0),
        points: (j['points'] as List).map((e) => TrackPoint.fromJson(e)).toList(),
        ble: (j['ble'] as List).map((e) => BleDetection.fromJson(e)).toList(),
        events: (j['events'] as List).map((e) => SensorEvent.fromJson(e)).toList(),
      );
}

/// Estimación APROXIMADA de distancia a partir del RSSI (modelo log-distance).
/// txPower = RSSI medido a 1 m (≈ -59 dBm), n = factor ambiental (2 = espacio libre).
double estimateDistance(int rssi, {int txPower = -59, double n = 2.0}) => pow(10, (txPower - rssi) / (10 * n)).toDouble();

String proximityLabel(int rssi) {
  final d = estimateDistance(rssi);
  if (d < 1) return 'Inmediato (<1 m)';
  if (d < 3) return 'Cerca (~${d.toStringAsFixed(1)} m)';
  if (d < 10) return 'Medio (~${d.toStringAsFixed(0)} m)';
  return 'Lejos (>10 m)';
}

String fmtDuration(Duration d) =>
    '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
String fmtDistance(double m) => m < 1000 ? '${m.toStringAsFixed(0)} m' : '${(m / 1000).toStringAsFixed(2)} km';
