/// Manejo común de fechas.
///
/// Criterio de "mismo día" (regla 3): se usa la **fecha local del dispositivo**
/// (zona horaria del teléfono). Dos visitas son del mismo día si su `dayKey` coincide.
class Dates {
  /// Clave del día en hora local: `yyyy-MM-dd`.
  static String dayKey(DateTime d) {
    final l = d.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  /// Clave del mes en hora local: `yyyy-MM`.
  static String monthKey(DateTime d) => dayKey(d).substring(0, 7);

  /// Inicio del día local.
  static DateTime startOfDay(DateTime d) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  /// `true` si [d] está dentro del periodo [start]..[end], incluidos los días inicial y final.
  static bool inPeriod(DateTime d, DateTime start, DateTime end) {
    final k = dayKey(d);
    return k.compareTo(dayKey(start)) >= 0 && k.compareTo(dayKey(end)) <= 0;
  }
}
