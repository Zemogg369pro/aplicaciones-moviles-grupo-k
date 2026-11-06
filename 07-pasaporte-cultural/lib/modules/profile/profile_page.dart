import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common.dart';

/// Módulo profile: nombre, rol, visitas totales, lugares distintos visitados y favoritos.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = scope.services, u = scope.user!;
    return AsyncView<List<Object>>(
      future: Future.wait([s.visits.listar(u), s.visits.lugaresDistintos(u), s.favorites.listar(u)]),
      builder: (d) => ListView(padding: const EdgeInsets.all(16), children: [
        const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
        const SizedBox(height: 8),
        Text(u.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        Text('Rol: ${u.role}', textAlign: TextAlign.center),
        const Divider(),
        ListTile(leading: const Icon(Icons.verified), title: const Text('Visitas totales'), trailing: Text('${(d[0] as List).length}')),
        ListTile(leading: const Icon(Icons.place), title: const Text('Lugares distintos visitados'), trailing: Text('${d[1]}')),
        ListTile(
          leading: const Icon(Icons.favorite),
          title: const Text('Favoritos'),
          trailing: Text('${(d[2] as List).length}'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.favorites),
        ),
        if (u.isEditor)
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Administración'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, AppRoutes.admin),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await s.session.logout();
            await scope.refreshSession();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ]),
    );
  }
}
