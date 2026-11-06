import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final auth = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Icon(Icons.event_available, size: 80),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Correo'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => GetUtils.isEmail(v ?? '') ? null : 'Correo inválido',
          ),
          TextFormField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            validator: (v) => (v ?? '').isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 20),
          Obx(() => auth.loading.value
              ? const Center(child: CircularProgressIndicator())
              : FilledButton(
                  onPressed: () {
                    if (_form.currentState!.validate()) auth.login(_email.text.trim(), _pass.text);
                  },
                  child: const Text('Entrar'))),
          TextButton(onPressed: () => Get.toNamed('/register'), child: const Text('¿No tienes cuenta? Regístrate')),
        ]),
      ),
    );
  }
}

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});
  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final isAdmin = false.obs;
  final auth = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null),
          TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Correo'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => GetUtils.isEmail(v ?? '') ? null : 'Correo inválido'),
          TextFormField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña'),
              validator: (v) => (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null),
          Obx(() => SwitchListTile(
                title: const Text('Soy administrador de un establecimiento'),
                value: isAdmin.value,
                onChanged: (v) => isAdmin.value = v,
              )),
          const SizedBox(height: 12),
          Obx(() => auth.loading.value
              ? const Center(child: CircularProgressIndicator())
              : FilledButton(
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      auth.register(_name.text.trim(), _email.text.trim(), _pass.text, isAdmin.value);
                    }
                  },
                  child: const Text('Crear cuenta'))),
        ]),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final u = auth.user.value!;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
      const SizedBox(height: 12),
      Text(u.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
      Text(u.email, textAlign: TextAlign.center),
      Text('Rol: ${u.role}', textAlign: TextAlign.center),
      const SizedBox(height: 20),
      FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: auth.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión')),
    ]);
  }
}

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<NotificationsController>();
    c.markRead();
    return Obx(() => c.items.isEmpty
        ? const Center(child: Text('Sin notificaciones'))
        : ListView(
            children: c.items
                .map((n) => ListTile(
                      leading: Icon(Icons.notifications, color: n.read ? Colors.grey : Colors.indigo),
                      title: Text(n.title),
                      subtitle: Text(n.body),
                    ))
                .toList()));
  }
}
