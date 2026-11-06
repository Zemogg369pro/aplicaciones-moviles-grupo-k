import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_scope.dart';
import 'data/models/user.dart';
import 'data/providers/storage_provider.dart';
import 'data/services/services.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  final services = await buildServices(await PrefsStorageProvider.create());
  runApp(PasaporteApp(services: services));
}

class PasaporteApp extends StatefulWidget {
  final AppServices services;
  const PasaporteApp({super.key, required this.services});
  @override
  State<PasaporteApp> createState() => _PasaporteAppState();
}

class _PasaporteAppState extends State<PasaporteApp> {
  final _navKey = GlobalKey<NavigatorState>();
  AppUser? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Relee la sesión guardada y vuelve al inicio correspondiente.
  Future<void> _refresh() async {
    final u = await widget.services.session.usuarioActual();
    setState(() {
      _user = u;
      _loading = false;
    });
    _navKey.currentState?.pushNamedAndRemoveUntil(u == null ? AppRoutes.login : AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    return AppScope(
      services: widget.services,
      user: _user,
      refreshSession: _refresh,
      child: MaterialApp(
        title: 'Pasaporte Cultural',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navKey,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF8B1E3F), useMaterial3: true),
        initialRoute: _user == null ? AppRoutes.login : AppRoutes.home,
        onGenerateRoute: (s) => AppRoutes.generate(s, _user),
      ),
    );
  }
}
