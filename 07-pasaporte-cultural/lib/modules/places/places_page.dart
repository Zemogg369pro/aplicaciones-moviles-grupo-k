import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../core/constants.dart';
import '../../data/models/place.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common.dart';

/// Módulo places: lista lugares activos, busca por nombre y filtra por categoría y municipio.
class PlacesPage extends StatefulWidget {
  final VoidCallback onChanged;
  const PlacesPage({super.key, required this.onChanged});
  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  String _text = '';
  String? _category, _municipality;
  late Future<List<Object>> _future;

  void _load() {
    final s = AppScope.of(context).services;
    _future = Future.wait([s.places.buscar(texto: _text, categoria: _category, municipio: _municipality), s.places.municipios()]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar por nombre', border: OutlineInputBorder()),
          onChanged: (v) => setState(() {
            _text = v;
            _load();
          }),
        ),
      ),
      FutureBuilder<List<Object>>(
        future: _future,
        builder: (_, s) {
          final municipios = s.hasData ? s.data![1] as List<String> : <String>[];
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              ...Categories.all.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(Categories.label(c)),
                      selected: _category == c,
                      onSelected: (v) => setState(() {
                        _category = v ? c : null;
                        _load();
                      }),
                    ),
                  )),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _municipality,
                hint: const Text('Municipio'),
                items: [const DropdownMenuItem(value: null, child: Text('Todos')), ...municipios.map((m) => DropdownMenuItem(value: m, child: Text(m)))],
                onChanged: (v) => setState(() {
                  _municipality = v;
                  _load();
                }),
              ),
            ]),
          );
        },
      ),
      Expanded(
        child: AsyncView<List<Object>>(
          future: _future,
          builder: (d) {
            final list = d[0] as List<Place>;
            if (list.isEmpty) return const EmptyState('No hay lugares que coincidan con la búsqueda o los filtros.');
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final p = list[i];
                return ListTile(
                  leading: CircleAvatar(child: Icon(categoryIcon(p.category))),
                  title: Text(p.name),
                  subtitle: Text('${Categories.label(p.category)} · ${p.municipality}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.pushNamed(context, AppRoutes.place, arguments: p.id);
                    widget.onChanged();
                  },
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}
