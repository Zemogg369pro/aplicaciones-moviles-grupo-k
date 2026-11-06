import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../core/errors.dart';
import '../../data/factories/demo_data.dart';
import '../../widgets/common.dart';

/// Módulo access: identifica al usuario y su rol.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  Map<String, String> _errors = {};
  bool _loading = false;

  Future<void> _submit() async {
    final scope = AppScope.of(context);
    setState(() {
      _loading = true;
      _errors = {};
    });
    try {
      await scope.services.session.login(_user.text, _pass.text);
      await scope.refreshSession();
    } on ValidationException catch (e) {
      setState(() => _errors = e.fieldErrors);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 32),
          Icon(Icons.travel_explore, size: 80, color: Theme.of(context).colorScheme.primary),
          Text('Pasaporte Cultural', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
          const Text('Descubre museos, galerías y centros culturales', textAlign: TextAlign.center),
          const SizedBox(height: 32),
          TextField(
            controller: _user,
            decoration: InputDecoration(labelText: 'Usuario', errorText: _errors['username'], prefixIcon: const Icon(Icons.person)),
            autocorrect: false,
          ),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: InputDecoration(labelText: 'Contraseña', errorText: _errors['password'], prefixIcon: const Icon(Icons.lock)),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          _loading ? const Center(child: CircularProgressIndicator()) : FilledButton(onPressed: _submit, child: const Text('Entrar')),
          const SizedBox(height: 24),
          const Text('Usuarios de prueba', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Visitante: ${DemoData.visitorUser} / ${DemoData.visitorPass}'),
          const Text('Editor: ${DemoData.editorUser} / ${DemoData.editorPass}'),
        ]),
      ),
    );
  }
}
