/// Constantes generales de la aplicación.
class Categories {
  static const museo = 'museo';
  static const galeria = 'galeria';
  static const centroCultural = 'centro_cultural';

  static const all = [museo, galeria, centroCultural];

  static String label(String c) => switch (c) {
        museo => 'Museo',
        galeria => 'Galería',
        centroCultural => 'Centro cultural',
        _ => c,
      };
}

class Roles {
  static const visitante = 'visitante';
  static const editor = 'editor';
}

class StorageTables {
  static const users = 'users';
  static const places = 'places';
  static const visits = 'visits';
  static const favorites = 'favorites';
  static const challenges = 'challenges';
  static const meta = 'meta';
}
