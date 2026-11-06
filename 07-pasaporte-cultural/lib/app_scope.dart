import 'package:flutter/widgets.dart';
import 'data/factories/demo_data.dart';
import 'data/models/user.dart';
import 'data/providers/storage_provider.dart';
import 'data/repositories/repositories.dart';
import 'data/services/services.dart';

/// Construye todas las dependencias a partir de un proveedor de almacenamiento.
Future<AppServices> buildServices(StorageProvider storage, {Clock? clock}) async {
  final users = UsersRepository(storage), places = PlacesRepository(storage), visits = VisitsRepository(storage);
  final favs = FavoritesRepository(storage), challenges = ChallengesRepository(storage), meta = MetaRepository(storage);
  await DemoData.seedIfNeeded(meta: meta, users: users, places: places, challenges: challenges);
  return AppServices(
    session: SessionService(users, meta),
    places: PlacesService(places),
    favorites: FavoritesService(favs, places),
    visits: VisitsService(visits, places, clock: clock),
    challenges: ChallengesService(challenges, visits, places, clock: clock),
  );
}

/// Expone los servicios y el usuario en sesión a todo el árbol de widgets.
class AppScope extends InheritedWidget {
  final AppServices services;
  final AppUser? user;
  final Future<void> Function() refreshSession;

  const AppScope({super.key, required this.services, required this.user, required this.refreshSession, required super.child});

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => old.user?.id != user?.id || old.services != services;
}
