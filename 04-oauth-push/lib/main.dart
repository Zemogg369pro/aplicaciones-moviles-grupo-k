import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/chat_screens.dart';
import 'screens/home_screen.dart';
import 'screens/post_screens.dart';
import 'services/auth_service.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // usa google-services.json / GoogleService-Info.plist
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  await initializeDateFormatting('es_MX');
  await PushService.init();
  runApp(const LostFoundApp());
  PushService.handleInitialMessage();
}

class LostFoundApp extends StatelessWidget {
  const LostFoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perdidos y Encontrados',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: AuthService.changes,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return snap.data == null ? const LoginScreen() : const HomeScreen();
        },
      ),
      onGenerateRoute: (s) {
        // Navegación desde notificaciones. Si no hay sesión, se exige login con Google.
        if (FirebaseAuth.instance.currentUser == null) return MaterialPageRoute(builder: (_) => const LoginScreen());
        switch (s.name) {
          case '/post':
            return MaterialPageRoute(builder: (_) => PostDetailScreen(postId: s.arguments as String));
          case '/chat':
            return MaterialPageRoute(builder: (_) => ChatScreen(chatId: s.arguments as String));
          case '/new':
            return MaterialPageRoute(builder: (_) => PostFormScreen(post: s.arguments as dynamic));
        }
        return null;
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool loading = false;

  Future<void> _login() async {
    setState(() => loading = true);
    try {
      await AuthService.signInWithGoogle();
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo iniciar sesión: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.travel_explore, size: 96, color: Colors.deepOrange),
              const SizedBox(height: 16),
              Text('Perdidos y Encontrados', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('Publica objetos perdidos o encontrados y recibe avisos cuando haya una posible coincidencia.', textAlign: TextAlign.center),
              const SizedBox(height: 40),
              loading
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton.icon(
                      onPressed: _login,
                      icon: const Icon(Icons.login),
                      label: const Padding(padding: EdgeInsets.all(12), child: Text('Iniciar sesión con Google')),
                    ),
            ]),
          ),
        ),
      );
}
