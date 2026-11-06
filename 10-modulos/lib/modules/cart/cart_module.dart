import 'package:flutter/material.dart';
import '../../core/module.dart';
import '../../shared/shared.dart';

/// MÓDULO CART: estado del carrito (ChangeNotifier) + pantalla. Expone [CartService].
class CartService extends ChangeNotifier {
  final Map<String, (Product, int)> _items = {};

  List<(Product, int)> get items => _items.values.toList();
  int get count => _items.values.fold(0, (a, e) => a + e.$2);
  double get total => _items.values.fold(0, (a, e) => a + e.$1.price * e.$2);

  void add(Product p) {
    final cur = _items[p.id];
    _items[p.id] = (p, (cur?.$2 ?? 0) + 1);
    notifyListeners();
  }

  void remove(Product p) {
    final cur = _items[p.id];
    if (cur == null) return;
    if (cur.$2 <= 1) {
      _items.remove(p.id);
    } else {
      _items[p.id] = (p, cur.$2 - 1);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

class CartModule extends AppModule {
  static const route = '/cart';
  @override
  String get name => 'cart';
  @override
  void registerDependencies(Injector i) => i.singleton<CartService>(() => CartService());
  @override
  Map<String, WidgetBuilder> get routes => {route: (_) => const CartPage()};
  @override
  ModuleMenuEntry get menuEntry => const ModuleMenuEntry('Carrito', Icons.shopping_cart, route);
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cart = Injector.instance.get<CartService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Módulo Carrito')),
      body: ListenableBuilder(
        listenable: cart,
        builder: (_, __) => cart.items.isEmpty
            ? const EmptyView('El carrito está vacío')
            : Column(children: [
                Expanded(
                  child: ListView(
                    children: cart.items
                        .map((e) => ListTile(
                              title: Text(e.$1.name),
                              subtitle: Text('${e.$2} × ${money(e.$1.price)}'),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(icon: const Icon(Icons.remove), onPressed: () => cart.remove(e.$1)),
                                IconButton(icon: const Icon(Icons.add), onPressed: () => cart.add(e.$1)),
                              ]),
                            ))
                        .toList(),
                  ),
                ),
                ListTile(title: const Text('Total'), trailing: Text(money(cart.total), style: Theme.of(context).textTheme.titleLarge)),
                Padding(padding: const EdgeInsets.all(12), child: FilledButton(onPressed: cart.clear, child: const Text('Vaciar carrito'))),
              ]),
      ),
    );
  }
}
