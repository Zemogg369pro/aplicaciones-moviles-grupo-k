import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// INFORMACIÓN DE APLICACIÓN con SQLite (base relacional): bitácora de uso de la app
/// (aperturas, versión, pantallas visitadas) con consultas SQL y agregados.
class AppInfoDb {
  static Database? _db;

  static Future<Database> get db async => _db ??= await openDatabase(
        join(await getDatabasesPath(), 'app_info.db'),
        version: 1,
        onCreate: (d, _) async {
          await d.execute('''
            CREATE TABLE app_events(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user TEXT,
              event TEXT NOT NULL,
              detail TEXT,
              app_version TEXT NOT NULL,
              created_at TEXT NOT NULL
            )''');
          await d.execute('CREATE INDEX idx_events_user ON app_events(user)');
        },
      );

  static const appVersion = '1.0.0';

  static Future<int> log(String event, {String? user, String? detail}) async => (await db).insert('app_events', {
        'user': user, 'event': event, 'detail': detail, 'app_version': appVersion,
        'created_at': DateTime.now().toIso8601String(),
      });

  static Future<List<Map<String, Object?>>> recent({int limit = 50}) async =>
      (await db).query('app_events', orderBy: 'id DESC', limit: limit);

  /// Resumen por tipo de evento (consulta agregada).
  static Future<List<Map<String, Object?>>> summary() async =>
      (await db).rawQuery('SELECT event, COUNT(*) AS total FROM app_events GROUP BY event ORDER BY total DESC');

  static Future<String?> firstOpen() async {
    final r = await (await db).rawQuery("SELECT MIN(created_at) AS f FROM app_events WHERE event = 'app_abierta'");
    return r.first['f'] as String?;
  }

  static Future<int> clear() async => (await db).delete('app_events');
}
