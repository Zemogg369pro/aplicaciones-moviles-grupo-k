import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../core/constants.dart';
import '../../data/models/place.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common.dart';

/// Detalle de un lugar: descripción, dirección, horario e imagen; marcar favorito; registrar visita.
class PlaceDetailPage extends StatefulWidget {
  final String placeId;
  const PlaceDetailPage({super.key, required this.placeId});
  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  late Future<(Place, bool)> _future;

  Future<(Place, bool)> _load() async {
    final scope = AppScope.of(context);
    final p = await scope.services.places.obtener(widget.placeId);
    return (p, await scope.services.favorites.esFavorito(scope.user!, p.id));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<void> _toggle(bool value) async {
    final scope = AppScope.of(context);
    try {
      await scope.services.favorites.establecer(scope.user, widget.placeId, value);
      if (mounted) showMessage(context, value ? 'Agregado a favoritos' : 'Quitado de favoritos');
      setState(() => _future = _load());
    } catch (e) {
      if (mounted) showMessage(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del lugar')),
      body: AsyncView<(Place, bool)>(
        future: _future,
        builder: (d) {
          final (p, fav) = d;
          return ListView(children: [
            Container(
              height: 180,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: p.image.isNotEmpty
                  ? Image.network(p.image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(categoryIcon(p.category), size: 96))
                  : Icon(categoryIcon(p.category), size: 96),
            ),
            ListTile(
              title: Text(p.name, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(Categories.label(p.category)),
              trailing: IconButton(
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                tooltip: fav ? 'Quitar de favoritos' : 'Agregar a favoritos',
                onPressed: () => _toggle(!fav),
              ),
            ),
            if (!p.active) const ListTile(leading: Icon(Icons.block, color: Colors.red), title: Text('Lugar inactivo: no acepta visitas')),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(p.description)),
            ListTile(leading: const Icon(Icons.place), title: Text(p.address), subtitle: Text(p.municipality)),
            ListTile(leading: const Icon(Icons.schedule), title: Text(p.schedule)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: p.active ? () => Navigator.pushNamed(context, AppRoutes.checkin, arguments: p.id) : null,
                icon: const Icon(Icons.verified),
                label: const Text('Registrar visita con código'),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
