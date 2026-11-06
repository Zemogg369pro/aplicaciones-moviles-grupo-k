import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/errors.dart';

/// Estado vacío claro para consultas sin datos.
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ]),
        ),
      );
}

IconData categoryIcon(String c) => switch (c) {
      Categories.museo => Icons.account_balance,
      Categories.galeria => Icons.palette,
      _ => Icons.theater_comedy,
    };

void showMessage(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
  ));
}

String errorText(Object e) => e is AppException ? e.message : 'Ocurrió un error inesperado. Intenta de nuevo.';

/// Constructor genérico para futuros con carga, error y vacío.
class AsyncView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  const AsyncView({super.key, required this.future, required this.builder});
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: future,
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return EmptyState(errorText(s.error!), icon: Icons.error_outline);
          return builder(s.data as T);
        },
      );
}
