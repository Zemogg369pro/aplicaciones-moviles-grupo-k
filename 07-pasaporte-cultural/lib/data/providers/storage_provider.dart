import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Acceso concreto al almacenamiento. Solo guarda y lee "tablas" (listas de mapas JSON).
/// No contiene reglas de negocio ni lógica de interfaz.
abstract class StorageProvider {
  Future<List<Map<String, dynamic>>> readTable(String table);
  Future<void> writeTable(String table, List<Map<String, dynamic>> rows);
}

/// Persistencia local en el dispositivo con SharedPreferences (los datos se conservan entre ejecuciones).
class PrefsStorageProvider implements StorageProvider {
  final SharedPreferences _prefs;
  PrefsStorageProvider(this._prefs);

  static Future<PrefsStorageProvider> create() async => PrefsStorageProvider(await SharedPreferences.getInstance());

  String _key(String table) => 'pc_$table';

  @override
  Future<List<Map<String, dynamic>>> readTable(String table) async {
    final raw = _prefs.getString(_key(table));
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> writeTable(String table, List<Map<String, dynamic>> rows) async {
    final ok = await _prefs.setString(_key(table), jsonEncode(rows));
    if (!ok) throw StateError('No se pudo guardar la información.');
  }
}

/// Almacenamiento en memoria para pruebas automatizadas.
class MemoryStorageProvider implements StorageProvider {
  final Map<String, String> _data = {};

  @override
  Future<List<Map<String, dynamic>>> readTable(String table) async {
    final raw = _data[table];
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> writeTable(String table, List<Map<String, dynamic>> rows) async => _data[table] = jsonEncode(rows);
}
