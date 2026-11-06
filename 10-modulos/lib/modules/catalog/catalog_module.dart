import 'package:flutter/material.dart';
import '../../core/module.dart';
import '../../shared/shared.dart';
import '../cart/cart_module.dart';

/// MÓDULO CATALOG: repositorio de productos + listado. Usa el CartService del módulo cart
/// a través del inyector (no crea dependencias propias de otro módulo).
abstract class ProductRepository {
  List<Product> all();
}

class InMemoryProductRepository implements ProductRepository {
  @override
  List<Product> all() => const [
        Product('p1', 'Audífonos Bluetooth', 'Audio', 599),
        Product('p2', 'Cargador rápido 20W', 'Accesorios', 249),
        Product('p3', 'Funda para celular', 'Accesorios', 149),
        Product('p4', 'Bocina portátil', 'Audio', 899),
        Product('p5', 'Power bank 10000 mAh', 'Energía', 459),
        Product('p6', 'Cable USB‑C 2 m', 'Accesorios', 99),
      ];
}

class CatalogModule extends AppModule {
  static const route = '/catalog';
  @override
  String get name => 'catalog';
  @override
  void registerDependencies(Injector i) => i.singleton<ProductRepository>(() => InMemoryProductRepository());
  @override
  Map<String, WidgetBuilder> get routes => {route: (_) => const CatalogPage()};
  @override
  ModuleMenuEntry get menuEntry => const ModuleMenuEntry('Catálogo', Icons.store, route);
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String? _cat;
  @override
  Widget build(BuildContext context) {
    final products = Injector.instance.get<ProductRepository>().all();
    final cart = Injector.instance.get<CartService>();
    final cats = products.map((p) => p.category).toSet();
    final list = products.where((p) => _cat == null || p.category == _cat).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Módulo Catálogo')),
      body: Column(children: [
        Wrap(spacing: 6, children: [
          ChoiceChip(label: const Text('Todos'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
          ...cats.map((c) => ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c))),
        ]),
        Expanded(
          child: ListView(
            children: list
                .map((p) => ListTile(
                      title: Text(p.name),
                      subtitle: Text('${p.category} · ${money(p.price)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart),
                        onPressed: () {
                          cart.add(p);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.name} agregado al carrito')));
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
      ]),
    );
  }
}
