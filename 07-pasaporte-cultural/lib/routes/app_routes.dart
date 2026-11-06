import 'package:flutter/material.dart';
import '../data/models/user.dart';
import '../middlewares/guards.dart';
import '../modules/access/login_page.dart';
import '../modules/admin/admin_pages.dart';
import '../modules/checkin/checkin_page.dart';
import '../modules/favorites/favorites_page.dart';
import '../modules/home/home_shell.dart';
import '../modules/places/place_detail_page.dart';

/// Destinos de la app y su relación:
///   /login  → /  (Inicio, Lugares, Pasaporte, Retos, Perfil)
///   /       → /place, /favorites, /checkin, /admin (solo editor)
///   /admin  → /admin/place, /admin/challenge
class AppRoutes {
  static const login = '/login';
  static const home = '/';
  static const place = '/place';
  static const favorites = '/favorites';
  static const checkin = '/checkin';
  static const admin = '/admin';
  static const adminPlace = '/admin/place';
  static const adminChallenge = '/admin/challenge';

  static Route<dynamic> generate(RouteSettings s, AppUser? user) {
    String? redirect;
    switch (s.name) {
      case login:
        redirect = Guards.guestOnly(user);
      case admin || adminPlace || adminChallenge:
        redirect = Guards.requireEditor(user);
      default:
        redirect = Guards.requireSession(user);
    }
    if (redirect == 'denied') return MaterialPageRoute(builder: (_) => Guards.deniedPage());
    final name = redirect ?? s.name;
    final Widget page = switch (name) {
      login => const LoginPage(),
      place => PlaceDetailPage(placeId: s.arguments as String),
      favorites => const FavoritesPage(),
      checkin => CheckinPage(placeId: s.arguments as String?),
      admin => const AdminPage(),
      adminPlace => PlaceFormPage(placeId: s.arguments as String?),
      adminChallenge => ChallengeFormPage(challengeId: s.arguments as String?),
      _ => const HomeShell(),
    };
    return MaterialPageRoute(builder: (_) => page, settings: RouteSettings(name: name, arguments: s.arguments));
  }
}
