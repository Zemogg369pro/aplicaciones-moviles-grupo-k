import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/screens.dart';
import 'storage/app_info_db.dart';
import 'storage/session_storage.dart';
import 'storage/user_data_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserDataStorage.init();
  final session = SessionStorage(await SharedPreferences.getInstance());
  await AppInfoDb.log('app_abierta', user: session.currentUser);
  runApp(StorageApp(session: session));
}

class StorageApp extends StatefulWidget {
  final SessionStorage session;
  const StorageApp({super.key, required this.session});
  @override
  State<StorageApp> createState() => _StorageAppState();
}

class _StorageAppState extends State<StorageApp> {
  bool _dark = false;

  Future<void> _applyTheme() async {
    final u = widget.session.currentUser;
    final d = u == null ? false : (await UserDataStorage().load(u))['darkMode'] as bool;
    if (mounted) setState(() => _dark = d);
  }

  @override
  void initState() {
    super.initState();
    _applyTheme();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Almacenamiento local',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true, brightness: _dark ? Brightness.dark : Brightness.light),
        home: widget.session.currentUser == null
            ? LoginScreen(session: widget.session, onDone: () {
                setState(() {});
                _applyTheme();
              })
            : HomeScreen(session: widget.session, onLogout: () => setState(() {}), onThemeChanged: _applyTheme),
      );
}
