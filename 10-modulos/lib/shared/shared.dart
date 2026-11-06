import 'package:flutter/material.dart';

/// Módulo compartido: modelos y widgets que usan varios módulos (sin lógica de negocio).
class Product {
  final String id, name, category;
  final double price;
  const Product(this.id, this.name, this.category, this.price);
}

String money(double v) => '\$${v.toStringAsFixed(2)}';

class EmptyView extends StatelessWidget {
  final String text;
  const EmptyView(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, style: const TextStyle(color: Colors.grey))));
}
