import '../../core/constants.dart';
import '../models/challenge.dart';
import '../models/favorite.dart';
import '../models/place.dart';
import '../models/user.dart';
import '../models/visit.dart';
import '../providers/storage_provider.dart';

/// Límite entre la lógica y el proveedor concreto: obtienen y guardan entidades.
abstract class _TableRepository<T> {
  final StorageProvider storage;
  final String table;
  _TableRepository(this.storage, this.table);

  T fromMap(Map<String, dynamic> m);
  Map<String, dynamic> toMap(T e);
  String idOf(T e);

  Future<List<T>> all() async => (await storage.readTable(table)).map(fromMap).toList();

  Future<T?> byId(String id) async {
    for (final e in await all()) {
      if (idOf(e) == id) return e;
    }
    return null;
  }

  /// Inserta o reemplaza por id (una sola escritura: o se guarda todo o nada).
  Future<void> save(T entity) async {
    final list = await all();
    final i = list.indexWhere((e) => idOf(e) == idOf(entity));
    if (i >= 0) {
      list[i] = entity;
    } else {
      list.add(entity);
    }
    await storage.writeTable(table, list.map(toMap).toList());
  }

  Future<void> saveAll(List<T> entities) => storage.writeTable(table, entities.map(toMap).toList());
}

class UsersRepository extends _TableRepository<AppUser> {
  UsersRepository(StorageProvider s) : super(s, StorageTables.users);
  @override
  AppUser fromMap(Map<String, dynamic> m) => AppUser.fromMap(m);
  @override
  Map<String, dynamic> toMap(AppUser e) => e.toMap();
  @override
  String idOf(AppUser e) => e.id;

  Future<AppUser?> byUsername(String username) async {
    final u = username.trim().toLowerCase();
    for (final e in await all()) {
      if (e.username == u) return e;
    }
    return null;
  }
}

class PlacesRepository extends _TableRepository<Place> {
  PlacesRepository(StorageProvider s) : super(s, StorageTables.places);
  @override
  Place fromMap(Map<String, dynamic> m) => Place.fromMap(m);
  @override
  Map<String, dynamic> toMap(Place e) => e.toMap();
  @override
  String idOf(Place e) => e.id;

  Future<Place?> byCode(String code) async {
    for (final p in await all()) {
      if (p.code == code) return p;
    }
    return null;
  }
}

class VisitsRepository extends _TableRepository<Visit> {
  VisitsRepository(StorageProvider s) : super(s, StorageTables.visits);
  @override
  Visit fromMap(Map<String, dynamic> m) => Visit.fromMap(m);
  @override
  Map<String, dynamic> toMap(Visit e) => e.toMap();
  @override
  String idOf(Visit e) => e.id;

  Future<List<Visit>> byUser(String userId) async => (await all()).where((v) => v.userId == userId).toList();
}

class FavoritesRepository {
  final StorageProvider storage;
  FavoritesRepository(this.storage);

  Future<List<Favorite>> all() async =>
      (await storage.readTable(StorageTables.favorites)).map(Favorite.fromMap).toList();

  Future<List<Favorite>> byUser(String userId) async => (await all()).where((f) => f.userId == userId).toList();

  /// Marca o desmarca sin duplicar (la pareja usuario–lugar es única).
  Future<void> set(String userId, String placeId, bool value) async {
    final list = await all();
    list.removeWhere((f) => f.userId == userId && f.placeId == placeId);
    if (value) list.add(Favorite(userId: userId, placeId: placeId));
    await storage.writeTable(StorageTables.favorites, list.map((f) => f.toMap()).toList());
  }
}

class ChallengesRepository extends _TableRepository<Challenge> {
  ChallengesRepository(StorageProvider s) : super(s, StorageTables.challenges);
  @override
  Challenge fromMap(Map<String, dynamic> m) => Challenge.fromMap(m);
  @override
  Map<String, dynamic> toMap(Challenge e) => e.toMap();
  @override
  String idOf(Challenge e) => e.id;
}

/// Metadatos (sesión actual, versión de datos de demostración).
class MetaRepository {
  final StorageProvider storage;
  MetaRepository(this.storage);

  Future<Map<String, dynamic>> _read() async {
    final rows = await storage.readTable(StorageTables.meta);
    return rows.isEmpty ? {} : rows.first;
  }

  Future<dynamic> get(String key) async => (await _read())[key];

  Future<void> set(String key, dynamic value) async {
    final m = await _read();
    if (value == null) {
      m.remove(key);
    } else {
      m[key] = value;
    }
    await storage.writeTable(StorageTables.meta, [m]);
  }
}
