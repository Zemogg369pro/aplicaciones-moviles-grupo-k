import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../chat_store.dart';
import '../deep_links.dart';
import '../models.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String title;
  const ChatScreen({super.key, required this.conversationId, required this.title});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  late final ChatStore store;
  bool loading = true, uploading = false;
  String? error;
  Message? editing;

  @override
  void initState() {
    super.initState();
    store = context.read<ChatStore>();
    store.openConversationId = widget.conversationId;
    _load();
  }

  Future<void> _load() async {
    try {
      await store.loadMessages(widget.conversationId);
      store.markRead(widget.conversationId); // actualiza "leído" al visualizar
    } on ApiError catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Sin conexión: mostrando mensajes guardados';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    if (store.openConversationId == widget.conversationId) store.openConversationId = null;
    store.setTyping(widget.conversationId, false);
    super.dispose();
  }

  Conversation? get conv => store.conversations.where((c) => c.id == widget.conversationId).firstOrNull;

  void _send() {
    final t = ctrl.text.trim();
    if (t.isEmpty) return;
    if (editing != null) {
      store.editMessage(editing!, t);
      setState(() => editing = null);
    } else {
      store.sendMessage(widget.conversationId, text: t);
    }
    ctrl.clear();
  }

  Future<void> _attach(bool image) async {
    String? path, name;
    if (image) {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      path = f?.path;
      name = f?.name;
    } else {
      final r = await FilePicker.platform.pickFiles();
      path = r?.files.single.path;
      name = r?.files.single.name;
    }
    if (path == null) return;
    setState(() => uploading = true);
    try {
      final a = await Api.upload(path, name!); // HTTP
      store.sendMessage(widget.conversationId, attachment: Attachment.fromJson(a), text: ''); // WS notifica
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo subir: $e')));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _share() async {
    final c = conv;
    if (c == null) return;
    String link = DeepLinks.shareLinkFor(c);
    if (c.isGroup) {
      try {
        link = (await Api.get('/conversations/${c.id}/invite'))['link'];
      } catch (_) {}
    }
    await Share.share(c.isGroup ? 'Únete al grupo "${c.name}": $link' : 'Abre nuestra conversación: $link', subject: 'Enlace de chat');
  }

  void _options(Message m) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          if (m.attachment == null)
            ListTile(leading: const Icon(Icons.edit), title: const Text('Editar'), onTap: () {
              Navigator.pop(context);
              setState(() => editing = m);
              ctrl.text = m.text;
            }),
          ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Eliminar para todos'), onTap: () {
            Navigator.pop(context);
            store.deleteMessage(m);
          }),
        ]),
      ),
    );
  }

  Widget _statusIcon(String s) => switch (s) {
        'enviando' => const Icon(Icons.schedule, size: 14),
        'enviado' => const Icon(Icons.check, size: 14),
        'entregado' => const Icon(Icons.done_all, size: 14),
        'leido' => const Icon(Icons.done_all, size: 14, color: Colors.blue),
        _ => const SizedBox(),
      };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ChatStore>();
    final list = s.messages[widget.conversationId] ?? [];
    final c = conv;
    final me = s.me!.id;
    final other = c?.other(me);
    final typingNames = s.typing[widget.conversationId]?.values.toList() ?? [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });

    String subtitle;
    if (typingNames.isNotEmpty) {
      subtitle = c?.isGroup == true ? '${typingNames.join(', ')} está escribiendo…' : 'escribiendo…';
    } else if (c?.isGroup == true) {
      subtitle = '${c!.members.length} participantes · ${c.members.where((m) => m.online).length} en línea';
    } else if (other != null) {
      subtitle = other.online ? 'En línea' : (other.lastSeen == null ? 'Desconectado' : 'Últ. vez ${DateFormat('dd/MM HH:mm').format(other.lastSeen!)}');
    } else {
      subtitle = '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c?.name ?? widget.title),
          Text(subtitle, style: TextStyle(fontSize: 12, color: typingNames.isNotEmpty ? Colors.green : null)),
        ]),
        actions: [
          IconButton(tooltip: 'Compartir enlace', icon: const Icon(Icons.share), onPressed: _share),
          if (c != null && c.pendingRequests.isNotEmpty)
            IconButton(
              icon: Badge(label: Text('${c.pendingRequests.length}'), child: const Icon(Icons.person_add)),
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => ListView(
                  children: c.pendingRequests.map((u) => ListTile(
                        title: Text(u.name),
                        subtitle: const Text('Solicita unirse'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.close), onPressed: () async {
                            await Api.post('/conversations/${c.id}/requests/${u.id}', {'accept': false});
                            await s.loadConversations();
                            if (context.mounted) Navigator.pop(context);
                          }),
                          IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () async {
                            await Api.post('/conversations/${c.id}/requests/${u.id}', {'accept': true});
                            await s.loadConversations();
                            if (context.mounted) Navigator.pop(context);
                          }),
                        ]),
                      )).toList(),
                ),
              ),
            ),
        ],
      ),
      body: Column(children: [
        if (s.conn != ConnState.conectado)
          Container(width: double.infinity, color: Colors.orange, padding: const EdgeInsets.all(4),
              child: const Text('Reconectando… los mensajes se enviarán al recuperar la conexión', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12))),
        if (error != null) MaterialBanner(content: Text(error!), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Volver'))]),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final mine = m.senderId == me;
                    final showDate = i == 0 || !DateUtils.isSameDay(list[i - 1].createdAt, m.createdAt);
                    return Column(children: [
                      if (showDate)
                        Padding(padding: const EdgeInsets.all(8), child: Chip(label: Text(DateFormat('EEEE d MMM yyyy').format(m.createdAt)))),
                      Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: mine && !m.deleted && m.status != 'enviando' ? () => _options(m) : null,
                          onTap: m.status == 'enviando' && mine ? () => store.retry(m) : null,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.all(10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(
                              color: mine ? Colors.indigo.shade100 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (c?.isGroup == true && !mine) Text(m.senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                              if (m.deleted)
                                const Text('🚫 Mensaje eliminado', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
                              else ...[
                                if (m.attachment != null) _attachmentView(m.attachment!),
                                if (m.text.isNotEmpty) Text(m.text),
                              ],
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                if (m.editedAt != null && !m.deleted) const Text('editado · ', style: TextStyle(fontSize: 10)),
                                Text(DateFormat('HH:mm').format(m.createdAt), style: const TextStyle(fontSize: 10)),
                                if (mine) ...[const SizedBox(width: 4), _statusIcon(m.status)],
                              ]),
                            ]),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
        ),
        if (typingNames.isNotEmpty)
          Padding(padding: const EdgeInsets.only(left: 12), child: Align(alignment: Alignment.centerLeft,
              child: Text('${typingNames.join(', ')} está escribiendo…', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.green)))),
        if (editing != null)
          ListTile(dense: true, leading: const Icon(Icons.edit), title: const Text('Editando mensaje'),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() => editing = null); ctrl.clear(); })),
        if (uploading) const LinearProgressIndicator(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              PopupMenuButton<bool>(
                icon: const Icon(Icons.attach_file),
                onSelected: _attach,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: true, child: ListTile(leading: Icon(Icons.image), title: Text('Imagen'))),
                  PopupMenuItem(value: false, child: ListTile(leading: Icon(Icons.insert_drive_file), title: Text('Archivo'))),
                ],
              ),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Mensaje', border: OutlineInputBorder(), isDense: true),
                  onChanged: (v) => store.setTyping(widget.conversationId, v.isNotEmpty),
                ),
              ),
              IconButton.filled(onPressed: _send, icon: Icon(editing != null ? Icons.check : Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _attachmentView(Attachment a) {
    final url = Api.absolute(a.url);
    if (a.isImage) {
      return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, height: 180, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)));
    }
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.insert_drive_file),
        const SizedBox(width: 6),
        Flexible(child: Text(a.name, style: const TextStyle(decoration: TextDecoration.underline))),
      ]),
    );
  }
}
