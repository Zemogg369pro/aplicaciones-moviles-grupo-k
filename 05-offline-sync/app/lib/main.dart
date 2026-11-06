import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'db.dart';
import 'sync_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChangeNotifierProvider(create: (_) => SyncEngine()..start(), child: const App()));
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Incidencias Offline',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const ReportsScreen(),
      );
}

const categories = ['Infraestructura', 'Eléctrica', 'Agua / Fuga', 'Seguridad', 'Limpieza', 'Equipo dañado', 'Otro'];
final fmt = DateFormat('dd/MM/yyyy HH:mm');

const statusInfo = {
  SyncStatus.pendiente: (Icons.schedule, Colors.orange, 'Pendiente'),
  SyncStatus.sincronizando: (Icons.sync, Colors.blue, 'Sincronizando'),
  SyncStatus.sincronizado: (Icons.cloud_done, Colors.green, 'Sincronizado'),
  SyncStatus.error: (Icons.error, Colors.red, 'Error'),
};

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  SyncStatus? filter;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SyncEngine>();
    final list = filter == null ? s.reports : s.reports.where((r) => r.status == filter).toList();
    final online = s.networkAvailable && s.serverReachable;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de incidencias'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar ahora',
            onPressed: s.syncing ? null : () async {
              await s.syncNow();
              if (context.mounted && s.lastError != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo sincronizar: ${s.lastError}')));
              }
            },
            icon: s.syncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(children: [
        // Barra de estado de conectividad + sincronización
        Container(
          width: double.infinity,
          color: online ? Colors.green.shade100 : Colors.orange.shade100,
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(online ? Icons.wifi : Icons.wifi_off, size: 18),
              const SizedBox(width: 6),
              Text(s.networkLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${s.pending} en cola'),
            ]),
            Text('Última sincronización exitosa: ${s.lastSync == null ? 'nunca' : fmt.format(s.lastSync!)}', style: const TextStyle(fontSize: 12)),
            if (s.syncing) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: s.progress),
              Text('Enviando ${s.done} de ${s.total}...', style: const TextStyle(fontSize: 12)),
            ],
            if (!s.syncing && s.lastError != null && s.pending > 0)
              Text('Último error: ${s.lastError} · se reintentará automáticamente', style: const TextStyle(fontSize: 12, color: Colors.red)),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: const Text('Todos'), selected: filter == null, onSelected: (_) => setState(() => filter = null))),
            ...SyncStatus.values.map((st) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text(statusInfo[st]!.$3), selected: filter == st, onSelected: (_) => setState(() => filter = st)),
                )),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No hay reportes'))
              : RefreshIndicator(
                  onRefresh: s.syncNow,
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final r = list[i];
                      final (icon, color, label) = statusInfo[r.status]!;
                      return Card(
                        child: ListTile(
                          leading: r.photoPath != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(File(r.photoPath!), width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)))
                              : const Icon(Icons.report, size: 40),
                          title: Text(r.title),
                          subtitle: Text('${r.category} · ${fmt.format(r.date)}${r.lastError != null && r.status == SyncStatus.error ? '\n${r.lastError}' : ''}'),
                          isThreeLine: r.status == SyncStatus.error,
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(icon, color: color),
                            Text(label, style: TextStyle(fontSize: 10, color: color)),
                          ]),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportForm(report: r))),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportForm())),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo reporte'),
      ),
    );
  }
}

/// Alta / edición / eliminación de un reporte (funciona sin Internet)
class ReportForm extends StatefulWidget {
  final Report? report;
  const ReportForm({super.key, this.report});
  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  final _form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.report?.title);
  late final desc = TextEditingController(text: widget.report?.description);
  late String category = widget.report?.category ?? categories.first;
  late String? photoPath = widget.report?.photoPath;
  late double? lat = widget.report?.lat, lng = widget.report?.lng;
  late DateTime date = widget.report?.date ?? DateTime.now();
  bool locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.report == null) _locate();
  }

  Future<void> _locate() async {
    setState(() => locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw Exception('Permiso de ubicación denegado');
      // El GPS funciona sin Internet
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
      setState(() { lat = p.latitude; lng = p.longitude; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ubicación: $e')));
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _photo(ImageSource src) async {
    final f = await ImagePicker().pickImage(source: src, maxWidth: 1280, imageQuality: 75);
    if (f == null) return;
    // Se copia al almacenamiento de la app para que persista aunque se borre de la galería
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/${const Uuid().v4()}.jpg';
    await File(f.path).copy(dest);
    setState(() => photoPath = dest);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final engine = context.read<SyncEngine>();
    final isNew = widget.report == null;
    final r = widget.report ??
        Report(id: const Uuid().v4(), title: '', description: '', category: category, date: date, updatedAt: DateTime.now());
    r
      ..title = title.text.trim()
      ..description = desc.text.trim()
      ..category = category
      ..photoPath = photoPath
      ..lat = lat
      ..lng = lng
      ..date = date;
    await engine.save(r, isNew: isNew);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(engine.networkAvailable ? 'Reporte guardado; sincronizando...' : 'Sin conexión: el reporte se guardó y se enviará al recuperar la red'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.report == null ? 'Nuevo reporte' : 'Editar reporte'), actions: [
        if (widget.report != null)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                title: const Text('Eliminar reporte'),
                content: const Text('Se eliminará del dispositivo y del servidor al sincronizar.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                ],
              ));
              if (ok == true && context.mounted) {
                await context.read<SyncEngine>().delete(widget.report!);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
      ]),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Título'), validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null),
          TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Descripción'), maxLines: 3, validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null),
          DropdownButtonFormField(value: category, decoration: const InputDecoration(labelText: 'Categoría'),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => category = v!)),
          const SizedBox(height: 12),
          if (photoPath != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(photoPath!), height: 200, fit: BoxFit.cover)),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _photo(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text('Cámara'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _photo(ImageSource.gallery), icon: const Icon(Icons.photo), label: const Text('Galería'))),
          ]),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place),
            title: Text(lat == null ? 'Sin ubicación' : '${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}'),
            subtitle: const Text('Ubicación GPS'),
            trailing: locating ? const CircularProgressIndicator() : IconButton(icon: const Icon(Icons.my_location), onPressed: _locate),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(fmt.format(date)),
            subtitle: const Text('Fecha del incidente'),
            onTap: () async {
              final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: date);
              if (d != null) setState(() => date = DateTime(d.year, d.month, d.day, date.hour, date.minute));
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Guardar')),
        ]),
      ),
    );
  }
}
