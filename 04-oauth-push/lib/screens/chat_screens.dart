import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../services/repo.dart';
import 'post_screens.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final me = Repo.me.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Conversaciones')),
      body: StreamBuilder<List<Chat>>(
        stream: Repo.myChats(),
        builder: (_, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.isEmpty) return const Center(child: Text('Aún no tienes conversaciones'));
          return ListView(
            children: snap.data!.map((c) {
              final other = c.otherId(me);
              final unread = ((c.unread[me] ?? 0) as num).toInt();
              final photo = c.photos[other] as String?;
              return ListTile(
                leading: CircleAvatar(backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null),
                title: Text('${c.names[other] ?? 'Usuario'} · ${c.postName}'),
                subtitle: Text(c.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: unread > 0 ? Badge(label: Text('$unread')) : null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: c.id))),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ctrl = TextEditingController();
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Repo.markRead(widget.chatId).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final me = Repo.me.uid;
    return StreamBuilder<Chat>(
      stream: Repo.chat(widget.chatId),
      builder: (context, cs) {
        if (cs.hasError) return Scaffold(appBar: AppBar(), body: const Center(child: Text('No tienes acceso a esta conversación')));
        if (!cs.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final chat = cs.data!;
        final other = chat.otherId(me);
        return Scaffold(
          appBar: AppBar(
            title: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${chat.names[other] ?? 'Usuario'}'),
              subtitle: Text(chat.postName),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: chat.postId))),
            ),
          ),
          body: Column(children: [
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: Repo.messages(chat.id),
                builder: (_, ms) {
                  final list = ms.data ?? [];
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
                    Repo.markRead(chat.id).catchError((_) {});
                  });
                  return ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      final mine = m.senderId == me;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.all(10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(m.text),
                            Text(m.createdAt == null ? 'enviando…' : DateFormat('HH:mm').format(m.createdAt!), style: const TextStyle(fontSize: 10)),
                          ]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Escribe un mensaje', border: OutlineInputBorder()))),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final t = ctrl.text.trim();
                      if (t.isEmpty) return;
                      ctrl.clear();
                      Repo.send(chat, t);
                    },
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}
