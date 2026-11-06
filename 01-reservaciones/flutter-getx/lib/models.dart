class User {
  final String id, name, email, role;
  User.fromJson(Map j) : id = j['id'], name = j['name'], email = j['email'], role = j['role'];
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email, 'role': role};
  bool get isAdmin => role == 'admin';
}

class Establishment {
  final String id, name, description, address, openTime, closeTime;
  final List<int> days;
  Establishment.fromJson(Map j)
      : id = j['id'],
        name = j['name'],
        description = j['description'] ?? '',
        address = j['address'] ?? '',
        openTime = j['openTime'],
        closeTime = j['closeTime'],
        days = List<int>.from(j['days'] ?? []);
}

class Service {
  final String id, name, description;
  final double price;
  final int durationMin;
  Service.fromJson(Map j)
      : id = j['id'],
        name = j['name'],
        description = j['description'] ?? '',
        price = (j['price'] as num).toDouble(),
        durationMin = (j['durationMin'] as num).toInt();
}

class Reservation {
  final String id, status;
  final DateTime start, end;
  final Service? service;
  final Establishment? establishment;
  final User client;
  Reservation.fromJson(Map j)
      : id = j['id'],
        status = j['status'],
        start = DateTime.parse(j['start']).toLocal(),
        end = DateTime.parse(j['end']).toLocal(),
        service = j['service'] == null ? null : Service.fromJson(j['service']),
        establishment = j['establishment'] == null ? null : Establishment.fromJson(j['establishment']),
        client = User.fromJson(j['client']);
  bool get isActive => status == 'pendiente' || status == 'confirmada';
}

class AppNotification {
  final String id, title, body;
  final bool read;
  final DateTime createdAt;
  AppNotification.fromJson(Map j)
      : id = j['id'],
        title = j['title'],
        body = j['body'],
        read = j['read'] ?? false,
        createdAt = DateTime.parse(j['createdAt']).toLocal();
}
