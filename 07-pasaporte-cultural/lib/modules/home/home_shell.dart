import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../widgets/common.dart';
import '../../routes/app_routes.dart';
import '../challenges/challenges_page.dart';
import '../passport/passport_page.dart';
import '../places/places_page.dart';
import '../profile/profile_page.dart';

/// Contenedor con navegación inferior.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  int _version = 0; // fuerza recarga de datos al volver de otras pantallas

  void refresh() => setState(() => _version++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      SummaryPage(key: ValueKey('s$_version'), onChanged: refresh),
      PlacesPage(key: ValueKey('p$_version'), onChanged: refresh),
      PassportPage(key: ValueKey('v$_version')),
      ChallengesPage(key: ValueKey('c$_version')),
      ProfilePage(key: ValueKey('f$_version')),
    ];
    const titles = ['Inicio', 'Lugares', 'Mi pasaporte', 'Retos', 'Perfil'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: pages[_tab],
      floatingActionButton: _tab <= 2
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.pushNamed(context, AppRoutes.checkin);
                refresh();
              },
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Registrar visita'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          _version++;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.museum), label: 'Lugares'),
          NavigationDestination(icon: Icon(Icons.book), label: 'Pasaporte'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Retos'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

/// Módulo home: nombre, lugares distintos visitados, favoritos y hasta tres retos activos.
class SummaryPage extends StatelessWidget {
  final VoidCallback onChanged;
  const SummaryPage({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = scope.services, u = scope.user!;
    final data = Future.wait([s.visits.lugaresDistintos(u), s.favorites.listar(u), s.challenges.activos(u)]);
    return AsyncView<List<Object>>(
      future: data,
      builder: (d) {
        final distinct = d[0] as int, favs = (d[1] as List).length;
        final active = (d[2] as List).cast<dynamic>().take(3).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Hola, ${u.name}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Stat('Lugares distintos', '$distinct', Icons.place)),
            Expanded(
              child: InkWell(
                onTap: () async {
                  await Navigator.pushNamed(context, AppRoutes.favorites);
                  onChanged();
                },
                child: _Stat('Favoritos', '$favs', Icons.favorite),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Retos activos', style: Theme.of(context).textTheme.titleMedium),
          if (active.isEmpty) const EmptyState('No hay retos activos en este momento.', icon: Icons.emoji_events_outlined),
          ...active.map((p) => Card(
                child: ListTile(
                  title: Text(p.challenge.title),
                  subtitle: LinearProgressIndicator(value: p.ratio),
                  trailing: Text('${p.progress}/${p.challenge.goal}'),
                ),
              )),
        ]);
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ]),
        ),
      );
}
