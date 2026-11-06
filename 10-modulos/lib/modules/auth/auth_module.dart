import 'package:flutter/material.dart';
import '../../core/module.dart';

/// MÓDULO AUTH: servicio de sesión + pantalla de acceso. Expone solo [AuthService] y la ruta /login.
class AuthService extends ChangeNotifier {
  String? _user;
  String? get user => _user;
  bool get loggedIn => _user != null;

  String? login(String name, String pass) {
    if (name.trim().isEmpty) return 'Escribe tu nombre';
    if (pass.length < 4) return 'La contraseña debe tener al menos 4 caracteres';
    _user = name.trim();
    notifyListeners();
    return null;
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}

class AuthModule extends AppModule {
  static const login = '/login';
  @override
  String get name => 'auth';
  @override
  void registerDependencies(Injector i) => i.singleton<AuthService>(() => AuthService());
  @override
  Map<String, WidgetBuilder> get routes => {login: (_) => const _LoginPage()};
}

class _LoginPage extends StatefulWidget {
  const _LoginPage();
  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _n = TextEditingController(), _p = TextEditingController();
  String? _error;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Módulo Auth')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          TextField(controller: _n, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: _p, obscureText: true, decoration: InputDecoration(labelText: 'Contraseña', errorText: _error)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final err = Injector.instance.get<AuthService>().login(_n.text, _p.text);
              if (err != null) return setState(() => _error = err);
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text('Entrar'),
          ),
        ]),
      );
}
