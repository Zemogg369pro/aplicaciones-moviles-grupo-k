import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../storage/app_info_db.dart';
import '../storage/session_storage.dart';
import '../storage/user_data_storage.dart';

void _msg(BuildContext c, String m, {bool error = false}) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? Colors.red : null));

// ===================== INICIO DE SESIÓN (SharedPreferences) =====================
class LoginScreen extends StatefulWidget {
  final SessionStorage session;
  final VoidCallback onDone;
  const LoginScreen({super.key, required this.session, required this.onDone});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _user = TextEditingController(text: widget.session.rememberedUser ?? '');
  final _pass = TextEditingController();
  bool _remember = true;

  Future<void> _go(bool register) async {
    try {
      if (register) await widget.session.register(_user.text, _pass.text);
      await widget.session.login(_user.text, _pass.text, remember: _remember);
      await AppInfoDb.log(register ? 'registro' : 'inicio_sesion', user: widget.session.currentUser);
      widget.onDone();
    } on ArgumentError catch (e) {
      if (mounted) _msg(context, '${e.message}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Inicio de sesión · SharedPreferences')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          TextField(controller: _user, decoration: const InputDecoration(labelText: 'Usuario')),
          TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña (mín. 6)')),
          CheckboxListTile(value: _remember, onChanged: (v) => setState(() => _remember = v!), title: const Text('Recordar usuario')),
          FilledButton(onPressed: () => _go(false), child: const Text('Entrar')),
          TextButton(onPressed: () => _go(true), child: const Text('Crear cuenta')),
        ]),
      );
}

// ===================== HOME con 3 pestañas =====================
class HomeScreen extends StatefulWidget {
  final SessionStorage session;
  final VoidCallback onLogout;
  final Future<void> Function() onThemeChanged;
  const HomeScreen({super.key, required this.session, required this.onLogout, required this.onThemeChanged});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final user = widget.session.currentUser!;
    final pages = [
      UserDataTab(user: user, onThemeChanged: widget.onThemeChanged),
      CacheTab(user: user),
      AppInfoTab(key: ValueKey(_tab)),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('Hola, $user'), actions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await AppInfoDb.log('cierre_sesion', user: user);
            await widget.session.logout();
            widget.onLogout();
          },
        ),
      ]),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          AppInfoDb.log('pantalla', user: user, detail: ['datos_usuario', 'cache', 'info_app'][i]);
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'Datos (Hive)'),
          NavigationDestination(icon: Icon(Icons.cached), label: 'Caché (Hive)'),
          NavigationDestination(icon: Icon(Icons.storage), label: 'Info app (SQLite)'),
        ],
      ),
    );
  }
}

// ===================== DATOS DE USUARIO (Hive) =====================
class UserDataTab extends StatefulWidget {
  final String user;
  final Future<void> Function() onThemeChanged;
  const UserDataTab({super.key, required this.user, required this.onThemeChanged});
  @override
  State<UserDataTab> createState() => _UserDataTabState();
}

class _UserDataTabState extends State<UserDataTab> {
  final _store = UserDataStorage();
  final _name = TextEditingController(), _email = TextEditingController(), _phone = TextEditingController();
  bool _dark = false;
  double _font = 16;

  @override
  void initState() {
    super.initState();
    _store.load(widget.user).then((d) => setState(() {
          _name.text = d['name'];
          _email.text = d['email'];
          _phone.text = d['phone'];
          _dark = d['darkMode'];
          _font = (d['fontSize'] as num).toDouble();
        }));
  }

  Future<void> _save() async {
    if (_email.text.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text)) {
      return _msg(context, 'Correo inválido', error: true);
    }
    await _store.save(widget.user, {'name': _name.text.trim(), 'email': _email.text.trim(), 'phone': _phone.text.trim(), 'darkMode': _dark, 'fontSize': _font});
    await AppInfoDb.log('datos_guardados', user: widget.user);
    await widget.onThemeChanged();
    if (mounted) _msg(context, 'Datos guardados en Hive (caja "user_${widget.user}")');
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
        TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo'), keyboardType: TextInputType.emailAddress),
        TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Teléfono'), keyboardType: TextInputType.phone),
        SwitchListTile(title: const Text('Modo oscuro'), value: _dark, onChanged: (v) => setState(() => _dark = v)),
        Text('Tamaño de letra: ${_font.toStringAsFixed(0)}', style: TextStyle(fontSize: _font)),
        Slider(min: 12, max: 24, divisions: 6, value: _font, onChanged: (v) => setState(() => _font = v)),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Guardar')),
        TextButton(
          onPressed: () async {
            await _store.clear(widget.user);
            if (context.mounted) _msg(context, 'Datos del usuario borrados');
          },
          child: const Text('Borrar mis datos'),
        ),
        const Text('Los datos se conservan al cerrar la app y son distintos para cada usuario.', style: TextStyle(color: Colors.grey)),
      ]);
}

// ===================== CACHÉ (Hive con TTL) =====================
class CacheTab extends StatefulWidget {
  final String user;
  const CacheTab({super.key, required this.user});
  @override
  State<CacheTab> createState() => _CacheTabState();
}

class _CacheTabState extends State<CacheTab> {
  final _cache = CacheStorage();
  static const _key = 'posts', _ttl = Duration(minutes: 5);
  List<dynamic> _posts = [];
  String _source = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    final cached = await _cache.get(_key, _ttl);
    if (!force && cached != null && !cached.$3) {
      setState(() {
        _posts = jsonDecode(cached.$1);
        _source = 'Caché (guardado ${DateFormat('HH:mm:ss').format(cached.$2)}, vigente 5 min)';
        _loading = false;
      });
      return;
    }
    try {
      final r = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/posts?_limit=15')).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      await _cache.put(_key, r.body);
      await AppInfoDb.log('cache_actualizada', user: widget.user);
      setState(() {
        _posts = jsonDecode(r.body);
        _source = 'Red (guardado en caché)';
      });
    } catch (_) {
      setState(() {
        _posts = cached == null ? [] : jsonDecode(cached.$1);
        _source = cached == null ? 'Sin conexión y sin caché' : 'Sin conexión: mostrando caché del ${DateFormat('dd/MM HH:mm').format(cached.$2)}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(_source),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: 'Actualizar desde la red', icon: const Icon(Icons.refresh), onPressed: () => _load(force: true)),
            IconButton(
              tooltip: 'Vaciar caché',
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                await _cache.clear();
                if (context.mounted) _msg(context, 'Caché vaciada');
              },
            ),
          ]),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _posts.isEmpty
              ? const Center(child: Text('Sin datos'))
              : ListView(children: _posts.map((p) => ListTile(title: Text(p['title']), subtitle: Text(p['body'], maxLines: 2))).toList()),
        ),
      ]);
}

// ===================== INFORMACIÓN DE APLICACIÓN (SQLite) =====================
class AppInfoTab extends StatelessWidget {
  const AppInfoTab({super.key});
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm:ss');
    return FutureBuilder(
      future: Future.wait([AppInfoDb.summary(), AppInfoDb.recent(), AppInfoDb.firstOpen()]),
      builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final summary = s.data![0] as List<Map<String, Object?>>;
        final recent = s.data![1] as List<Map<String, Object?>>;
        final first = s.data![2] as String?;
        return ListView(padding: const EdgeInsets.all(12), children: [
          ListTile(title: const Text('Versión de la app'), trailing: const Text(AppInfoDb.appVersion)),
          ListTile(title: const Text('Primera apertura'), trailing: Text(first == null ? '-' : fmt.format(DateTime.parse(first)))),
          const Divider(),
          const Text('Eventos por tipo (SELECT … GROUP BY)', style: TextStyle(fontWeight: FontWeight.bold)),
          ...summary.map((r) => ListTile(dense: true, title: Text('${r['event']}'), trailing: Text('${r['total']}'))),
          const Divider(),
          const Text('Últimos eventos', style: TextStyle(fontWeight: FontWeight.bold)),
          ...recent.map((r) => ListTile(
                dense: true,
                title: Text('${r['event']}${r['detail'] != null ? ' · ${r['detail']}' : ''}'),
                subtitle: Text('${r['user'] ?? '-'} · ${fmt.format(DateTime.parse(r['created_at'] as String))}'),
              )),
        ]);
      },
    );
  }
}
