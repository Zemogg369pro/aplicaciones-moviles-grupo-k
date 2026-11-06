import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'storage.dart';
import 'tracker.dart';

void main() {
  runApp(ChangeNotifierProvider(create: (_) => Tracker()..init(), child: const App()));
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Recorridos + BLE',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [const TrackScreen(), const BleScreen(), const HistoryScreen()];
    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Recorrido'),
          NavigationDestination(icon: Icon(Icons.bluetooth_searching), label: 'Bluetooth'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }
}

Widget osmLayer() => TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'mx.uat.recorridos');

// =============== RECORRIDO EN VIVO ===============
class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final map = MapController();
  bool follow = true;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<Tracker>();
    final pos = t.position;
    if (t.error != null && pos == null) {
      return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(t.error!), FilledButton(onPressed: t.init, child: const Text('Reintentar')),
      ])));
    }
    if (pos == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final here = LatLng(pos.latitude, pos.longitude);
    if (follow) WidgetsBinding.instance.addPostFrameCallback((_) {
      try { map.move(here, map.camera.zoom); } catch (_) {}
    });
    final trip = t.trip;
    return Scaffold(
      appBar: AppBar(title: const Text('Recorrido GPS'), actions: [
        IconButton(icon: Icon(follow ? Icons.gps_fixed : Icons.gps_not_fixed), onPressed: () => setState(() => follow = !follow)),
      ]),
      body: Column(children: [
        Expanded(
          child: FlutterMap(
            mapController: map,
            options: MapOptions(initialCenter: here, initialZoom: 17, onPositionChanged: (_, gesture) {
              if (gesture && follow) setState(() => follow = false);
            }),
            children: [
              osmLayer(),
              if (t.route.length > 1) PolylineLayer(polylines: [Polyline(points: t.route, strokeWidth: 5, color: Colors.blue)]),
              MarkerLayer(markers: [
                if (t.route.isNotEmpty) Marker(point: t.route.first, child: const Icon(Icons.flag, color: Colors.green)),
                Marker(point: here, child: const Icon(Icons.my_location, color: Colors.red, size: 30)),
              ]),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _stat('Distancia', fmtDistance(trip?.distance ?? 0)),
              _stat('Duración', fmtDuration(trip?.duration ?? Duration.zero)),
              _stat('Velocidad', '${t.currentSpeedKmh.toStringAsFixed(1)} km/h'),
              _stat('Promedio', '${(trip?.avgSpeedKmh ?? 0).toStringAsFixed(1)} km/h'),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Chip(
                avatar: Icon(t.moving ? Icons.directions_walk : Icons.accessibility_new, color: t.moving ? Colors.green : Colors.grey),
                label: Text('${t.moving ? 'En movimiento' : 'Detenido'} (${t.accelMagnitude.toStringAsFixed(2)} m/s²)'),
              ),
              Chip(avatar: const Icon(Icons.screen_rotation), label: Text(t.orientation)),
            ]),
            if (t.targetName != null)
              Text('📡 Registrando: ${t.targetName} · ${trip?.ble.where((b) => b.deviceId == t.targetId).length ?? 0} detecciones'),
            if (t.liveEvents.isNotEmpty) Text('Último evento: ${t.liveEvents.first.detail}', style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: t.isTracking
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        final saved = await t.stopTrip();
                        if (saved != null && context.mounted) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetail(trip: saved)));
                        }
                      },
                      icon: const Icon(Icons.stop),
                      label: const Text('Finalizar recorrido'))
                  : FilledButton.icon(onPressed: t.startTrip, icon: const Icon(Icons.play_arrow), label: const Text('Iniciar recorrido')),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);
}

// =============== BLUETOOTH LE ===============
class BleScreen extends StatelessWidget {
  const BleScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<Tracker>();
    final list = t.sortedDevices;
    return Scaffold(
      appBar: AppBar(title: const Text('Dispositivos BLE cercanos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: t.scanning ? t.stopScan : t.startScan,
        icon: Icon(t.scanning ? Icons.stop : Icons.search),
        label: Text(t.scanning ? 'Detener' : 'Escanear'),
      ),
      body: Column(children: [
        if (t.error != null) MaterialBanner(content: Text(t.error!), actions: [TextButton(onPressed: t.startScan, child: const Text('Reintentar'))]),
        if (t.scanning) const LinearProgressIndicator(),
        ListTile(
          leading: const Icon(Icons.track_changes),
          title: Text(t.targetName == null ? 'Sin dispositivo seleccionado' : 'Seleccionado: ${t.targetName}'),
          subtitle: const Text('Toca un dispositivo para registrar cuándo se detecta durante el recorrido'),
          trailing: t.targetId == null ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => t.selectTarget(null)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('La proximidad se estima a partir del RSSI y es aproximada; no es una medición exacta.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No hay dispositivos. Presiona Escanear.'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final ScanResult r = list[i];
                    final id = r.device.remoteId.str;
                    final strength = ((r.rssi + 100) / 60).clamp(0.0, 1.0);
                    return ListTile(
                      selected: id == t.targetId,
                      leading: Icon(Icons.bluetooth, color: Color.lerp(Colors.red, Colors.green, strength)),
                      title: Text(Tracker.deviceName(r)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$id · RSSI ${r.rssi} dBm'),
                        Text(proximityLabel(r.rssi)),
                        LinearProgressIndicator(value: strength),
                      ]),
                      isThreeLine: true,
                      trailing: id == t.targetId ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                      onTap: () => t.selectTarget(r),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// =============== HISTORIAL ===============
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Trip>> trips = TripStorage.load();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Historial de recorridos')),
        body: FutureBuilder<List<Trip>>(
          future: trips,
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.isEmpty) return const Center(child: Text('Aún no hay recorridos guardados'));
            return ListView(
              children: snap.data!
                  .map((tr) => Dismissible(
                        key: Key(tr.id),
                        background: Container(color: Colors.red),
                        onDismissed: (_) => TripStorage.delete(tr.id),
                        child: ListTile(
                          leading: const Icon(Icons.route),
                          title: Text(DateFormat('dd/MM/yyyy HH:mm').format(tr.start)),
                          subtitle: Text('${fmtDistance(tr.distance)} · ${fmtDuration(tr.duration)} · ${tr.ble.map((b) => b.deviceId).toSet().length} dispositivos BLE'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetail(trip: tr))),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      );
}

class TripDetail extends StatelessWidget {
  final Trip trip;
  const TripDetail({super.key, required this.trip});
  @override
  Widget build(BuildContext context) {
    final pts = trip.points.map((p) => LatLng(p.lat, p.lng)).toList();
    final hm = DateFormat('HH:mm:ss');
    return Scaffold(
      appBar: AppBar(title: Text('Recorrido ${DateFormat('dd/MM HH:mm').format(trip.start)}')),
      body: ListView(children: [
        SizedBox(
          height: 300,
          child: pts.isEmpty
              ? const Center(child: Text('Sin puntos GPS'))
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: pts.first,
                    initialZoom: 16,
                    initialCameraFit: pts.length > 1 ? CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(30)) : null,
                  ),
                  children: [
                    osmLayer(),
                    PolylineLayer(polylines: [Polyline(points: pts, strokeWidth: 5, color: Colors.blue)]),
                    MarkerLayer(markers: [
                      Marker(point: pts.first, child: const Icon(Icons.flag, color: Colors.green)),
                      Marker(point: pts.last, child: const Icon(Icons.sports_score, color: Colors.red)),
                      ...trip.ble.where((b) => b.lat != null).map((b) =>
                          Marker(point: LatLng(b.lat!, b.lng!), width: 20, height: 20, child: const Icon(Icons.bluetooth, color: Colors.indigo, size: 18))),
                    ]),
                  ],
                ),
        ),
        ListTile(title: const Text('Distancia'), trailing: Text(fmtDistance(trip.distance))),
        ListTile(title: const Text('Duración'), trailing: Text(fmtDuration(trip.duration))),
        ListTile(title: const Text('Tiempo en movimiento'), trailing: Text(fmtDuration(trip.movingTime))),
        ListTile(title: const Text('Velocidad promedio / máxima'),
            trailing: Text('${trip.avgSpeedKmh.toStringAsFixed(1)} / ${trip.maxSpeedKmh.toStringAsFixed(1)} km/h')),
        ExpansionTile(
          title: Text('Dispositivos BLE detectados (${trip.ble.length} registros)'),
          children: trip.ble.map((b) => ListTile(
                dense: true,
                leading: const Icon(Icons.bluetooth),
                title: Text('${b.name} · ${b.rssi} dBm (~${b.distance.toStringAsFixed(1)} m)'),
                subtitle: Text('${hm.format(b.time)} · ${b.lat?.toStringAsFixed(5)}, ${b.lng?.toStringAsFixed(5)}'),
              )).toList(),
        ),
        ExpansionTile(
          title: Text('Eventos de sensores (${trip.events.length})'),
          children: trip.events.map((e) => ListTile(dense: true, title: Text(e.detail), subtitle: Text('${e.type} · ${hm.format(e.time)}'))).toList(),
        ),
      ]),
    );
  }
}
