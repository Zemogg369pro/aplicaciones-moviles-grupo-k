import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../core/constants.dart';
import '../../data/models/place.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common.dart';

/// Módulo favorites: consulta y quita lugares de la lista personal.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<Place>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _future = scope.services.favorites.listar(scope.user);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis favoritos')),
      body: AsyncView<List<Place>>(
        future: _future,
        builder: (list) => list.isEmpty
            ? const EmptyState('Aún no tienes favoritos. Márcalos desde el detalle de un lugar.', icon: Icons.favorite_border)
            : ListView(
                children: list
                    .map((p) => ListTile(
                          leading: Icon(categoryIcon(p.category)),
                          title: Text(p.name),
                          subtitle: Text('${Categories.label(p.category)} · ${p.municipality}${p.active ? '' : ' · inactivo'}'),
                          onTap: () => Navigator.pushNamed(context, AppRoutes.place, arguments: p.id),
                          trailing: IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            tooltip: 'Quitar',
                            onPressed: () async {
                              await scope.services.favorites.establecer(scope.user, p.id, false);
                              setState(() => _future = scope.services.favorites.listar(scope.user));
                            },
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}
