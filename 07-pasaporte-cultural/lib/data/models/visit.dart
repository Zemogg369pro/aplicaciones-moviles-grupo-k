import '../../core/dates.dart';

/// Visita: pertenece a un usuario y a un lugar.
class Visit {
  final String id;
  final String userId;
  final String placeId;
  final DateTime dateTime;

  const Visit({required this.id, required this.userId, required this.placeId, required this.dateTime});

  String get dayKey => Dates.dayKey(dateTime);

  factory Visit.fromMap(Map<String, dynamic> m) =>
      Visit(id: m['id'], userId: m['userId'], placeId: m['placeId'], dateTime: DateTime.parse(m['dateTime']));

  Map<String, dynamic> toMap() =>
      {'id': id, 'userId': userId, 'placeId': placeId, 'dateTime': dateTime.toIso8601String()};
}
