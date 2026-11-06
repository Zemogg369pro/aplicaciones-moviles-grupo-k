import 'constants.dart';

/// Validadores puros: devuelven `null` si el valor es válido o el mensaje de error.
class Validators {
  static String? required(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field es obligatorio.' : null;

  static String? category(String? v) =>
      Categories.all.contains(v) ? null : 'Categoría inválida.';

  /// Código de registro: 4 a 20 caracteres alfanuméricos o guion.
  static String? registrationCode(String? v) {
    final r = required(v, 'El código');
    if (r != null) return r;
    return RegExp(r'^[A-Za-z0-9-]{4,20}$').hasMatch(v!.trim())
        ? null
        : 'El código debe tener de 4 a 20 letras, números o guiones.';
  }

  static String? positiveInt(int? v, String field) =>
      (v == null || v <= 0) ? '$field debe ser un número entero mayor que cero.' : null;

  static String? dateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'Las fechas de inicio y fin son obligatorias.';
    if (start.isAfter(end)) return 'La fecha inicial no puede ser posterior a la final.';
    return null;
  }

  static String normalizeCode(String code) => code.trim().toUpperCase();
}
