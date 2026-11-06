import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_cultural/app_scope.dart';
import 'package:pasaporte_cultural/core/constants.dart';
import 'package:pasaporte_cultural/core/errors.dart';
import 'package:pasaporte_cultural/data/factories/demo_data.dart';
import 'package:pasaporte_cultural/data/models/challenge.dart';
import 'package:pasaporte_cultural/data/models/place.dart';
import 'package:pasaporte_cultural/data/providers/storage_provider.dart';
import 'package:pasaporte_cultural/data/services/services.dart';

/// Pruebas automatizadas mínimas del encargo (sección 8).
void main() {
  late MemoryStorageProvider storage;
  late AppServices s;
  late DateTime now;

  Future<AppServices> build() => buildServices(storage, clock: () => now);

  setUp(() async {
    storage = MemoryStorageProvider();
    now = DateTime.now();
    s = await build();
  });

  Future<dynamic> visitor() => s.session.login(DemoData.visitorUser, DemoData.visitorPass);
  Future<dynamic> editor() => s.session.login(DemoData.editorUser, DemoData.editorPass);

  test('Datos de demostración: 12 lugares en 3 categorías, 3 retos, 2 usuarios', () async {
    final places = await s.places.buscar();
    expect(places.length, 12);
    expect(places.map((p) => p.category).toSet(), Categories.all.toSet());
    final e = await editor();
    expect((await s.challenges.todos(e)).length, 3);
  });

  test('La carga inicial no sobrescribe datos existentes al reiniciar', () async {
    final u = await visitor();
    await s.favorites.establecer(u, 'p01', true);
    await s.visits.registrar(u, DemoData.demoCode);
    s = await build(); // simula reinicio de la app
    final u2 = await s.session.usuarioActual(); // la sesión se conserva
    expect(u2?.id, u.id);
    expect((await s.favorites.listar(u2)).length, 1);
    expect((await s.visits.listar(u2)).length, 1);
  });

  test('Validación de código: código inválido o de otro lugar no registra visita', () async {
    final u = await visitor();
    expect(() => s.visits.registrar(u, 'NOEXISTE'), throwsA(isA<NotFoundException>()));
    expect(() => s.visits.registrar(u, ''), throwsA(isA<ValidationException>()));
    expect(() => s.visits.registrar(u, 'MHN-002', placeId: 'p01'), throwsA(isA<ValidationException>()));
    expect(await s.visits.listar(u), isEmpty);
  });

  test('Duplicado diario: misma visita el mismo día falla y no crea otra fila', () async {
    final u = await visitor();
    await s.visits.registrar(u, DemoData.demoCode);
    await expectLater(s.visits.registrar(u, DemoData.demoCode), throwsA(isA<DuplicateException>()));
    expect((await s.visits.listar(u)).length, 1);
  });

  test('Mismo lugar en días diferentes: historial conserva ambas, el reto cuenta un lugar', () async {
    final u = await visitor();
    final base = DateTime.now();
    now = DateTime(base.year, base.month, 1, 10);
    await s.visits.registrar(u, DemoData.demoCode);
    now = DateTime(base.year, base.month, 2, 10);
    await s.visits.registrar(u, DemoData.demoCode);
    expect((await s.visits.listar(u)).length, 2);
    final reto = (await s.challenges.listarConAvance(u)).firstWhere((p) => p.challenge.id == 'r01');
    expect(reto.progress, 1);
  });

  test('Progreso con lugares distintos y fechas límite (inicio y fin incluidos), sin superar la meta', () async {
    final e = await editor();
    final start = DateTime(2026, 10, 1), end = DateTime(2026, 10, 31);
    final reto = await s.challenges.guardar(
        Challenge(id: 'rt', title: 'Octubre', description: '', category: Categories.museo, goal: 2, startDate: start, endDate: end), e);
    final u = await visitor();
    now = DateTime(2026, 10, 1, 9); // día inicial
    await s.visits.registrar(u, 'MCH-001');
    now = DateTime(2026, 10, 31, 20); // día final
    await s.visits.registrar(u, 'MHN-002');
    now = DateTime(2026, 11, 1, 9); // fuera del periodo
    await s.visits.registrar(u, 'MCM-003');
    expect(await s.challenges.calcularAvance(u, reto), 2);
    now = DateTime(2026, 10, 15);
    final reto1 = reto.copyWith(goal: 1);
    expect(await s.challenges.calcularAvance(u, reto1), 1); // no supera la meta
  });

  test('Unicidad de favoritos: marcar dos veces no duplica; quitar elimina', () async {
    final u = await visitor();
    await s.favorites.establecer(u, 'p02', true);
    await s.favorites.establecer(u, 'p02', true);
    expect((await s.favorites.listar(u)).length, 1);
    await s.favorites.establecer(u, 'p02', false);
    expect(await s.favorites.listar(u), isEmpty);
  });

  test('Permiso de editor: el visitante recibe acceso denegado; el editor crea y modifica', () async {
    final u = await visitor();
    final nuevo = Place(id: 'pX', name: 'Museo X', category: Categories.museo, municipality: 'Tampico', address: 'Calle 1',
        description: '', schedule: '9-5', image: '', code: 'MX-100');
    expect(() => s.places.guardar(nuevo, u), throwsA(isA<PermissionDeniedException>()));
    expect(() => s.places.desactivar('p01', u), throwsA(isA<PermissionDeniedException>()));
    final e = await editor();
    await s.places.guardar(nuevo, e);
    await s.places.guardar(nuevo.copyWith(name: 'Museo X editado'), e);
    s = await build(); // persistencia de una operación
    expect((await s.places.obtener('pX')).name, 'Museo X editado');
  });

  test('Validación: campos obligatorios y código duplicado no guardan datos parciales', () async {
    final e = await editor();
    final malo = Place(id: 'pY', name: '', category: Categories.museo, municipality: '', address: '', description: '',
        schedule: '', image: '', code: 'MCH-001');
    await expectLater(s.places.guardar(malo, e), throwsA(isA<ValidationException>()));
    expect(() => s.places.obtener('pY'), throwsA(isA<NotFoundException>()));
    final reto = Challenge(id: 'bad', title: 'x', description: '', category: Categories.museo, goal: 0,
        startDate: DateTime(2026, 2, 1), endDate: DateTime(2026, 1, 1));
    await expectLater(s.challenges.guardar(reto, e), throwsA(isA<ValidationException>()));
  });

  test('Lugar desactivado: sale del catálogo, no acepta visitas, sigue en el historial', () async {
    final u = await visitor();
    await s.visits.registrar(u, DemoData.demoCode);
    final e = await editor();
    await s.places.desactivar('p01', e);
    expect((await s.places.buscar()).any((p) => p.id == 'p01'), isFalse);
    final u2 = await visitor();
    now = now.add(const Duration(days: 1));
    expect(() => s.visits.registrar(u2, DemoData.demoCode), throwsA(isA<ValidationException>()));
    expect((await s.visits.listar(u2)).single.placeId, 'p01');
  });

  test('Recorrido completo: acceso → buscar → favorito → registrar visita → pasaporte y reto', () async {
    final u = await visitor();
    final museos = await s.places.buscar(texto: 'huasteca', categoria: Categories.museo, municipio: 'Tampico');
    expect(museos.single.id, 'p01');
    await s.favorites.establecer(u, museos.single.id, true);
    final v = await s.visits.registrar(u, DemoData.demoCode);
    expect((await s.visits.listar(u)).first.id, v.id);
    final activos = await s.challenges.activos(u);
    expect(activos.firstWhere((p) => p.challenge.id == 'r01').progress, 1);
    expect(await s.places.buscar(texto: 'zzz'), isEmpty); // estado vacío
  });
}
