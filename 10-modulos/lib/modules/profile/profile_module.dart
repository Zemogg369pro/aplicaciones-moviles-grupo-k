import 'package:flutter/material.dart';
import '../../core/module.dart';
import '../auth/auth_module.dart';
import '../cart/cart_module.dart';

/// MÓDULO PROFILE: solo presentación; consume servicios públicos de auth y cart.
class ProfileModule extends AppModule {
  static const route = '/profile';
  @override
  String get name => 'profile';
  @override
  void registerDependencies(Injector i) {} // no necesita servicios propios
  @override
  Map<String, WidgetBuilder> get routes => {route: (_) => const ProfilePage()};
  @override
  ModuleMenuEntry get menuEntry => const ModuleMenuEntry('Perfil', Icons.person, route);
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Injector.instance.get<AuthService>();
    final cart = Injector.instance.get<CartService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Módulo Perfil')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(leading: const Icon(Icons.person), title: Text(auth.user ?? '-'), subtitle: const Text('Usuario (módulo auth)')),
        ListTile(leading: const Icon(Icons.shopping_cart), title: Text('${cart.count} artículos'), subtitle: const Text('Carrito (módulo cart)')),
        OutlinedButton.icon(
          onPressed: () {
            auth.logout();
            cart.clear();
            Navigator.pushNamedAndRemoveUntil(context, AuthModule.login, (_) => false);
          },
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ]),
    );
  }
}
