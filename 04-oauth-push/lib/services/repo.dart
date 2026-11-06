import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models.dart';

class Repo {
  static final db = FirebaseFirestore.instance;
  static User get me => FirebaseAuth.instance.currentUser!;

  // ---------- publicaciones ----------
  /// Objetos pendientes (los resueltos dejan de aparecer)
  static Stream<List<Post>> pendingPosts() => db
      .collection('posts')
      .where('status', isEqualTo: 'pendiente')
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Post.fromDoc).toList());

  static Stream<List<Post>> myPosts() => db
      .collection('posts')
      .where('ownerId', isEqualTo: me.uid)
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Post.fromDoc).toList());

  static Stream<Post?> post(String id) =>
      db.collection('posts').doc(id).snapshots().map((d) => d.exists ? Post.fromDoc(d) : null);

  static Future<String?> uploadPhoto(File f) async {
    final ref = FirebaseStorage.instance.ref('posts/${me.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(f, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  static Future<void> savePost(Post p, {File? photo}) async {
    var data = p.toMap();
    if (photo != null) data['photoUrl'] = await uploadPhoto(photo);
    if (p.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await db.collection('posts').add(data); // dispara la Cloud Function de coincidencias
    } else {
      // Las reglas de Firestore garantizan que sólo el dueño puede editar
      await db.collection('posts').doc(p.id).update(data);
    }
  }

  static Future<void> deletePost(String id) => db.collection('posts').doc(id).delete();
  static Future<void> markResolved(String id) => db.collection('posts').doc(id).update({'status': 'resuelto', 'resolvedAt': FieldValue.serverTimestamp()});

  /// Coincidencias detectadas por la Cloud Function para una publicación
  static Stream<List<String>> matchesFor(String postId) => db
      .collection('matches')
      .where('postIds', arrayContains: postId)
      .snapshots()
      .map((s) => s.docs.map((d) => (List<String>.from(d['postIds'])).firstWhere((x) => x != postId)).toList());

  // ---------- chat ----------
  static Future<String> openChat(Post p) async {
    final ids = [me.uid, p.ownerId]..sort();
    final chatId = '${p.id}_${ids.join('_')}';
    final ref = db.collection('chats').doc(chatId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'postId': p.id,
        'postName': p.name,
        'participants': ids,
        'names': {me.uid: me.displayName, p.ownerId: p.ownerName},
        'photos': {me.uid: me.photoURL, p.ownerId: p.ownerPhoto},
        'unread': {me.uid: 0, p.ownerId: 0},
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }

  static Stream<List<Chat>> myChats() => db
      .collection('chats')
      .where('participants', arrayContains: me.uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Chat.fromDoc).toList());

  static Stream<Chat> chat(String id) => db.collection('chats').doc(id).snapshots().map(Chat.fromDoc);

  static Stream<List<Message>> messages(String chatId) => db
      .collection('chats/$chatId/messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Message.fromDoc).toList());

  static Future<void> send(Chat c, String text) async {
    final batch = db.batch();
    batch.set(db.collection('chats/${c.id}/messages').doc(), {
      'senderId': me.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    }); // dispara la Cloud Function que notifica al otro participante
    batch.update(db.collection('chats').doc(c.id), {
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
      'unread.${c.otherId(me.uid)}': FieldValue.increment(1),
    });
    await batch.commit();
  }

  static Future<void> markRead(String chatId) =>
      db.collection('chats').doc(chatId).update({'unread.${me.uid}': 0});
}
