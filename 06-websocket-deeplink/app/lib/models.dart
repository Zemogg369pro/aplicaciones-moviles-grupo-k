class ChatUser {
  final String id, name, username;
  bool online;
  DateTime? lastSeen;
  ChatUser.fromJson(Map j)
      : id = j['id'],
        name = j['name'],
        username = j['username'] ?? '',
        online = j['online'] ?? false,
        lastSeen = j['lastSeen'] == null ? null : DateTime.parse(j['lastSeen']).toLocal();
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'username': username};
}

class Attachment {
  final String url, name, mime;
  Attachment.fromJson(Map j) : url = j['url'], name = j['name'], mime = j['mime'] ?? '';
  Map<String, dynamic> toJson() => {'url': url, 'name': name, 'mime': mime};
  bool get isImage => mime.startsWith('image/');
}

/// Estados: enviando -> enviado -> entregado -> leido
class Message {
  String id; // id del servidor (o clientId mientras se envía)
  final String clientId, conversationId, senderId, senderName;
  String text;
  Attachment? attachment;
  DateTime createdAt;
  DateTime? editedAt;
  bool deleted;
  String status;

  Message({required this.id, required this.clientId, required this.conversationId, required this.senderId, this.senderName = '',
      required this.text, this.attachment, required this.createdAt, this.editedAt, this.deleted = false, this.status = 'enviando'});

  factory Message.fromJson(Map j) => Message(
        id: j['id'],
        clientId: j['clientId'] ?? j['id'],
        conversationId: j['conversationId'],
        senderId: j['senderId'],
        senderName: j['senderName'] ?? '',
        text: j['text'] ?? '',
        attachment: j['attachment'] == null ? null : Attachment.fromJson(j['attachment']),
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
        editedAt: j['editedAt'] == null ? null : DateTime.parse(j['editedAt']).toLocal(),
        deleted: j['deleted'] ?? false,
        status: j['status'] ?? 'enviado',
      );

  /// Formato del outbox persistente (mensajes pendientes de envío)
  Map<String, dynamic> toOutbox() => {
        'type': 'message', 'clientId': clientId, 'conversationId': conversationId, 'text': text,
        'attachment': attachment?.toJson(), 'createdAt': createdAt.toIso8601String(), 'senderId': senderId,
      };
}

class Conversation {
  final String id, type;
  String name;
  List<ChatUser> members;
  int unread;
  Message? lastMessage;
  final String? joinPolicy, adminId, link;
  List<ChatUser> pendingRequests;

  Conversation.fromJson(Map j)
      : id = j['id'],
        type = j['type'],
        name = j['name'] ?? 'Chat',
        members = (j['members'] as List).map((e) => ChatUser.fromJson(e)).toList(),
        unread = j['unread'] ?? 0,
        lastMessage = j['lastMessage'] == null ? null : Message.fromJson(j['lastMessage']),
        joinPolicy = j['joinPolicy'],
        adminId = j['adminId'],
        link = j['link'],
        pendingRequests = ((j['pendingRequests'] ?? []) as List).map((e) => ChatUser.fromJson(e)).toList();

  bool get isGroup => type == 'group';
  ChatUser? other(String me) => isGroup ? null : members.firstWhere((m) => m.id != me, orElse: () => members.first);
}
