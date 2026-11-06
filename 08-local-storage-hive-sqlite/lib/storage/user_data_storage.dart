import 'package:hive_flutter/hive_flutter.dart';

/// DATOS DE USUARIO con Hive (base NoSQL clave-valor, muy rápida, sin SQL).
/// Una caja por usuario con su perfil y preferencias.
class UserDataStorage {
  static Future<void> init() => Hive.initFlutter();

  Future<Box> _box(String user) => Hive.openBox('user_$user');

  Future<Map<String, dynamic>> load(String user) async {
    final b = await _box(user);
    return {
      'name': b.get('name', defaultValue: ''),
      'email': b.get('email', defaultValue: ''),
      'phone': b.get('phone', defaultValue: ''),
      'darkMode': b.get('darkMode', defaultValue: false),
      'fontSize': b.get('fontSize', defaultValue: 16.0),
    };
  }

  Future<void> save(String user, Map<String, dynamic> data) async {
    final b = await _box(user);
    await b.putAll(data);
  }

  Future<void> clear(String user) async => (await _box(user)).clear();
}

/// CACHÉ con Hive: guarda respuestas de red con fecha de expiración (TTL).
/// Si no hay internet, se muestra la última copia guardada.
class CacheStorage {
  static const _boxName = 'cache';

  Future<Box> get _box => Hive.openBox(_boxName);

  Future<void> put(String key, String value) async =>
      (await _box).put(key, {'value': value, 'savedAt': DateTime.now().toIso8601String()});

  /// Devuelve (valor, fechaGuardado, expirado?) o null si no existe.
  Future<(String, DateTime, bool)?> get(String key, Duration ttl) async {
    final raw = (await _box).get(key);
    if (raw == null) return null;
    final saved = DateTime.parse(raw['savedAt']);
    return (raw['value'] as String, saved, DateTime.now().difference(saved) > ttl);
  }

  Future<int> clear() async => (await _box).clear();
}
