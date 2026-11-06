import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_scope.dart';
import '../../core/constants.dart';
import '../../data/models/challenge.dart';
import '../../widgets/common.dart';

/// Módulo challenges: retos activos y finalizados con meta, periodo, avance y estado.
class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final now = scope.services.challenges.now();
    final fmt = DateFormat('d MMM yyyy', 'es_MX');
    return AsyncView<List<ChallengeProgress>>(
      future: scope.services.challenges.listarConAvance(scope.user),
      builder: (list) {
        final active = list.where((p) => !p.challenge.isFinished(now)).toList();
        final finished = list.where((p) => p.challenge.isFinished(now)).toList();
        if (list.isEmpty) return const EmptyState('No hay retos registrados.', icon: Icons.emoji_events_outlined);
        Widget tile(ChallengeProgress p) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(p.challenge.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                    Chip(
                      label: Text(p.completed ? 'Completado' : (p.challenge.isFinished(now) ? 'No completado' : 'En progreso')),
                      backgroundColor: p.completed ? Colors.green.shade100 : null,
                    ),
                  ]),
                  Text(p.challenge.description),
                  Text('Categoría: ${Categories.label(p.challenge.category)} · Meta: ${p.challenge.goal} lugares distintos'),
                  Text('Periodo: ${fmt.format(p.challenge.startDate)} – ${fmt.format(p.challenge.endDate)}'),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: p.ratio),
                  Text('Avance: ${p.progress} de ${p.challenge.goal}'),
                ]),
              ),
            );
        return ListView(padding: const EdgeInsets.all(12), children: [
          Text('Activos', style: Theme.of(context).textTheme.titleMedium),
          if (active.isEmpty) const EmptyState('No hay retos activos.'),
          ...active.map(tile),
          const SizedBox(height: 12),
          Text('Finalizados', style: Theme.of(context).textTheme.titleMedium),
          if (finished.isEmpty) const EmptyState('No hay retos finalizados.'),
          ...finished.map(tile),
        ]);
      },
    );
  }
}
