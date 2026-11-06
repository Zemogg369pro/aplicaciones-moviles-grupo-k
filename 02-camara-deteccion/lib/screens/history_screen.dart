import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../storage.dart';
import '../widgets.dart';
import 'video_screen.dart';

/// Historial de fotografías y videos analizados (persistente)
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> items = [];
  String filter = 'todos';

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final l = await Storage.load();
    if (mounted) setState(() => items = l);
  }

  @override
  Widget build(BuildContext context) {
    final list = filter == 'todos' ? items : items.where((i) => i.type == filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Historial'), actions: [
        PopupMenuButton<String>(
          initialValue: filter,
          onSelected: (v) => setState(() => filter = v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'todos', child: Text('Todos')),
            PopupMenuItem(value: 'foto', child: Text('Fotografías')),
            PopupMenuItem(value: 'video', child: Text('Videos')),
          ],
          icon: const Icon(Icons.filter_list),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: reload,
        child: list.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Aún no hay análisis guardados'))])
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final it = list[i];
                  final thumb = it.framePath ?? it.path;
                  return Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(thumb), width: 56, height: 56, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                      ),
                      title: Text('${it.type == 'video' ? '🎬 Video' : '📷 Foto'} · ${it.detections.length} objetos'),
                      subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(it.date)}\n${it.summary}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      isThreeLine: true,
                      onTap: () => _detail(it),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await Storage.remove(it.id);
                          reload();
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _detail(HistoryItem it) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.all(12), children: [
          Image.file(File(it.framePath ?? it.path)),
          const SizedBox(height: 8),
          CountsView(it.detections),
          ...it.detections.map((d) => ListTile(dense: true, title: Text(d.label), trailing: Text('${(d.confidence * 100).toStringAsFixed(1)}%'))),
          Row(children: [
            if (it.type == 'video')
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(videoPath: it.path))),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Ver video'),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Share.shareXFiles([XFile(it.framePath ?? it.path)],
                    text: 'Objetos detectados: ${it.summary}'),
                icon: const Icon(Icons.share),
                label: const Text('Compartir'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
