import 'package:cloud_firestore/cloud_firestore.dart';

const categories = ['Electrónicos', 'Documentos', 'Llaves', 'Ropa', 'Mochilas/Bolsos', 'Cartera/Dinero', 'Accesorios', 'Mascotas', 'Otros'];

class Post {
  final String id, ownerId, ownerName, ownerPhoto, type, name, description, category, location, status;
  final String? photoUrl;
  final DateTime date;
  final DateTime? createdAt;

  Post({
    required this.id, required this.ownerId, required this.ownerName, required this.ownerPhoto, required this.type,
    required this.name, required this.description, required this.category, required this.location,
    required this.status, required this.date, this.photoUrl, this.createdAt,
  });

  bool get isLost => type == 'perdido';
  bool get resolved => status == 'resuelto';

  factory Post.fromDoc(DocumentSnapshot d) {
    final j = d.data() as Map<String, dynamic>;
    return Post(
      id: d.id,
      ownerId: j['ownerId'],
      ownerName: j['ownerName'] ?? '',
      ownerPhoto: j['ownerPhoto'] ?? '',
      type: j['type'],
      name: j['name'],
      description: j['description'] ?? '',
      category: j['category'],
      location: j['location'] ?? '',
      status: j['status'] ?? 'pendiente',
      photoUrl: j['photoUrl'],
      date: (j['date'] as Timestamp).toDate(),
      createdAt: (j['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId, 'ownerName': ownerName, 'ownerPhoto': ownerPhoto, 'type': type, 'name': name,
        'description': description, 'category': category, 'location': location, 'status': status,
        'photoUrl': photoUrl, 'date': Timestamp.fromDate(date),
        // palabras clave normalizadas para la detección de coincidencias en Cloud Functions
        'keywords': keywords('$name $description'),
        'locationKeywords': keywords(location),
      };
}

const _stop = {'de', 'la', 'el', 'en', 'y', 'un', 'una', 'con', 'los', 'las', 'del', 'por', 'para', 'color', 'mi', 'se', 'al'};
List<String> keywords(String s) {
  const from = 'áéíóúüñ', to = 'aeiouun';
  var t = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    t = t.replaceAll(from[i], to[i]);
  }
  return t.split(RegExp(r'[^a-z0-9]+')).where((w) => w.length > 2 && !_stop.contains(w)).toSet().toList();
}

class Chat {
  final String id, postId, postName, lastMessage;
  final List<String> participants;
  final Map<String, dynamic> names, photos, unread;
  final DateTime? updatedAt;
  Chat.fromDoc(DocumentSnapshot d)
      : id = d.id,
        postId = (d.data() as Map)['postId'],
        postName = (d.data() as Map)['postName'] ?? '',
        lastMessage = (d.data() as Map)['lastMessage'] ?? '',
        participants = List<String>.from((d.data() as Map)['participants']),
        names = Map<String, dynamic>.from((d.data() as Map)['names'] ?? {}),
        photos = Map<String, dynamic>.from((d.data() as Map)['photos'] ?? {}),
        unread = Map<String, dynamic>.from((d.data() as Map)['unread'] ?? {}),
        updatedAt = ((d.data() as Map)['updatedAt'] as Timestamp?)?.toDate();

  String otherId(String me) => participants.firstWhere((p) => p != me, orElse: () => me);
}

class Message {
  final String id, senderId, text;
  final DateTime? createdAt;
  Message.fromDoc(DocumentSnapshot d)
      : id = d.id,
        senderId = (d.data() as Map)['senderId'],
        text = (d.data() as Map)['text'],
        createdAt = ((d.data() as Map)['createdAt'] as Timestamp?)?.toDate();
}
