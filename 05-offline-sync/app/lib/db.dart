import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

enum SyncStatus { pendiente, sincronizando, sincronizado, error }

class Report {
  final String id; // UUID generado en el dispositivo (clave de idempotencia)
  String title, description, category;
  String? photoPath;
  double? lat, lng;
  DateTime date, updatedAt;
  SyncStatus status;
  String? lastError;

  Report({required this.id, required this.title, required this.description, required this.category, this.photoPath,
      this.lat, this.lng, required this.date, required this.updatedAt, this.status = SyncStatus.pendiente, this.lastError});

  Map<String, Object?> toRow() => {
        'id': id, 'title': title, 'description': description, 'category': category, 'photoPath': photoPath,
        'lat': lat, 'lng': lng, 'date': date.toIso8601String(), 'updatedAt': updatedAt.toIso8601String(),
        'status': status.name, 'lastError': lastError,
      };
  factory Report.fromRow(Map<String, Object?> r) => Report(
        id: r['id'] as String, title: r['title'] as String, description: r['description'] as String,
        category: r['category'] as String, photoPath: r['photoPath'] as String?,
        lat: r['lat'] as double?, lng: r['lng'] as double?,
        date: DateTime.parse(r['date'] as String), updatedAt: DateTime.parse(r['updatedAt'] as String),
        status: SyncStatus.values.byName(r['status'] as String), lastError: r['lastError'] as String?,
      );
}

class QueueItem {
  final int id;
  final String reportId, op; // create | update | delete
  final int attempts;
  final DateTime nextAttemptAt;
  QueueItem.fromRow(Map<String, Object?> r)
      : id = r['id'] as int,
        reportId = r['reportId'] as String,
        op = r['op'] as String,
        attempts = r['attempts'] as int,
        nextAttemptAt = DateTime.parse(r['nextAttemptAt'] as String);
}

/// Base de datos local SQLite: sobrevive a cierres de la app y reinicios del dispositivo
class LocalDb {
  static Database? _db;
  static Future<Database> get db async => _db ??= await openDatabase(
        join(await getDatabasesPath(), 'incidencias.db'),
        version: 1,
        onCreate: (d, _) async {
          await d.execute('''CREATE TABLE reports(
            id TEXT PRIMARY KEY, title TEXT, description TEXT, category TEXT, photoPath TEXT,
            lat REAL, lng REAL, date TEXT, updatedAt TEXT, status TEXT, lastError TEXT)''');
          // Cola de operaciones pendientes (FIFO por id autoincremental)
          await d.execute('''CREATE TABLE sync_queue(
            id INTEGER PRIMARY KEY AUTOINCREMENT, reportId TEXT, op TEXT,
            attempts INTEGER DEFAULT 0, nextAttemptAt TEXT, lastError TEXT, createdAt TEXT)''');
        },
      );

  static Future<List<Report>> reports() async =>
      (await (await db).query('reports', orderBy: 'date DESC')).map(Report.fromRow).toList();

  static Future<Report?> report(String id) async {
    final r = await (await db).query('reports', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Report.fromRow(r.first);
  }

  static Future<void> upsertReport(Report r) async =>
      (await db).insert('reports', r.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> deleteReport(String id) async => (await db).delete('reports', where: 'id = ?', whereArgs: [id]);

  static Future<void> setStatus(String id, SyncStatus s, {String? error}) async =>
      (await db).update('reports', {'status': s.name, 'lastError': error}, where: 'id = ?', whereArgs: [id]);

  // ---------- cola ----------
  static Future<List<QueueItem>> queue() async =>
      (await (await db).query('sync_queue', orderBy: 'id ASC')).map(QueueItem.fromRow).toList();

  static Future<int> pendingCount() async =>
      Sqflite.firstIntValue(await (await db).rawQuery('SELECT COUNT(*) FROM sync_queue')) ?? 0;

  /// Encola una operación combinando con las existentes para no hacer envíos inútiles
  static Future<void> enqueue(String reportId, String op) async {
    final d = await db;
    final existing = await d.query('sync_queue', where: 'reportId = ?', whereArgs: [reportId]);
    final ops = existing.map((e) => e['op']).toSet();
    if (op == 'update' && (ops.contains('create') || ops.contains('update'))) return; // se envía el estado más reciente
    if (op == 'delete' && ops.contains('create')) {
      // nunca llegó al servidor: basta con quitarlo de la cola
      await d.delete('sync_queue', where: 'reportId = ?', whereArgs: [reportId]);
      return;
    }
    if (op == 'delete') await d.delete('sync_queue', where: 'reportId = ?', whereArgs: [reportId]);
    await d.insert('sync_queue', {
      'reportId': reportId, 'op': op, 'attempts': 0,
      'nextAttemptAt': DateTime.now().toIso8601String(), 'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> dequeue(int id) async => (await db).delete('sync_queue', where: 'id = ?', whereArgs: [id]);

  static Future<void> markFailed(QueueItem q, String error) async {
    final attempts = q.attempts + 1;
    // Backoff exponencial: 2, 4, 8, 16 ... hasta 5 minutos
    final wait = Duration(seconds: (1 << attempts.clamp(1, 8)).clamp(2, 300));
    await (await db).update('sync_queue',
        {'attempts': attempts, 'nextAttemptAt': DateTime.now().add(wait).toIso8601String(), 'lastError': error},
        where: 'id = ?', whereArgs: [q.id]);
  }

  static Future<bool> hasQueued(String reportId) async =>
      (await (await db).query('sync_queue', where: 'reportId = ?', whereArgs: [reportId])).isNotEmpty;
}
