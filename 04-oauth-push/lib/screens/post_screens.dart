import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../services/repo.dart';
import 'chat_screens.dart';

/// Crear o editar una publicación (sólo el dueño puede editar)
class PostFormScreen extends StatefulWidget {
  final Post? post;
  const PostFormScreen({super.key, this.post});
  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final _form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.post?.name);
  late final desc = TextEditingController(text: widget.post?.description);
  late final loc = TextEditingController(text: widget.post?.location);
  late String type = widget.post?.type ?? 'perdido';
  late String category = widget.post?.category ?? categories.first;
  late DateTime date = widget.post?.date ?? DateTime.now();
  File? photo;
  bool saving = false;

  Future<void> _pick(ImageSource src) async {
    final f = await ImagePicker().pickImage(source: src, maxWidth: 1280, imageQuality: 80);
    if (f != null) setState(() => photo = File(f.path));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (photo == null && widget.post?.photoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega una fotografía del objeto')));
      return;
    }
    setState(() => saving = true);
    try {
      final me = Repo.me;
      await Repo.savePost(
        Post(
          id: widget.post?.id ?? '',
          ownerId: me.uid,
          ownerName: me.displayName ?? '',
          ownerPhoto: me.photoURL ?? '',
          type: type,
          name: name.text.trim(),
          description: desc.text.trim(),
          category: category,
          location: loc.text.trim(),
          status: widget.post?.status ?? 'pendiente',
          date: date,
          photoUrl: widget.post?.photoUrl,
        ),
        photo: photo,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicación guardada')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.post == null ? 'Nueva publicación' : 'Editar publicación')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'perdido', label: Text('Lo perdí'), icon: Icon(Icons.help)),
              ButtonSegment(value: 'encontrado', label: Text('Lo encontré'), icon: Icon(Icons.check)),
            ],
            selected: {type},
            onSelectionChanged: (s) => setState(() => type = s.first),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              builder: (_) => SafeArea(
                child: Wrap(children: [
                  ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Cámara'), onTap: () { Navigator.pop(context); _pick(ImageSource.camera); }),
                  ListTile(leading: const Icon(Icons.photo), title: const Text('Galería'), onTap: () { Navigator.pop(context); _pick(ImageSource.gallery); }),
                ]),
              ),
            ),
            child: Container(
              height: 180,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: photo != null
                  ? Image.file(photo!, fit: BoxFit.cover)
                  : widget.post?.photoUrl != null
                      ? Image.network(widget.post!.photoUrl!, fit: BoxFit.cover)
                      : const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_a_photo, size: 40), Text('Agregar fotografía')])),
            ),
          ),
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Nombre del objeto'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null),
          TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Descripción (color, marca, señas)'), maxLines: 3,
              validator: (v) => (v ?? '').trim().length < 10 ? 'Describe con al menos 10 caracteres' : null),
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => category = v!),
          ),
          TextFormField(controller: loc, decoration: const InputDecoration(labelText: 'Ubicación (ej. Edificio C, Facultad de Ingeniería)'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(date)}'),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: date);
              if (d != null) setState(() => date = d);
            },
          ),
          const SizedBox(height: 16),
          saving ? const Center(child: CircularProgressIndicator()) : FilledButton(onPressed: _save, child: const Text('Guardar')),
        ]),
      ),
    );
  }
}

/// Detalle de publicación: contactar, coincidencias, editar/eliminar/marcar resuelto (dueño)
class PostDetailScreen extends StatelessWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Post?>(
      stream: Repo.post(postId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final p = snap.data;
        if (p == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('La publicación ya no existe')));
        final mine = p.ownerId == Repo.me.uid;
        return Scaffold(
          appBar: AppBar(title: Text(p.name), actions: [
            if (mine && !p.resolved)
              IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostFormScreen(post: p)))),
            if (mine)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Eliminar publicación'),
                      content: const Text('Esta acción no se puede deshacer.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await Repo.deletePost(p.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
          ]),
          body: ListView(children: [
            if (p.photoUrl != null) Image.network(p.photoUrl!, height: 260, fit: BoxFit.cover),
            ListTile(
              title: Text(p.name, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text('${p.isLost ? 'Perdido' : 'Encontrado'} · ${p.category}${p.resolved ? ' · RESUELTO' : ''}'),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(p.description)),
            ListTile(leading: const Icon(Icons.place), title: Text(p.location)),
            ListTile(leading: const Icon(Icons.event), title: Text(DateFormat("d 'de' MMMM yyyy", 'es_MX').format(p.date))),
            ListTile(
              leading: CircleAvatar(backgroundImage: p.ownerPhoto.isNotEmpty ? NetworkImage(p.ownerPhoto) : null),
              title: Text(p.ownerName),
              subtitle: const Text('Publicado por'),
            ),
            const Divider(),
            // Coincidencias detectadas automáticamente
            StreamBuilder<List<String>>(
              stream: Repo.matchesFor(p.id),
              builder: (_, ms) {
                final ids = ms.data ?? [];
                if (ids.isEmpty) return const ListTile(leading: Icon(Icons.manage_search), title: Text('Sin coincidencias por ahora'));
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.all(16), child: Text('Posibles coincidencias (${ids.length})', style: Theme.of(context).textTheme.titleMedium)),
                  ...ids.map((id) => StreamBuilder<Post?>(
                        stream: Repo.post(id),
                        builder: (_, s) => s.data == null
                            ? const SizedBox()
                            : ListTile(
                                leading: const Icon(Icons.link, color: Colors.deepOrange),
                                title: Text(s.data!.name),
                                subtitle: Text('${s.data!.type} · ${s.data!.location}'),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: id))),
                              ),
                      )),
                ]);
              },
            ),
            const SizedBox(height: 80),
          ]),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: mine
                  ? (p.resolved
                      ? const Text('Esta publicación está resuelta', textAlign: TextAlign.center)
                      : FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () => Repo.markResolved(p.id),
                          icon: const Icon(Icons.verified),
                          label: Text(p.isLost ? 'Marcar como recuperado' : 'Marcar como entregado')))
                  : FilledButton.icon(
                      onPressed: p.resolved
                          ? null
                          : () async {
                              final chatId = await Repo.openChat(p);
                              if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)));
                            },
                      icon: const Icon(Icons.chat),
                      label: Text('Contactar a ${p.ownerName.split(' ').first}')),
            ),
          ),
        );
      },
    );
  }
}
