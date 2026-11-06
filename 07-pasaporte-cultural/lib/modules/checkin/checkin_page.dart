import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../widgets/common.dart';

/// Módulo checkin: recibe el código del lugar, lo valida, guarda la visita y comunica el resultado.
/// Si se abre desde un lugar, el código debe corresponder a ESE lugar.
class CheckinPage extends StatefulWidget {
  final String? placeId;
  const CheckinPage({super.key, this.placeId});
  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  final _code = TextEditingController();
  String? _error;
  String? _success;
  bool _loading = false;

  Future<void> _submit() async {
    final scope = AppScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final v = await scope.services.visits.registrar(scope.user, _code.text, placeId: widget.placeId);
      final p = await scope.services.places.obtener(v.placeId);
      setState(() => _success = '¡Visita registrada en "${p.name}"! Ya aparece en tu pasaporte.');
      _code.clear();
    } catch (e) {
      setState(() => _error = errorText(e)); // se conserva el código escrito para corregirlo
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar visita')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.qr_code_2, size: 80),
        const Text('Escribe el código que aparece en la entrada del lugar.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: 'Código del lugar', border: const OutlineInputBorder(), errorText: _error, errorMaxLines: 3),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        _loading ? const Center(child: CircularProgressIndicator()) : FilledButton(onPressed: _submit, child: const Text('Registrar')),
        if (_success != null)
          Card(
            color: Colors.green.shade50,
            child: ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: Text(_success!)),
          ),
      ]),
    );
  }
}
