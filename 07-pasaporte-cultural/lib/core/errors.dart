/// Tipos de error del dominio. Todos tienen un mensaje comprensible para el usuario.
sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);
  @override
  String toString() => message;
}

/// Datos de entrada inválidos (campos obligatorios, formatos, rangos).
class ValidationException extends AppException {
  final Map<String, String> fieldErrors;
  const ValidationException(super.message, [this.fieldErrors = const {}]);
}

/// El recurso solicitado no existe.
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// El usuario no tiene permiso para la operación (rol insuficiente o sin sesión).
class PermissionDeniedException extends AppException {
  const PermissionDeniedException([super.message = 'Acceso denegado: no tienes permiso para esta operación.']);
}

/// Operación repetida que la regla de negocio no permite (p. ej. visita duplicada en el día).
class DuplicateException extends AppException {
  const DuplicateException(super.message);
}

/// Credenciales incorrectas.
class AuthException extends AppException {
  const AuthException([super.message = 'Usuario o contraseña incorrectos.']);
}
