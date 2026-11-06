import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_scope.dart';
import '../../core/constants.dart';
import '../../core/dates.dart';
import '../../data/models/place.dart';
import '../../data/models/visit.dart';
import '../../widgets/common.dart';

/// Módulo passport: visitas propias en orden descendente, filtro por mes y lugar de cada visita.
class PassportPage extends StatefulWidget {
  const PassportPage({super.key});
  @override
  State<PassportPage> createState() => _PassportPageState();
}

class _PassportPageState extends State<PassportPage> {
  String? _month;

  Future<(List<Visit>, Map<String, Place>, List<String>)> _load() async {
    final scope = AppScope.of(context);
    final s = scope.services;
    final all = await s.visits.listar(scope.user);
    final visits = _month == null ? all : await s.visits.listar(scope.user, mes: _month);
    final places = <String, Place>{};
    for (final v in all) {
      places[v.placeId] ??= await s.places.obtener(v.placeId);
    }
    final months = all.map((v) => Dates.monthKey(v.dateTime)).toSet().toList()..sort((a, b) => b.compareTo(a));
    return (visits, places, months);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("EEE d 'de' MMM yyyy, HH:mm", 'es_MX');
    return AsyncView<(List<Visit>, Map<String, Place>, List<String>)>(
      future: _load(),
      builder: (d) {
        final (visits, places, months) = d;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              const Text('Mes: '),
              DropdownButton<String?>(
                value: _month,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ...months.map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMMM yyyy', 'es_MX').format(DateTime.parse('$m-01'))))),
                ],
                onChanged: (v) => setState(() => _month = v),
              ),
              const Spacer(),
              Text('${visits.length} visita(s)'),
            ]),
          ),
          Expanded(
            child: visits.isEmpty
                ? const EmptyState('No hay visitas registradas para este filtro.', icon: Icons.book_outlined)
                : ListView.builder(
                    itemCount: visits.length,
                    itemBuilder: (_, i) {
                      final v = visits[i], p = places[v.placeId];
                      return ListTile(
                        leading: Icon(categoryIcon(p?.category ?? '')),
                        title: Text(p?.name ?? 'Lugar eliminado'),
                        subtitle: Text('${Categories.label(p?.category ?? '')} · ${fmt.format(v.dateTime.toLocal())}'),
                        trailing: const Icon(Icons.verified, color: Colors.green),
                      );
                    },
                  ),
          ),
        ]);
      },
    );
  }
}
