import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'chat_store.dart';
import 'models.dart';
import 'screens/chat_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Maneja enlaces https://chat.ejemplo.com/chat/{id} y /join/{code}
/// (también chatapp://chat/{id} para pruebas) con la app abierta, en segundo plano o cerrada.
class DeepLinks {
  static final _appLinks = AppLinks();
  static Uri? pending; // enlace recibido antes de iniciar sesión
  static StreamSubscription? _sub;

  static Future<void> init(ChatStore store) async {
    // App cerrada: el enlace que la abrió
    final initial = await _appLinks.getInitialLink();
    if (initial != null) pending = initial;
    // App abierta o en segundo plano
    _sub ??= _appLinks.uriLinkStream.listen((uri) {
      pending = uri;
      process(store);
    });
  }

  static String shareLinkFor(Conversation c) => c.link ?? 'https://chat.ejemplo.com/chat/${c.id}';

  /// Procesa el enlace pendiente. Si no hay sesión se conserva y se procesa después del login.
  static Future<void> process(ChatStore store) async {
    final uri = pending;
    if (uri == null) return;
    if (!store.loggedIn) {
      _snack('Inicia sesión para abrir el enlace');
      return; // se procesará en cuanto el usuario se autentique
    }
    pending = null;
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments : [uri.host, ...uri.pathSegments]; // https vs chatapp://
    final parts = seg.where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return _invalid('El enlace no es válido');

    try {
      if (parts[0] == 'chat') {
        // valida existencia y permisos antes de abrir
        final c = Conversation.fromJson(await Api.get('/conversations/${parts[1]}'));
        _open(store, c);
      } else if (parts[0] == 'join') {
        final r = await Api.post('/join/${parts[1]}');
        if (r['status'] == 'requested') {
          _dialog('Solicitud enviada', 'El administrador de "${r['groupName']}" debe aprobar tu ingreso.');
        } else {
          final c = Conversation.fromJson(r['conversation']);
          await store.loadConversations();
          _open(store, c);
        }
      } else {
        _invalid('El enlace no es válido');
      }
    } on ApiError catch (e) {
      if (e.status == 404) {
        _invalid('La conversación no existe o el enlace es inválido');
      } else if (e.status == 403) {
        _invalid('No tienes permiso para ver esta conversación privada');
      } else {
        _invalid(e.message);
      }
    } catch (_) {
      _invalid('No se pudo abrir el enlace (¿sin conexión?)');
    }
  }

  static void _open(ChatStore store, Conversation c) {
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ChatScreen(conversationId: c.id, title: c.name)));
  }

  static void _invalid(String msg) => _dialog('Enlace no disponible', msg);

  static void _dialog(String title, String msg) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(context: ctx, builder: (_) => AlertDialog(title: Text(title), content: Text(msg), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aceptar')),
    ]));
  }

  static void _snack(String msg) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }
}
