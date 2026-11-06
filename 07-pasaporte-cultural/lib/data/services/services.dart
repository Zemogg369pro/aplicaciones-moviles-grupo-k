import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../../core/dates.dart';
import '../../core/errors.dart';
import '../../core/validators.dart';
import '../models/challenge.dart';
import '../models/place.dart';
import '../models/user.dart';
import '../models/visit.dart';
import '../repositories/repositories.dart';

/// Aquí se implementan las reglas de negocio (sección 5 del encargo).

String newId() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(1 << 20)}';
String hashPassword(String p) => sha256.convert(utf8.encode(p)).toString();

/// Reloj inyectable para poder probar reglas por día.
typedef Clock = DateTime Function();

// ======================= Sesión =======================
class SessionService {
  final UsersRepository users;
  final MetaRepository meta;
  SessionService(this.users, this.meta);

  AppUser? _current;

  /// Sesion.usuarioActual() -> usuario o ausencia de sesión.
  Future<AppUser?> usuarioActual() async {
    if (_current != null) return _current;
    final id = await meta.get('sessionUserId');
    if (id == null) return null;
    _current = await users.byId(id);
    return _current;
  }

  Future<AppUser> login(String username, String password) async {
    final errs = <String, String>{};
    final u1 = Validators.required(username, 'El usuario');
    final p1 = Validators.required(password, 'La contraseña');
    if (u1 != null) errs['username'] = u1;
    if (p1 != null) errs['password'] = p1;
    if (errs.isNotEmpty) throw ValidationException('Revisa los campos marcados.', errs);
    final u = await users.byUsername(username);
    if (u == null || u.passwordHash != hashPassword(password)) throw const AuthException();
    await meta.set('sessionUserId', u.id); // la sesión se conserva al cerrar la app
    _current = u;
    return u;
  }

  Future<void> logout() async {
    _current = null;
    await meta.set('sessionUserId', null);
  }

  /// Verificación de rol en el servicio (no basta con ocultar la opción en la interfaz).
  static void requireEditor(AppUser? u) {
    if (u == null || !u.isEditor) throw const PermissionDeniedException();
  }

  static void requireUser(AppUser? u) {
    if (u == null) throw const PermissionDeniedException('Inicia sesión para continuar.');
  }
}

// ======================= Lugares =======================
class PlacesService {
  final PlacesRepository repo;
  PlacesService(this.repo);

  /// Lugares.buscar(texto, categoría, municipio) -> lugares activos
  Future<List<Place>> buscar({String texto = '', String? categoria, String? municipio}) async {
    final t = texto.trim().toLowerCase();
    final list = (await repo.all()).where((p) =>
        p.active &&
        (t.isEmpty || p.name.toLowerCase().contains(t)) &&
        (categoria == null || p.category == categoria) &&
        (municipio == null || p.municipality == municipio)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<List<String>> municipios() async =>
      ((await repo.all()).where((p) => p.active).map((p) => p.municipality).toSet().toList()..sort());

  /// Lugares.obtener(id) -> lugar o no encontrado
  Future<Place> obtener(String id) async =>
      await repo.byId(id) ?? (throw const NotFoundException('El lugar no existe.'));

  /// Todos (incluye inactivos) — solo para administración.
  Future<List<Place>> todos(AppUser? editor) async {
    SessionService.requireEditor(editor);
    return (await repo.all())..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Lugares.guardar(datos, usuarioEditor) -> lugar o error de validación/permiso
  Future<Place> guardar(Place datos, AppUser? editor) async {
    SessionService.requireEditor(editor);
    final errs = <String, String>{};
    void chk(String k, String? e) {
      if (e != null) errs[k] = e;
    }
    chk('name', Validators.required(datos.name, 'El nombre'));
    chk('category', Validators.category(datos.category));
    chk('municipality', Validators.required(datos.municipality, 'El municipio'));
    chk('address', Validators.required(datos.address, 'La dirección'));
    chk('schedule', Validators.required(datos.schedule, 'El horario'));
    chk('code', Validators.registrationCode(datos.code));
    if (errs.isEmpty) {
      final code = Validators.normalizeCode(datos.code);
      final other = await repo.byCode(code);
      if (other != null && other.id != datos.id) errs['code'] = 'Ese código ya está asignado a otro lugar.';
    }
    if (errs.isNotEmpty) throw ValidationException('Revisa los campos marcados.', errs); // no se guarda nada
    final place = datos.copyWith(name: datos.name.trim(), code: Validators.normalizeCode(datos.code));
    await repo.save(place);
    return place;
  }

  /// Lugares.desactivar(id, usuarioEditor) -> resultado (las visitas registradas se conservan)
  Future<Place> desactivar(String id, AppUser? editor, {bool activo = false}) async {
    SessionService.requireEditor(editor);
    final p = await obtener(id);
    final updated = p.copyWith(active: activo);
    await repo.save(updated);
    return updated;
  }
}

// ======================= Favoritos =======================
class FavoritesService {
  final FavoritesRepository repo;
  final PlacesRepository places;
  FavoritesService(this.repo, this.places);

  /// Favoritos.establecer(usuario, lugar, sí/no) -> resultado
  Future<bool> establecer(AppUser? usuario, String placeId, bool value) async {
    SessionService.requireUser(usuario);
    if (await places.byId(placeId) == null) throw const NotFoundException('El lugar no existe.');
    await repo.set(usuario!.id, placeId, value);
    return value;
  }

  /// Favoritos.listar(usuario) -> lugares favoritos
  Future<List<Place>> listar(AppUser? usuario) async {
    SessionService.requireUser(usuario);
    final ids = (await repo.byUser(usuario!.id)).map((f) => f.placeId).toSet();
    return (await places.all()).where((p) => ids.contains(p.id)).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<bool> esFavorito(AppUser usuario, String placeId) async =>
      (await repo.byUser(usuario.id)).any((f) => f.placeId == placeId);
}

// ======================= Visitas / Registro =======================
class VisitsService {
  final VisitsRepository visits;
  final PlacesRepository places;
  final Clock now;
  VisitsService(this.visits, this.places, {Clock? clock}) : now = clock ?? DateTime.now;

  /// Registro.registrar(usuario, lugar, código) -> visita o error
  /// Flujo: obtener lugar → comprobar activo → verificar código → buscar visita del mismo
  /// usuario, lugar y día → guardar → devolver resultado.
  Future<Visit> registrar(AppUser? usuario, String code, {String? placeId}) async {
    SessionService.requireUser(usuario);
    final codeErr = Validators.registrationCode(code);
    if (codeErr != null) throw ValidationException(codeErr, {'code': codeErr});
    final normalized = Validators.normalizeCode(code);

    final place = placeId != null ? await places.byId(placeId) : await places.byCode(normalized);
    if (place == null) throw const NotFoundException('Código desconocido: no corresponde a ningún lugar.');
    if (!place.active) throw const ValidationException('Este lugar está inactivo y no acepta visitas.');
    if (place.code != normalized) throw const ValidationException('El código no corresponde a este lugar.');

    final today = Dates.dayKey(now());
    final dup = (await visits.byUser(usuario!.id)).any((v) => v.placeId == place.id && v.dayKey == today);
    if (dup) throw DuplicateException('Ya registraste tu visita a "${place.name}" hoy.');

    final v = Visit(id: newId(), userId: usuario.id, placeId: place.id, dateTime: now());
    await visits.save(v);
    return v;
  }

  /// Visitas.listar(usuario, mes opcional) -> visitas ordenadas (fecha descendente)
  Future<List<Visit>> listar(AppUser? usuario, {String? mes}) async {
    SessionService.requireUser(usuario);
    final list = (await visits.byUser(usuario!.id)).where((v) => mes == null || Dates.monthKey(v.dateTime) == mes).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  Future<int> lugaresDistintos(AppUser usuario) async =>
      (await visits.byUser(usuario.id)).map((v) => v.placeId).toSet().length;
}

// ======================= Retos =======================
class ChallengesService {
  final ChallengesRepository repo;
  final VisitsRepository visits;
  final PlacesRepository places;
  final Clock now;
  ChallengesService(this.repo, this.visits, this.places, {Clock? clock}) : now = clock ?? DateTime.now;

  /// Retos.calcularAvance(usuario, reto) -> cantidad de lugares distintos
  /// Cuenta lugares DISTINTOS de la categoría del reto visitados dentro del periodo (días inicial y
  /// final incluidos). No supera la meta. Se calcula siempre a partir de las visitas.
  Future<int> calcularAvance(AppUser usuario, Challenge reto) async {
    final byId = {for (final p in await places.all()) p.id: p};
    final distinct = (await visits.byUser(usuario.id))
        .where((v) => byId[v.placeId]?.category == reto.category && Dates.inPeriod(v.dateTime, reto.startDate, reto.endDate))
        .map((v) => v.placeId)
        .toSet()
        .length;
    return min(distinct, reto.goal);
  }

  Future<List<ChallengeProgress>> listarConAvance(AppUser? usuario) async {
    SessionService.requireUser(usuario);
    final list = <ChallengeProgress>[];
    for (final c in await repo.all()) {
      list.add(ChallengeProgress(c, await calcularAvance(usuario!, c)));
    }
    list.sort((a, b) => a.challenge.endDate.compareTo(b.challenge.endDate));
    return list;
  }

  Future<List<ChallengeProgress>> activos(AppUser usuario) async =>
      (await listarConAvance(usuario)).where((p) => p.challenge.isCurrent(now())).toList();

  Future<List<Challenge>> todos(AppUser? editor) async {
    SessionService.requireEditor(editor);
    return (await repo.all())..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  Future<Challenge> obtener(String id) async =>
      await repo.byId(id) ?? (throw const NotFoundException('El reto no existe.'));

  /// Crear o editar reto (solo editor).
  Future<Challenge> guardar(Challenge c, AppUser? editor) async {
    SessionService.requireEditor(editor);
    final errs = <String, String>{};
    final t = Validators.required(c.title, 'El título');
    final cat = Validators.category(c.category);
    final g = Validators.positiveInt(c.goal, 'La meta');
    final d = Validators.dateRange(c.startDate, c.endDate);
    if (t != null) errs['title'] = t;
    if (cat != null) errs['category'] = cat;
    if (g != null) errs['goal'] = g;
    if (d != null) errs['dates'] = d;
    if (errs.isNotEmpty) throw ValidationException('Revisa los campos marcados.', errs);
    await repo.save(c);
    return c;
  }
}

/// Contenedor simple de dependencias.
class AppServices {
  final SessionService session;
  final PlacesService places;
  final FavoritesService favorites;
  final VisitsService visits;
  final ChallengesService challenges;

  AppServices({required this.session, required this.places, required this.favorites, required this.visits, required this.challenges});
}
