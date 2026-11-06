import 'package:flutter/material.dart';
import '../data/models/user.dart';

/// Guardas de navegación (equivalente a middlewares):
/// - [guestOnly]: la entrada al sistema es solo sin sesión; con sesión lleva al resumen.
/// - [requireSession]: pantallas de usuario identificado.
/// - [requireEditor]: administración (además, los servicios vuelven a validar el rol).
class Guards {
  static const login = '/login';
  static const home = '/';

  static String? guestOnly(AppUser? u) => u == null ? null : home;
  static String? requireSession(AppUser? u) => u == null ? login : null;
  static String? requireEditor(AppUser? u) => u == null ? login : (u.isEditor ? null : 'denied');

  static Widget deniedPage() => Scaffold(
        appBar: AppBar(title: const Text('Acceso denegado')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Esta sección es solo para el perfil editor.', textAlign: TextAlign.center),
          ),
        ),
      );
}
