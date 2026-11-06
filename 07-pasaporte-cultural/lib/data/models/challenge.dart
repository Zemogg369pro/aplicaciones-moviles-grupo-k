import '../../core/dates.dart';

/// Reto. El progreso NO se guarda: se calcula a partir de las visitas.
class Challenge {
  final String id;
  final String title;
  final String description;
  final String category;
  final int goal; // cantidad de lugares distintos
  final DateTime startDate;
  final DateTime endDate;
  final bool active;

  const Challenge({
    required this.id, required this.title, required this.description, required this.category,
    required this.goal, required this.startDate, required this.endDate, this.active = true,
  });

  /// Vigente hoy (activo y dentro del periodo).
  bool isCurrent(DateTime now) => active && Dates.inPeriod(now, startDate, endDate);

  /// Finalizado: inactivo o su periodo ya terminó.
  bool isFinished(DateTime now) => !active || Dates.dayKey(now).compareTo(Dates.dayKey(endDate)) > 0;

  Challenge copyWith({String? title, String? description, String? category, int? goal, DateTime? startDate,
          DateTime? endDate, bool? active}) =>
      Challenge(
        id: id, title: title ?? this.title, description: description ?? this.description,
        category: category ?? this.category, goal: goal ?? this.goal, startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate, active: active ?? this.active,
      );

  factory Challenge.fromMap(Map<String, dynamic> m) => Challenge(
        id: m['id'], title: m['title'], description: m['description'] ?? '', category: m['category'],
        goal: m['goal'], startDate: DateTime.parse(m['startDate']), endDate: DateTime.parse(m['endDate']),
        active: m['active'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'title': title, 'description': description, 'category': category, 'goal': goal,
        'startDate': startDate.toIso8601String(), 'endDate': endDate.toIso8601String(), 'active': active,
      };
}

/// Resultado del cálculo de avance de un reto para un usuario.
class ChallengeProgress {
  final Challenge challenge;
  final int progress; // nunca supera la meta
  const ChallengeProgress(this.challenge, this.progress);
  bool get completed => progress >= challenge.goal;
  double get ratio => challenge.goal == 0 ? 0 : progress / challenge.goal;
}
