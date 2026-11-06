import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'analyze_screen.dart';

/// Reproduce un video; al pausarlo se puede analizar el fotograma actual con IA
class VideoScreen extends StatefulWidget {
  final String videoPath;
  final bool isNew;
  const VideoScreen({super.key, required this.videoPath, this.isNew = false});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final VideoPlayerController c;
  bool extracting = false;

  @override
  void initState() {
    super.initState();
    c = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) => setState(() {}))
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _analyzeFrame() async {
    await c.pause();
    setState(() => extracting = true);
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: c.value.position.inMilliseconds,
        quality: 95,
      );
      if (bytes == null) throw Exception('No se pudo extraer el fotograma');
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => AnalyzeScreen(imageBytes: bytes, source: 'video', videoPath: widget.videoPath)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => extracting = false);
    }
  }

  String _t(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final v = c.value;
    return Scaffold(
      appBar: AppBar(title: Text(widget.isNew ? 'Video grabado' : 'Video')),
      body: !v.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(child: Center(child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(c)))),
              VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.all(12)),
              Text('${_t(v.position)} / ${_t(v.duration)}'),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  IconButton.filled(
                    iconSize: 36,
                    onPressed: () => v.isPlaying ? c.pause() : c.play(),
                    icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                  FilledButton.icon(
                    onPressed: extracting ? null : _analyzeFrame,
                    icon: extracting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.center_focus_strong),
                    label: const Text('Pausar y analizar fotograma'),
                  ),
                ]),
              ),
            ]),
    );
  }
}
