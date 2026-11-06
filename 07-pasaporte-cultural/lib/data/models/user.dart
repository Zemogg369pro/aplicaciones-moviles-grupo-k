import '../../core/constants.dart';

/// Usuario del sistema. Rol `visitante` o `editor`. Tiene visitas y favoritos.
class AppUser {
  final String id;
  final String name;
  final String username;
  final String passwordHash; // SHA-256, nunca la contraseña en claro
  final String role;

  const AppUser({required this.id, required this.name, required this.username, required this.passwordHash, required this.role});

  bool get isEditor => role == Roles.editor;

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'], name: m['name'], username: m['username'], passwordHash: m['passwordHash'], role: m['role']);

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'username': username, 'passwordHash': passwordHash, 'role': role};
}
