import 'package:flutter/material.dart';
import 'core/module.dart';
import 'modules/auth/auth_module.dart';
import 'modules/cart/cart_module.dart';
import 'modules/catalog/catalog_module.dart';
import 'modules/profile/profile_module.dart';

/// La app solo conoce la lista de módulos. Agregar o quitar una funcionalidad
/// es agregar o quitar un módulo aquí.
final registry = ModuleRegistry([AuthModule(), CatalogModule(), CartModule(), ProfileModule()]);

void main() => runApp(const ModularApp());

class ModularApp extends StatelessWidget {
  const ModularApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'App modular',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        initialRoute: AuthModule.login,
        routes: {'/': (_) => const ShellPage(), ...registry.routes},
      );
}

/// Menú principal construido a partir de los módulos registrados.
class ShellPage extends StatelessWidget {
  const ShellPage({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Injector.instance.get<AuthService>();
    final cart = Injector.instance.get<CartService>();
    return Scaffold(
      appBar: AppBar(title: Text('Hola, ${auth.user ?? ''}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Módulos cargados: ${registry.modules.map((m) => m.name).join(', ')}'),
        const SizedBox(height: 12),
        ...registry.menu.map((e) => Card(
              child: ListTile(
                leading: Icon(e.icon),
                title: Text(e.label),
                trailing: e.route == CartModule.route
                    ? ListenableBuilder(listenable: cart, builder: (_, __) => Badge(label: Text('${cart.count}'), isLabelVisible: cart.count > 0))
                    : const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, e.route),
              ),
            )),
      ]),
    );
  }
}
