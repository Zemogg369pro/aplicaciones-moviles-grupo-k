import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_scope.dart';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../data/models/challenge.dart';
import '../../data/models/place.dart';
import '../../data/services/services.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common.dart';

/// Módulo admin: solo el editor crea, edita y desactiva lugares, y crea y edita retos.
/// La ruta está protegida por el middleware y cada operación vuelve a validar el rol en el servicio.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _v = 0;
  void _reload() => setState(() => _v++);

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = scope.services, u = scope.user;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          bottom: const TabBar(tabs: [Tab(text: 'Lugares'), Tab(text: 'Retos')]),
        ),
        body: TabBarView(children: [
          AsyncView<List<Place>>(
            key: ValueKey('p$_v'),
            future: s.places.todos(u),
            builder: (list) => list.isEmpty
                ? const EmptyState('No hay lugares.')
                : ListView(
                    children: list
                        .map((p) => ListTile(
                              leading: Icon(categoryIcon(p.category), color: p.active ? null : Colors.grey),
                              title: Text(p.name, style: TextStyle(color: p.active ? null : Colors.grey)),
                              subtitle: Text('${p.code} · ${p.municipality} · ${p.active ? 'activo' : 'inactivo'}'),
                              onTap: () async {
                                await Navigator.pushNamed(context, AppRoutes.adminPlace, arguments: p.id);
                                _reload();
                              },
                              trailing: Switch(
                                value: p.active,
                                onChanged: (v) async {
                                  try {
                                    await s.places.desactivar(p.id, u, activo: v);
                                    if (context.mounted) showMessage(context, v ? 'Lugar activado' : 'Lugar desactivado');
                                  } catch (e) {
                                    if (context.mounted) showMessage(context, errorText(e), error: true);
                                  }
                                  _reload();
                                },
                              ),
                            ))
                        .toList(),
                  ),
          ),
          AsyncView<List<Challenge>>(
            key: ValueKey('c$_v'),
            future: s.challenges.todos(u),
            builder: (list) => list.isEmpty
                ? const EmptyState('No hay retos.')
                : ListView(
                    children: list
                        .map((c) => ListTile(
                              leading: const Icon(Icons.emoji_events),
                              title: Text(c.title),
                              subtitle: Text('${Categories.label(c.category)} · meta ${c.goal} · ${c.active ? 'activo' : 'inactivo'}'),
                              onTap: () async {
                                await Navigator.pushNamed(context, AppRoutes.adminChallenge, arguments: c.id);
                                _reload();
                              },
                            ))
                        .toList(),
                  ),
          ),
        ]),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            onPressed: () async {
              final tab = DefaultTabController.of(ctx).index;
              await Navigator.pushNamed(context, tab == 0 ? AppRoutes.adminPlace : AppRoutes.adminChallenge);
              _reload();
            },
            icon: const Icon(Icons.add),
            label: const Text('Nuevo'),
          ),
        ),
      ),
    );
  }
}

// ---------------- Formulario de lugar ----------------
class PlaceFormPage extends StatefulWidget {
  final String? placeId;
  const PlaceFormPage({super.key, this.placeId});
  @override
  State<PlaceFormPage> createState() => _PlaceFormPageState();
}

class _PlaceFormPageState extends State<PlaceFormPage> {
  final _c = {for (final k in ['name', 'municipality', 'address', 'description', 'schedule', 'image', 'code']) k: TextEditingController()};
  String _category = Categories.museo;
  Place? _original;
  Map<String, String> _errors = {};
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.placeId != null && _original == null) {
      AppScope.of(context).services.places.obtener(widget.placeId!).then((p) => setState(() {
            _original = p;
            _c['name']!.text = p.name;
            _c['municipality']!.text = p.municipality;
            _c['address']!.text = p.address;
            _c['description']!.text = p.description;
            _c['schedule']!.text = p.schedule;
            _c['image']!.text = p.image;
            _c['code']!.text = p.code;
            _category = p.category;
            _loading = false;
          }));
    } else {
      _loading = false;
    }
  }

  Future<void> _save() async {
    final scope = AppScope.of(context);
    final place = Place(
      id: _original?.id ?? newId(),
      name: _c['name']!.text, category: _category, municipality: _c['municipality']!.text.trim(),
      address: _c['address']!.text.trim(), description: _c['description']!.text.trim(),
      schedule: _c['schedule']!.text.trim(), image: _c['image']!.text.trim(), code: _c['code']!.text,
      active: _original?.active ?? true,
    );
    try {
      await scope.services.places.guardar(place, scope.user);
      if (!mounted) return;
      showMessage(context, 'Lugar guardado');
      Navigator.pop(context);
    } on ValidationException catch (e) {
      setState(() => _errors = e.fieldErrors); // la información capturada se conserva
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e), error: true);
    }
  }

  Widget _field(String key, String label, {int lines = 1}) => TextField(
        controller: _c[key],
        maxLines: lines,
        decoration: InputDecoration(labelText: label, errorText: _errors[key]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.placeId == null ? 'Nuevo lugar' : 'Editar lugar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              _field('name', 'Nombre *'),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(labelText: 'Categoría *', errorText: _errors['category']),
                items: Categories.all.map((c) => DropdownMenuItem(value: c, child: Text(Categories.label(c)))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              _field('municipality', 'Municipio *'),
              _field('address', 'Dirección *'),
              _field('schedule', 'Horario *'),
              _field('description', 'Descripción', lines: 3),
              _field('image', 'URL de imagen (opcional)'),
              _field('code', 'Código de registro único *'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('Guardar')),
            ]),
    );
  }
}

// ---------------- Formulario de reto ----------------
class ChallengeFormPage extends StatefulWidget {
  final String? challengeId;
  const ChallengeFormPage({super.key, this.challengeId});
  @override
  State<ChallengeFormPage> createState() => _ChallengeFormPageState();
}

class _ChallengeFormPageState extends State<ChallengeFormPage> {
  final _title = TextEditingController(), _desc = TextEditingController(), _goal = TextEditingController(text: '3');
  String _category = Categories.museo;
  DateTime _start = DateTime.now(), _end = DateTime.now().add(const Duration(days: 30));
  bool _active = true;
  Challenge? _original;
  Map<String, String> _errors = {};
  final _fmt = DateFormat('d MMM yyyy', 'es_MX');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.challengeId != null && _original == null) {
      AppScope.of(context).services.challenges.obtener(widget.challengeId!).then((c) => setState(() {
            _original = c;
            _title.text = c.title;
            _desc.text = c.description;
            _goal.text = '${c.goal}';
            _category = c.category;
            _start = c.startDate;
            _end = c.endDate;
            _active = c.active;
          }));
    }
  }

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(context: context, initialDate: start ? _start : _end, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (d == null) return;
    setState(() {
      if (start) {
        _start = d;
      } else {
        _end = d;
      }
    });
  }

  Future<void> _save() async {
    final scope = AppScope.of(context);
    final goal = int.tryParse(_goal.text.trim());
    final c = Challenge(
      id: _original?.id ?? newId(), title: _title.text.trim(), description: _desc.text.trim(), category: _category,
      goal: goal ?? 0, startDate: _start, endDate: _end, active: _active,
    );
    try {
      await scope.services.challenges.guardar(c, scope.user);
      if (!mounted) return;
      showMessage(context, 'Reto guardado');
      Navigator.pop(context);
    } on ValidationException catch (e) {
      setState(() => _errors = e.fieldErrors);
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.challengeId == null ? 'Nuevo reto' : 'Editar reto')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _title, decoration: InputDecoration(labelText: 'Título *', errorText: _errors['title'])),
        TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Descripción'), maxLines: 2),
        DropdownButtonFormField<String>(
          key: ValueKey(_category),
          initialValue: _category,
          decoration: InputDecoration(labelText: 'Categoría *', errorText: _errors['category']),
          items: Categories.all.map((c) => DropdownMenuItem(value: c, child: Text(Categories.label(c)))).toList(),
          onChanged: (v) => setState(() => _category = v!),
        ),
        TextField(
          controller: _goal,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Meta (lugares distintos) *', errorText: _errors['goal']),
        ),
        ListTile(contentPadding: EdgeInsets.zero, title: Text('Inicio: ${_fmt.format(_start)}'), trailing: const Icon(Icons.edit_calendar), onTap: () => _pick(true)),
        ListTile(contentPadding: EdgeInsets.zero, title: Text('Fin: ${_fmt.format(_end)}'), trailing: const Icon(Icons.edit_calendar), onTap: () => _pick(false)),
        if (_errors['dates'] != null) Text(_errors['dates']!, style: const TextStyle(color: Colors.red)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Activo'), value: _active, onChanged: (v) => setState(() => _active = v)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ]),
    );
  }
}
