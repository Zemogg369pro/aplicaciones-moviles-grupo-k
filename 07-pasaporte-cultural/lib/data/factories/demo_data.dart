import '../../core/constants.dart';
import '../models/challenge.dart';
import '../models/place.dart';
import '../models/user.dart';
import '../repositories/repositories.dart';
import '../services/services.dart';

/// Datos iniciales de demostración. Se cargan UNA sola vez (marca `seed_version` en meta):
/// no reinician ni sobrescriben favoritos, visitas o cambios del usuario en cada inicio.
class DemoData {
  static const seedVersion = 1;

  /// Usuarios de prueba.
  static const visitorUser = 'visitante', visitorPass = 'visitante123';
  static const editorUser = 'editor', editorPass = 'editor123';

  /// Código de visita válido para la demostración (Museo de la Cultura Huasteca).
  static const demoCode = 'MCH-001';

  static Future<void> seedIfNeeded({
    required MetaRepository meta,
    required UsersRepository users,
    required PlacesRepository places,
    required ChallengesRepository challenges,
    DateTime? now,
  }) async {
    if ((await meta.get('seed_version') ?? 0) >= seedVersion) return;
    final today = now ?? DateTime.now();

    await users.saveAll([
      AppUser(id: 'u-visitante', name: 'Juan Diego Gómez', username: visitorUser, passwordHash: hashPassword(visitorPass), role: Roles.visitante),
      AppUser(id: 'u-editor', name: 'Editor Cultural', username: editorUser, passwordHash: hashPassword(editorPass), role: Roles.editor),
    ]);

    Place p(String id, String name, String cat, String mun, String addr, String desc, String sched, String code) => Place(
        id: id, name: name, category: cat, municipality: mun, address: addr, description: desc, schedule: sched, image: '', code: code);

    await places.saveAll([
      p('p01', 'Museo de la Cultura Huasteca', Categories.museo, 'Tampico', 'Espacio Cultural Metropolitano', 'Arqueología y cultura del pueblo huasteco.', 'Mar–Dom 10:00–17:00', demoCode),
      p('p02', 'Museo de Historia Naval', Categories.museo, 'Tampico', 'Calle Aduana s/n', 'Historia marítima del puerto.', 'Mar–Dom 9:00–17:00', 'MHN-002'),
      p('p03', 'Museo de la Ciudad', Categories.museo, 'Madero', 'Av. Álvaro Obregón 100', 'Historia de Ciudad Madero.', 'Lun–Vie 9:00–16:00', 'MCM-003'),
      p('p04', 'Museo del Ferrocarril', Categories.museo, 'Altamira', 'Antigua estación', 'Locomotoras y memoria ferroviaria.', 'Mié–Dom 10:00–18:00', 'MFA-004'),
      p('p05', 'Galería Metropolitana', Categories.galeria, 'Tampico', 'Plaza de Armas 12', 'Arte contemporáneo regional.', 'Mar–Sáb 11:00–19:00', 'GME-005'),
      p('p06', 'Galería del Puerto', Categories.galeria, 'Tampico', 'Calle Díaz Mirón 210', 'Fotografía y gráfica.', 'Jue–Dom 12:00–20:00', 'GPU-006'),
      p('p07', 'Galería Universitaria UAT', Categories.galeria, 'Tampico', 'Centro Universitario Sur', 'Exposiciones de alumnos y artistas invitados.', 'Lun–Vie 9:00–18:00', 'GUA-007'),
      p('p08', 'Galería Laguna', Categories.galeria, 'Madero', 'Blvd. Costero 45', 'Pintura y escultura.', 'Mar–Dom 10:00–18:00', 'GLA-008'),
      p('p09', 'Espacio Cultural Metropolitano (Metro)', Categories.centroCultural, 'Tampico', 'Av. Hidalgo s/n', 'Teatro, cine y talleres.', 'Lun–Dom 9:00–21:00', 'ECM-009'),
      p('p10', 'Centro Cultural Tampico', Categories.centroCultural, 'Tampico', 'Calle Colón 300', 'Talleres y presentaciones.', 'Mar–Dom 10:00–20:00', 'CCT-010'),
      p('p11', 'Casa de la Cultura de Madero', Categories.centroCultural, 'Madero', 'Calle 1o de Mayo 501', 'Danza, música y artes plásticas.', 'Lun–Sáb 9:00–20:00', 'CCM-011'),
      p('p12', 'Centro Cultural Altamira', Categories.centroCultural, 'Altamira', 'Plaza principal', 'Eventos comunitarios.', 'Mar–Dom 10:00–19:00', 'CCA-012'),
    ]);

    final m0 = DateTime(today.year, today.month, 1);
    final mEnd = DateTime(today.year, today.month + 1, 0);
    await challenges.saveAll([
      Challenge(id: 'r01', title: 'Conoce tres museos distintos este mes', description: 'Visita 3 museos diferentes.', category: Categories.museo, goal: 3, startDate: m0, endDate: mEnd),
      Challenge(id: 'r02', title: 'Ruta de galerías', description: 'Visita 2 galerías durante el periodo.', category: Categories.galeria, goal: 2, startDate: m0.subtract(const Duration(days: 60)), endDate: m0.subtract(const Duration(days: 1))),
      Challenge(id: 'r03', title: 'Explorador de centros culturales', description: 'Visita 4 centros culturales.', category: Categories.centroCultural, goal: 4, startDate: m0, endDate: mEnd.add(const Duration(days: 30))),
    ]);

    await meta.set('seed_version', seedVersion);
  }
}
