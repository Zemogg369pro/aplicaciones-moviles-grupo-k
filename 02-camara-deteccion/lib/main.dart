import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'detector.dart';
import 'screens/camera_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartCameraApp());
}

class SmartCameraApp extends StatelessWidget {
  const SmartCameraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Cámara inteligente',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true, brightness: Brightness.dark),
        home: const PermissionGate(),
      );
}

/// Solicita permisos de cámara, micrófono y galería antes de iniciar
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});
  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool? granted;
  String status = 'Cargando modelo de IA...';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final res = await [Permission.camera, Permission.microphone, Permission.photos, Permission.storage].request();
    final ok = res[Permission.camera]!.isGranted && res[Permission.microphone]!.isGranted;
    try {
      await Detector.instance.load();
    } catch (e) {
      status = 'No se pudo cargar el modelo: $e\nRevisa assets/yolov8n.tflite (ver README).';
    }
    setState(() => granted = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (granted == null) return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(status, textAlign: TextAlign.center)])));
    if (!granted!) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.no_photography, size: 64),
              const Text('Se necesitan permisos de cámara y micrófono para usar la aplicación.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () async {
                await openAppSettings();
                setState(() => granted = null);
                _init();
              }, child: const Text('Abrir configuración')),
            ]),
          ),
        ),
      );
    }
    return const HomeShell();
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  final historyKey = GlobalKey<HistoryScreenState>();

  @override
  Widget build(BuildContext context) {
    final pages = [const CameraScreen(), const GalleryScreen(), HistoryScreen(key: historyKey), const SettingsScreen()];
    return Scaffold(
      body: IndexedStack(index: tab, children: [
        // la cámara sólo está activa cuando su pestaña es visible
        tab == 0 ? pages[0] : const SizedBox(),
        pages[1], pages[2], pages[3],
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) {
          setState(() => tab = i);
          if (i == 2) historyKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.camera_alt), label: 'Cámara'),
          NavigationDestination(icon: Icon(Icons.photo_library), label: 'Galería'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double v = Detector.instance.threshold;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ajustes de detección')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Umbral mínimo de confianza: ${(v * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: v, min: 0.1, max: 0.95, divisions: 17,
            label: '${(v * 100).toStringAsFixed(0)}%',
            onChanged: (x) => setState(() => v = x),
            onChangeEnd: Detector.instance.setThreshold,
          ),
          const Text('Sólo se mostrarán los objetos cuya confianza sea igual o mayor al umbral.'),
          const Divider(),
          const ListTile(leading: Icon(Icons.memory), title: Text('Modelo'), subtitle: Text('YOLOv8n · TensorFlow Lite · 80 clases COCO · procesamiento 100% local')),
        ]),
      );
}
