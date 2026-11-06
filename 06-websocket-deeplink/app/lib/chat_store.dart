import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api.dart';
import 'models.dart';

enum ConnState { desconectado, conectando, conectado }

/// Estado global del chat: sesión, WebSocket con reconexión automática,
/// conversaciones, mensajes, presencia, "escribiendo…" y outbox de mensajes pendientes.
class ChatStore extends ChangeNotifier {
  ChatUser? me;
  ConnState conn = ConnState.desconectado;
  List<Conversation> conversations = [];
  List<ChatUser> users = [];
  final Map<String, List<Message>> messages = {};
  final Map<String, Map<String, String>> typing = {}; // convId -> {userId: name}
  String? openConversationId; // conversación visible (para marcar como leído)
  String? notice; // avisos (solicitudes de ingreso, etc.)

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _retries = 0;
  bool _manualClose = false;
  final List<Map<String, dynamic>> _outbox = []; // mensajes sin confirmar (persisten)
  final _typingTimers = <String, Timer>{};

  bool get loggedIn => me != null && Api.token != null;

  // ===================== sesión =====================
  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    await Api.loadToken();
    final u = p.getString('me');
    if (u != null && Api.token != null) {
      me = ChatUser.fromJson(jsonDecode(u));
      _outbox.addAll((jsonDecode(p.getString('outbox') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e)));
      await _afterLogin();
    }
    notifyListeners();
  }

  Future<void> login(String username, String password, {String? name}) async {
    final data = name == null
        ? await Api.post('/auth/login', {'username': username, 'password': password})
        : await Api.post('/auth/register', {'username': username, 'password': password, 'name': name});
    Api.token = data['token'];
    me = ChatUser.fromJson(data['user']);
    final p = await SharedPreferences.getInstance();
    await p.setString('token', Api.token!);
    await p.setString('me', jsonEncode(me!.toJson()));
    await _afterLogin();
    notifyListeners();
  }

  Future<void> logout() async {
    _manualClose = true;
    await _ch?.sink.close();
    final p = await SharedPreferences.getInstance();
    await p.clear();
    Api.token = null;
    me = null;
    conversations = [];
    messages.clear();
    _outbox.clear();
    conn = ConnState.desconectado;
    notifyListeners();
  }

  Future<void> _afterLogin() async {
    _manualClose = false;
    connect();
    await Future.wait([loadConversations(), loadUsers()]);
  }

  // ===================== REST =====================
  Future<void> loadConversations() async {
    try {
      conversations = (await Api.get('/conversations') as List).map((e) => Conversation.fromJson(e)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadUsers() async {
    try {
      users = (await Api.get('/users') as List).map((e) => ChatUser.fromJson(e)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadMessages(String convId) async {
    final list = (await Api.get('/conversations/$convId/messages') as List).map((e) => Message.fromJson(e)).toList();
    // conserva los mensajes locales aún no confirmados
    final pending = (messages[convId] ?? []).where((m) => m.status == 'enviando');
    messages[convId] = [...list, ...pending.where((p) => !list.any((m) => m.clientId == p.clientId))];
    notifyListeners();
  }

  Future<Conversation> openDirect(String userId) async {
    final c = Conversation.fromJson(await Api.post('/conversations', {'type': 'direct', 'userId': userId}));
    _upsertConv(c);
    return c;
  }

  Future<Conversation> createGroup(String name, List<String> memberIds, String joinPolicy) async {
    final c = Conversation.fromJson(await Api.post('/conversations', {'type': 'group', 'name': name, 'memberIds': memberIds, 'joinPolicy': joinPolicy}));
    _upsertConv(c);
    return c;
  }

  void _upsertConv(Conversation c) {
    conversations.removeWhere((x) => x.id == c.id);
    conversations.insert(0, c);
    notifyListeners();
  }

  // ===================== WebSocket =====================
  void connect() {
    if (Api.token == null || conn != ConnState.desconectado) return;
    conn = ConnState.conectando;
    notifyListeners();
    try {
      _ch = WebSocketChannel.connect(Uri.parse('$kWsUrl/ws?token=${Api.token}'));
      _ch!.ready.then((_) {
        conn = ConnState.conectado;
        _retries = 0;
        notifyListeners();
        _flushOutbox(); // reenvía lo pendiente al reconectar
        loadConversations();
        if (openConversationId != null) {
          loadMessages(openConversationId!);
          markRead(openConversationId!);
        }
      }).catchError((_) => _scheduleReconnect());
      _sub = _ch!.stream.listen(_onEvent, onDone: _scheduleReconnect, onError: (_) => _scheduleReconnect());
    } catch (_) {
      _scheduleReconnect();
    }
  }

  /// Reconexión automática con backoff exponencial (1, 2, 4 … 30 s)
  void _scheduleReconnect() {
    _sub?.cancel();
    conn = ConnState.desconectado;
    notifyListeners();
    if (_manualClose || Api.token == null) return;
    _reconnectTimer?.cancel();
    final secs = min(30, pow(2, _retries).toInt());
    _retries++;
    _reconnectTimer = Timer(Duration(seconds: secs), connect);
  }

  void _send(Map<String, dynamic> ev) {
    if (conn == ConnState.conectado) _ch?.sink.add(jsonEncode(ev));
  }

  void _onEvent(dynamic raw) {
    final ev = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (ev['type']) {
      case 'ack': // el servidor confirmó y asignó id: enviando -> enviado
        final m = Message.fromJson(ev['message']);
        _outbox.removeWhere((o) => o['clientId'] == ev['clientId']);
        _persistOutbox();
        _replaceByClientId(m);
        break;
      case 'message':
        final m = Message.fromJson(ev['message']);
        _replaceByClientId(m);
        final c = conversations.where((x) => x.id == m.conversationId).firstOrNull;
        if (c == null) {
          loadConversations();
        } else {
          c.lastMessage = m;
          if (m.senderId != me!.id && openConversationId != m.conversationId) c.unread++;
          conversations
            ..remove(c)
            ..insert(0, c);
        }
        typing[m.conversationId]?.remove(m.senderId);
        if (openConversationId == m.conversationId && m.senderId != me!.id) markRead(m.conversationId);
        break;
      case 'status': // entregado / leído
        final list = messages[ev['conversationId']] ?? [];
        for (final m in list) {
          if (m.id == ev['messageId']) m.status = ev['status'];
        }
        break;
      case 'typing':
        final convId = ev['conversationId'] as String;
        final uid = ev['userId'] as String;
        typing.putIfAbsent(convId, () => {});
        _typingTimers['$convId$uid']?.cancel();
        if (ev['isTyping'] == true) {
          typing[convId]![uid] = ev['name'];
          // si no llega "dejó de escribir", se limpia a los 5 s
          _typingTimers['$convId$uid'] = Timer(const Duration(seconds: 5), () {
            typing[convId]?.remove(uid);
            notifyListeners();
          });
        } else {
          typing[convId]!.remove(uid);
        }
        break;
      case 'presence':
        for (final u in [...users, ...conversations.expand((c) => c.members)]) {
          if (u.id == ev['userId']) {
            u.online = ev['online'];
            u.lastSeen = ev['lastSeen'] == null ? null : DateTime.parse(ev['lastSeen']).toLocal();
          }
        }
        break;
      case 'edited':
        _replaceByClientId(Message.fromJson(ev['message']));
        break;
      case 'deleted':
        for (final m in messages[ev['conversationId']] ?? <Message>[]) {
          if (m.id == ev['messageId']) {
            m.deleted = true;
            m.text = '';
            m.attachment = null;
          }
        }
        break;
      case 'conversation':
        loadConversations();
        break;
      case 'join_request':
        notice = '${ev['user']['name']} solicita unirse a un grupo';
        loadConversations();
        break;
      case 'error':
        if (ev['clientId'] != null) {
          _outbox.removeWhere((o) => o['clientId'] == ev['clientId']);
          _persistOutbox();
        }
        notice = ev['message'];
        break;
    }
    notifyListeners();
  }

  void _replaceByClientId(Message m) {
    final list = messages.putIfAbsent(m.conversationId, () => []);
    final i = list.indexWhere((x) => x.clientId == m.clientId || x.id == m.id);
    if (i >= 0) {
      list[i] = m;
    } else {
      list.add(m);
    }
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // orden cronológico
  }

  // ===================== acciones =====================
  void sendMessage(String convId, {String text = '', Attachment? attachment}) {
    final m = Message(
      id: const Uuid().v4(), clientId: const Uuid().v4(), conversationId: convId, senderId: me!.id, senderName: me!.name,
      text: text, attachment: attachment, createdAt: DateTime.now(), status: 'enviando',
    );
    messages.putIfAbsent(convId, () => []).add(m);
    _outbox.add(m.toOutbox());
    _persistOutbox();
    _send(m.toOutbox()); // si no hay conexión queda en el outbox y se envía al reconectar
    setTyping(convId, false);
    notifyListeners();
  }

  void _flushOutbox() {
    for (final o in List.of(_outbox)) {
      _send(o); // mismo clientId => el servidor no duplica
    }
  }

  Future<void> _persistOutbox() async => (await SharedPreferences.getInstance()).setString('outbox', jsonEncode(_outbox));

  void retry(Message m) => _send(m.toOutbox());

  void editMessage(Message m, String text) => _send({'type': 'edit', 'conversationId': m.conversationId, 'messageId': m.id, 'text': text});
  void deleteMessage(Message m) => _send({'type': 'delete', 'conversationId': m.conversationId, 'messageId': m.id});

  DateTime? _lastTypingSent;
  void setTyping(String convId, bool isTyping) {
    final now = DateTime.now();
    if (isTyping && _lastTypingSent != null && now.difference(_lastTypingSent!).inSeconds < 2) return;
    _lastTypingSent = isTyping ? now : null;
    _send({'type': 'typing', 'conversationId': convId, 'isTyping': isTyping});
  }

  void markRead(String convId) {
    _send({'type': 'read', 'conversationId': convId});
    final c = conversations.where((x) => x.id == convId).firstOrNull;
    if (c != null && c.unread > 0) {
      c.unread = 0;
      notifyListeners();
    }
  }

  int get totalUnread => conversations.fold(0, (a, c) => a + c.unread);

  @override
  void dispose() {
    _manualClose = true;
    _reconnectTimer?.cancel();
    _ch?.sink.close();
    super.dispose();
  }
}
