import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'chat_store.dart';
import 'deep_links.dart';
import 'screens/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ChatStore();
  await store.restore();
  await DeepLinks.init(store);
  runApp(ChangeNotifierProvider.value(value: store, child: const ChatApp()));
  // procesa el enlace con el que se abrió la app (si ya hay sesión)
  WidgetsBinding.instance.addPostFrameCallback((_) => DeepLinks.process(store));
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ChatStore>();
    return MaterialApp(
      title: 'Chat en tiempo real',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: store.loggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}

// ===================== LOGIN / REGISTRO =====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final user = TextEditingController(), pass = TextEditingController(), name = TextEditingController();
  bool register = false, loading = false;
  String? error;

  Future<void> _submit() async {
    if (user.text.trim().isEmpty || pass.text.length < 6 || (register && name.text.trim().isEmpty)) {
      setState(() => error = 'Completa los campos (contraseña mínimo 6 caracteres)');
      return;
    }
    setState(() { loading = true; error = null; });
    final store = context.read<ChatStore>();
    try {
      await store.login(user.text.trim(), pass.text, name: register ? name.text.trim() : null);
      // tras autenticarse continúa al chat del enlace pendiente
      WidgetsBinding.instance.addPostFrameCallback((_) => DeepLinks.process(store));
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 40),
            const Icon(Icons.forum, size: 80, color: Colors.indigo),
            Text(register ? 'Crear cuenta' : 'Iniciar sesión', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            if (DeepLinks.pending != null)
              const Padding(padding: EdgeInsets.all(8), child: Text('Inicia sesión para abrir la conversación del enlace', textAlign: TextAlign.center, style: TextStyle(color: Colors.indigo))),
            if (register) TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: user, decoration: const InputDecoration(labelText: 'Usuario'), autocorrect: false),
            TextField(controller: pass, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 20),
            loading ? const Center(child: CircularProgressIndicator()) : FilledButton(onPressed: _submit, child: Text(register ? 'Registrarme' : 'Entrar')),
            TextButton(onPressed: () => setState(() => register = !register), child: Text(register ? 'Ya tengo cuenta' : 'Crear una cuenta')),
          ]),
        ),
      );
}

// ===================== INICIO =====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<ChatStore>();
    if (s.notice != null) {
      final n = s.notice!;
      s.notice = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(n))));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        bottom: s.conn == ConnState.conectado
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Container(
                  color: Colors.orange,
                  width: double.infinity,
                  padding: const EdgeInsets.all(4),
                  child: Text(s.conn == ConnState.conectando ? 'Conectando…' : 'Sin conexión · reconectando automáticamente',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
        actions: [
          PopupMenuButton(itemBuilder: (_) => [
            PopupMenuItem(onTap: s.logout, child: Text('Cerrar sesión (${s.me?.name})')),
          ]),
        ],
      ),
      body: tab == 0 ? const ConversationsTab() : const UsersTab(),
      floatingActionButton: tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewGroupScreen())),
              icon: const Icon(Icons.group_add),
              label: const Text('Nuevo grupo'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) {
          setState(() => tab = i);
          if (i == 1) s.loadUsers();
        },
        destinations: [
          NavigationDestination(icon: Badge(isLabelVisible: s.totalUnread > 0, label: Text('${s.totalUnread}'), child: const Icon(Icons.chat)), label: 'Conversaciones'),
          const NavigationDestination(icon: Icon(Icons.people), label: 'Usuarios'),
        ],
      ),
    );
  }
}

Widget avatar(String name, {bool online = false, bool group = false}) => Stack(children: [
      CircleAvatar(child: group ? const Icon(Icons.group) : Text(name.isEmpty ? '?' : name[0].toUpperCase())),
      if (online)
        Positioned(
          right: 0, bottom: 0,
          child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
        ),
    ]);

class ConversationsTab extends StatelessWidget {
  const ConversationsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<ChatStore>();
    if (s.conversations.isEmpty) return const Center(child: Text('Sin conversaciones.\nVe a Usuarios para iniciar una.', textAlign: TextAlign.center));
    return RefreshIndicator(
      onRefresh: s.loadConversations,
      child: ListView(
        children: s.conversations.map((c) {
          final other = c.other(s.me!.id);
          final typingNames = s.typing[c.id]?.values.toList() ?? [];
          final last = c.lastMessage;
          final lastText = last == null ? '' : (last.deleted ? 'Mensaje eliminado' : (last.attachment != null ? '📎 ${last.attachment!.name}' : last.text));
          return ListTile(
            leading: avatar(c.name, online: other?.online ?? false, group: c.isGroup),
            title: Text(c.name, style: TextStyle(fontWeight: c.unread > 0 ? FontWeight.bold : null)),
            subtitle: Text(typingNames.isNotEmpty ? '${typingNames.join(', ')} está escribiendo…' : lastText,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: typingNames.isNotEmpty ? Colors.green : null, fontStyle: typingNames.isNotEmpty ? FontStyle.italic : null)),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (last != null) Text(DateFormat('HH:mm').format(last.createdAt), style: const TextStyle(fontSize: 11)),
              if (c.unread > 0) Badge(label: Text('${c.unread}')),
            ]),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: c.id, title: c.name))),
          );
        }).toList(),
      ),
    );
  }
}

class UsersTab extends StatelessWidget {
  const UsersTab({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<ChatStore>();
    return RefreshIndicator(
      onRefresh: s.loadUsers,
      child: ListView(
        children: s.users.map((u) => ListTile(
              leading: avatar(u.name, online: u.online),
              title: Text(u.name),
              subtitle: Text(u.online ? 'En línea' : (u.lastSeen == null ? '@${u.username}' : 'Últ. vez ${DateFormat('dd/MM HH:mm').format(u.lastSeen!)}')),
              trailing: const Icon(Icons.chat_bubble_outline),
              onTap: () async {
                final c = await s.openDirect(u.id);
                if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: c.id, title: c.name)));
              },
            )).toList(),
      ),
    );
  }
}

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});
  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final name = TextEditingController();
  final selected = <String>{};
  String policy = 'approval';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ChatStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo grupo')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre del grupo')),
        const SizedBox(height: 12),
        const Text('Ingreso mediante enlace de invitación'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'approval', label: Text('Con aprobación')),
            ButtonSegment(value: 'open', label: Text('Abierto')),
          ],
          selected: {policy},
          onSelectionChanged: (v) => setState(() => policy = v.first),
        ),
        const Divider(),
        const Text('Participantes'),
        ...s.users.map((u) => CheckboxListTile(
              value: selected.contains(u.id),
              title: Text(u.name),
              onChanged: (v) => setState(() => v! ? selected.add(u.id) : selected.remove(u.id)),
            )),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: name.text.trim().isEmpty && selected.isEmpty
                ? null
                : () async {
                    if (name.text.trim().isEmpty) return;
                    final c = await s.createGroup(name.text.trim(), selected.toList(), policy);
                    if (context.mounted) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: c.id, title: c.name)));
                    }
                  },
            child: const Text('Crear grupo'),
          ),
        ),
      ),
    );
  }
}
