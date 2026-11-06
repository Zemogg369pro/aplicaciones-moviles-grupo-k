import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';

/// URL del servidor. En emulador Android 10.0.2.2 = localhost de la PC.
const kServer = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:4000');

/// Motor de sincronización Offline-First:
/// cola FIFO, detección de conectividad, verificación real del servidor,
/// reintentos con backoff exponencial e idempotencia por UUID.
class SyncEngine extends ChangeNotifier {
  bool networkAvailable = false; // hay Wi-Fi / datos
  bool serverReachable = false; // el servidor respondió /health
  bool syncing = false;
  int total = 0, done = 0;
  DateTime? lastSync;
  String? lastError;
  List<Report> reports = [];
  int pending = 0;

  StreamSubscription? _connSub;
  Timer? _retryTimer;

  double get progress => total == 0 ? 0 : done / total;
  String get networkLabel => !networkAvailable ? 'Sin conexión' : (serverReachable ? 'En línea' : 'Red sin acceso al servidor');

  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    final ls = prefs.getString('lastSync');
    lastSync = ls == null ? null : DateTime.parse(ls);

    // Al abrir la app: los reportes que quedaron "sincronizando" (app cerrada a medio envío) vuelven a pendiente
    for (final r in await LocalDb.reports()) {
      if (r.status == SyncStatus.sincronizando) await LocalDb.setStatus(r.id, SyncStatus.pendiente);
    }
    await refresh();

    // Detecta cambios de conectividad (Wi-Fi / datos móviles)
    _connSub = Connectivity().onConnectivityChanged.listen((results) => _onConnectivity(results));
    await _onConnectivity(await Connectivity().checkConnectivity());

    // Reintentos automáticos mientras la app está activa
    _retryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (pending > 0) trySync();
    });
  }

  Future<void> _onConnectivity(List<ConnectivityResult> results) async {
    networkAvailable = results.any((r) => r != ConnectivityResult.none);
    notifyListeners();
    if (networkAvailable) {
      await trySync(); // al recuperar conexión se sincroniza automáticamente
    } else {
      serverReachable = false;
      notifyListeners();
    }
  }

  /// Comprueba conectividad REAL con el servidor (no sólo estar en una red)
  Future<bool> checkServer() async {
    try {
      final r = await http.get(Uri.parse('$kServer/health')).timeout(const Duration(seconds: 5));
      serverReachable = r.statusCode == 200;
    } catch (_) {
      serverReachable = false;
    }
    notifyListeners();
    return serverReachable;
  }

  Future<void> refresh() async {
    reports = await LocalDb.reports();
    pending = await LocalDb.pendingCount();
    notifyListeners();
  }

  // ---------- operaciones CRUD (funcionan sin conexión) ----------
  Future<void> save(Report r, {required bool isNew}) async {
    r.updatedAt = DateTime.now();
    r.status = SyncStatus.pendiente;
    r.lastError = null;
    await LocalDb.upsertReport(r); // primero se guarda localmente
    await LocalDb.enqueue(r.id, isNew ? 'create' : 'update');
    await refresh();
    trySync();
  }

  Future<void> delete(Report r) async {
    await LocalDb.deleteReport(r.id);
    await LocalDb.enqueue(r.id, 'delete');
    await refresh();
    trySync();
  }

  /// Sincronización manual (botón) ignora el backoff
  Future<void> syncNow() => trySync(force: true);

  // ---------- procesamiento de la cola ----------
  Future<void> trySync({bool force = false}) async {
    if (syncing) return;
    if (!networkAvailable && !force) return;
    if (!await checkServer()) {
      lastError = 'El servidor no está disponible';
      notifyListeners();
      return;
    }
    final queue = await LocalDb.queue();
    final ready = queue.where((q) => force || !q.nextAttemptAt.isAfter(DateTime.now())).toList();
    if (ready.isEmpty) return;

    syncing = true;
    total = queue.length;
    done = 0;
    lastError = null;
    notifyListeners();

    for (final q in queue) {
      // se respeta el orden: si un elemento aún espera su reintento, los siguientes esperan también
      if (!force && q.nextAttemptAt.isAfter(DateTime.now())) break;
      final ok = await _process(q);
      if (!ok) break; // la conexión falló: los datos permanecen en la cola
      done++;
      notifyListeners();
    }

    if (done > 0) {
      lastSync = DateTime.now();
      (await SharedPreferences.getInstance()).setString('lastSync', lastSync!.toIso8601String());
    }
    syncing = false;
    await refresh();
  }

  Future<bool> _process(QueueItem q) async {
    try {
      http.Response res;
      if (q.op == 'delete') {
        res = await http.delete(Uri.parse('$kServer/reports/${q.reportId}'), headers: {'Idempotency-Key': '${q.reportId}-delete'})
            .timeout(const Duration(seconds: 15));
      } else {
        final r = await LocalDb.report(q.reportId);
        if (r == null) {
          await LocalDb.dequeue(q.id);
          return true;
        }
        await LocalDb.setStatus(r.id, SyncStatus.sincronizando);
        await refresh();
        String? photo;
        if (r.photoPath != null && await File(r.photoPath!).exists()) {
          photo = base64Encode(await File(r.photoPath!).readAsBytes());
        }
        // PUT con el UUID del cliente => crear o actualizar sin duplicar en reintentos
        res = await http
            .put(Uri.parse('$kServer/reports/${r.id}'),
                headers: {'Content-Type': 'application/json', 'Idempotency-Key': '${r.id}-${r.updatedAt.millisecondsSinceEpoch}'},
                body: jsonEncode({
                  'id': r.id, 'title': r.title, 'description': r.description, 'category': r.category,
                  'lat': r.lat, 'lng': r.lng, 'date': r.date.toIso8601String(),
                  'updatedAt': r.updatedAt.toIso8601String(), 'photoBase64': photo,
                }))
            .timeout(const Duration(seconds: 30));
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Sólo se marca sincronizado cuando el servidor CONFIRMA la recepción
        await LocalDb.dequeue(q.id);
        if (q.op != 'delete' && !await LocalDb.hasQueued(q.reportId)) {
          await LocalDb.setStatus(q.reportId, SyncStatus.sincronizado);
        }
        return true;
      }
      throw HttpException('HTTP ${res.statusCode}');
    } catch (e) {
      final msg = e is TimeoutException ? 'Tiempo de espera agotado' : e.toString();
      await LocalDb.markFailed(q, msg);
      if (q.op != 'delete') await LocalDb.setStatus(q.reportId, SyncStatus.error, error: msg);
      lastError = msg;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
