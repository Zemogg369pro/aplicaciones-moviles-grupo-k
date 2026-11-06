import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/repo.dart';
import 'chat_screens.dart';
import 'post_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    const pages = [FeedTab(), MyPostsTab(), ChatsTab(), ProfileTab()];
    return Scaffold(
      body: pages[tab],
      floatingActionButton: tab < 2
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostFormScreen())),
              icon: const Icon(Icons.add),
              label: const Text('Publicar'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.search), label: 'Objetos'),
          const NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Mis publicaciones'),
          NavigationDestination(
            icon: StreamBuilder<List<Chat>>(
              stream: Repo.myChats(),
              builder: (_, s) {
                final n = (s.data ?? []).fold<int>(0, (a, c) => a + ((c.unread[Repo.me.uid] ?? 0) as num).toInt());
                return Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.chat));
              },
            ),
            label: 'Chats',
          ),
          const NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

/// Tarjeta reutilizable de publicación
class PostCard extends StatelessWidget {
  final Post p;
  const PostCard(this.p, {super.key});
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: p.photoUrl == null
              ? CircleAvatar(child: Icon(p.isLost ? Icons.help : Icons.check))
              : ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(p.photoUrl!, width: 56, height: 56, fit: BoxFit.cover)),
          title: Text(p.name),
          subtitle: Text('${p.category} · ${p.location}\n${DateFormat('dd/MM/yyyy').format(p.date)}'),
          isThreeLine: true,
          trailing: Chip(
            label: Text(p.resolved ? 'RESUELTO' : p.type.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11)),
            backgroundColor: p.resolved ? Colors.grey : (p.isLost ? Colors.red : Colors.green),
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id))),
        ),
      );
}

/// Publicaciones pendientes de todos los usuarios, con búsqueda y filtros
class FeedTab extends StatefulWidget {
  const FeedTab({super.key});
  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  String query = '', type = 'todos', location = '';
  String? category;
  DateTime? since;

  bool _match(Post p) {
    final q = query.toLowerCase();
    return (type == 'todos' || p.type == type) &&
        (category == null || p.category == category) &&
        (location.isEmpty || p.location.toLowerCase().contains(location.toLowerCase())) &&
        (since == null || !p.date.isBefore(since!)) &&
        (q.isEmpty || p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q));
  }

  Future<void> _filters() async {
    final locCtrl = TextEditingController(text: location);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Filtros', style: Theme.of(ctx).textTheme.titleLarge),
            DropdownButtonFormField<String?>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [const DropdownMenuItem(value: null, child: Text('Todas')), ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))],
              onChanged: (v) => setM(() => category = v),
            ),
            TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Ubicación contiene...')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(since == null ? 'Cualquier fecha' : 'Desde ${DateFormat('dd/MM/yyyy').format(since!)}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final d = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: since ?? DateTime.now());
                setM(() => since = d);
              },
            ),
            Row(children: [
              TextButton(onPressed: () => setM(() { category = null; since = null; locCtrl.clear(); }), child: const Text('Limpiar')),
              const Spacer(),
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aplicar')),
            ]),
          ]),
        ),
      ),
    );
    setState(() => location = locCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Objetos pendientes'),
        actions: [IconButton(onPressed: _filters, icon: Badge(isLabelVisible: category != null || since != null || location.isNotEmpty, child: const Icon(Icons.filter_alt)))],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar objeto...', border: OutlineInputBorder(), isDense: true),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'todos', label: Text('Todos')),
                ButtonSegment(value: 'perdido', label: Text('Perdidos')),
                ButtonSegment(value: 'encontrado', label: Text('Encontrados')),
              ],
              selected: {type},
              onSelectionChanged: (s) => setState(() => type = s.first),
            ),
          ]),
        ),
      ),
      body: StreamBuilder<List<Post>>(
        stream: Repo.pendingPosts(),
        builder: (_, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!.where(_match).toList();
          if (list.isEmpty) return const Center(child: Text('No hay publicaciones que coincidan'));
          return ListView(padding: const EdgeInsets.only(bottom: 80), children: list.map((p) => PostCard(p)).toList());
        },
      ),
    );
  }
}

/// Historial de publicaciones personales (incluye resueltas)
class MyPostsTab extends StatelessWidget {
  const MyPostsTab({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis publicaciones')),
        body: StreamBuilder<List<Post>>(
          stream: Repo.myPosts(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.isEmpty) return const Center(child: Text('Aún no has publicado nada'));
            return ListView(children: snap.data!.map((p) => PostCard(p)).toList());
          },
        ),
      );
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context) {
    final u = AuthService.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        CircleAvatar(radius: 48, backgroundImage: u.photoURL != null ? NetworkImage(u.photoURL!) : null, child: u.photoURL == null ? const Icon(Icons.person, size: 48) : null),
        const SizedBox(height: 12),
        Text(u.displayName ?? '', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        Text(u.email ?? '', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('Sesión iniciada con Google (OAuth 2.0)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        OutlinedButton.icon(onPressed: AuthService.signOut, icon: const Icon(Icons.logout), label: const Text('Cerrar sesión')),
      ]),
    );
  }
}
