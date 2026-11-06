import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../storage.dart';
import 'analyze_screen.dart';
import 'video_screen.dart';

/// Selección de fotos y videos desde la galería para analizarlos
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  Future<void> _pickImage(BuildContext context) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null || !context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyzeScreen(imagePath: f.path, source: 'galeria')));
  }

  Future<void> _pickVideo(BuildContext context) async {
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (f == null) return;
    final saved = await Storage.copyVideo(f.path);
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(videoPath: saved)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Analizar desde galería')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.image_search, size: 96),
            const SizedBox(height: 16),
            const Text('Selecciona una foto o un video almacenado para detectar los objetos que contiene.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: () => _pickImage(context), icon: const Icon(Icons.photo), label: const Text('Elegir fotografía')),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => _pickVideo(context), icon: const Icon(Icons.video_library), label: const Text('Elegir video')),
          ]),
        ),
      );
}
