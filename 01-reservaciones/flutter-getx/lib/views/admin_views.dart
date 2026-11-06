import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers.dart';
import '../models.dart';
import 'auth_views.dart';
import 'client_views.dart';

class AdminHomeView extends StatelessWidget {
  const AdminHomeView({super.key});
  @override
  Widget build(BuildContext context) {
    final tab = 0.obs;
    final notif = Get.find<NotificationsController>();
    const pages = [EstablishmentTab(), ServicesTab(), AdminReservationsTab(), NotificationsTab(), ProfileTab()];
    const titles = ['Mi establecimiento', 'Servicios', 'Reservaciones', 'Notificaciones', 'Perfil'];
    return Obx(() => Scaffold(
          appBar: AppBar(title: Text(titles[tab.value])),
          body: pages[tab.value],
          floatingActionButton: tab.value == 1 ? FloatingActionButton(onPressed: () => Get.toNamed('/service-form'), child: const Icon(Icons.add)) : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab.value,
            onDestinationSelected: (i) => tab.value = i,
            destinations: [
              const NavigationDestination(icon: Icon(Icons.store), label: 'Negocio'),
              const NavigationDestination(icon: Icon(Icons.design_services), label: 'Servicios'),
              const NavigationDestination(icon: Icon(Icons.event_note), label: 'Citas'),
              NavigationDestination(
                  icon: Badge(isLabelVisible: notif.unread > 0, label: Text('${notif.unread}'), child: const Icon(Icons.notifications)),
                  label: 'Avisos'),
              const NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        ));
  }
}

class EstablishmentTab extends StatefulWidget {
  const EstablishmentTab({super.key});
  @override
  State<EstablishmentTab> createState() => _EstablishmentTabState();
}

class _EstablishmentTabState extends State<EstablishmentTab> {
  final c = Get.find<EstablishmentController>();
  final _form = GlobalKey<FormState>();
  final name = TextEditingController(), desc = TextEditingController(), address = TextEditingController();
  final open = TextEditingController(text: '09:00'), close = TextEditingController(text: '18:00');
  final days = <int>{1, 2, 3, 4, 5, 6}.obs;
  static const dayNames = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  Worker? _w;

  void _fill(Establishment? e) {
    if (e == null) return;
    name.text = e.name;
    desc.text = e.description;
    address.text = e.address;
    open.text = e.openTime;
    close.text = e.closeTime;
    days.assignAll(e.days);
  }

  @override
  void initState() {
    super.initState();
    _fill(c.establishment.value);
    _w = ever(c.establishment, _fill);
  }

  @override
  void dispose() {
    _w?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? hv(String? v) => _hhmm.hasMatch(v ?? '') ? null : 'Formato HH:MM';
    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Obx(() => Text(c.establishment.value == null ? 'Registra tu establecimiento' : 'Edita tu establecimiento',
            style: Theme.of(context).textTheme.titleLarge)),
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) => (v ?? '').isEmpty ? 'Requerido' : null),
        TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Descripción'), maxLines: 2),
        TextFormField(controller: address, decoration: const InputDecoration(labelText: 'Dirección')),
        Row(children: [
          Expanded(child: TextFormField(controller: open, decoration: const InputDecoration(labelText: 'Abre'), validator: hv)),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(controller: close, decoration: const InputDecoration(labelText: 'Cierra'), validator: hv)),
        ]),
        const SizedBox(height: 12),
        const Text('Días de atención'),
        Obx(() => Wrap(
              spacing: 6,
              children: List.generate(7, (i) => FilterChip(
                    label: Text(dayNames[i]),
                    selected: days.contains(i),
                    onSelected: (v) => v ? days.add(i) : days.remove(i),
                  )),
            )),
        const SizedBox(height: 16),
        Obx(() => c.loading.value
            ? const Center(child: CircularProgressIndicator())
            : FilledButton(
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  if (open.text.compareTo(close.text) >= 0) return showError('La hora de cierre debe ser posterior a la de apertura');
                  c.save({
                    'name': name.text.trim(),
                    'description': desc.text.trim(),
                    'address': address.text.trim(),
                    'openTime': open.text,
                    'closeTime': close.text,
                    'days': days.toList()..sort(),
                  });
                },
                child: const Text('Guardar'))),
      ]),
    );
  }
}

class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ServicesController>();
    final est = Get.find<EstablishmentController>();
    return Obx(() {
      if (est.establishment.value == null) return const Center(child: Text('Primero registra tu establecimiento'));
      if (c.loading.value && c.items.isEmpty) return const Center(child: CircularProgressIndicator());
      if (c.items.isEmpty) return const Center(child: Text('Sin servicios. Agrega uno con +'));
      return ListView(
        children: c.items
            .map((s) => Card(
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text('\$${s.price.toStringAsFixed(2)} · ${s.durationMin} min\n${s.description}'),
                    isThreeLine: true,
                    onTap: () => Get.toNamed('/service-form', arguments: s),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => Get.defaultDialog(
                          title: 'Eliminar',
                          middleText: '¿Eliminar "${s.name}"?',
                          textCancel: 'No',
                          textConfirm: 'Eliminar',
                          onConfirm: () {
                            Get.back();
                            c.remove(s.id);
                          }),
                    ),
                  ),
                ))
            .toList(),
      );
    });
  }
}

class ServiceFormView extends StatefulWidget {
  const ServiceFormView({super.key});
  @override
  State<ServiceFormView> createState() => _ServiceFormViewState();
}

class _ServiceFormViewState extends State<ServiceFormView> {
  final Service? s = Get.arguments;
  final c = Get.find<ServicesController>();
  final _form = GlobalKey<FormState>();
  late final name = TextEditingController(text: s?.name);
  late final desc = TextEditingController(text: s?.description);
  late final price = TextEditingController(text: s?.price.toString());
  late final dur = TextEditingController(text: (s?.durationMin ?? 30).toString());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s == null ? 'Nuevo servicio' : 'Editar servicio')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => (v ?? '').isEmpty ? 'Requerido' : null),
          TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Descripción'), maxLines: 2),
          TextFormField(controller: price, decoration: const InputDecoration(labelText: 'Precio', prefixText: '\$'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Precio inválido' : null),
          TextFormField(controller: dur, decoration: const InputDecoration(labelText: 'Duración (min)'),
              keyboardType: TextInputType.number,
              validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Duración inválida' : null),
          const SizedBox(height: 16),
          Obx(() => c.loading.value
              ? const Center(child: CircularProgressIndicator())
              : FilledButton(
                  onPressed: () async {
                    if (!_form.currentState!.validate()) return;
                    final ok = await c.save(
                        id: s?.id,
                        name: name.text.trim(),
                        description: desc.text.trim(),
                        price: double.parse(price.text),
                        durationMin: int.parse(dur.text));
                    if (ok) Get.back();
                  },
                  child: const Text('Guardar'))),
        ]),
      ),
    );
  }
}

class AdminReservationsTab extends StatelessWidget {
  const AdminReservationsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ReservationsController>();
    return Column(children: [
      SizedBox(
        height: 56,
        child: Obx(() => ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              children: ['todas', 'pendiente', 'confirmada', 'finalizada', 'cancelada']
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(label: Text(f), selected: c.filter.value == f, onSelected: (_) => c.filter.value = f),
                      ))
                  .toList(),
            )),
      ),
      Expanded(
        child: Obx(() {
          final list = c.filtered;
          if (c.loading.value && c.items.isEmpty) return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(
            onRefresh: c.load,
            child: list.isEmpty
                ? ListView(children: const [SizedBox(height: 100), Center(child: Text('Sin reservaciones'))])
                : ListView(
                    children: list
                        .map((r) => Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${r.service?.name} — ${r.client.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${dateFmt.format(r.start)} a ${hourFmt.format(r.end)}'),
                                  statusChip(r.status),
                                  Wrap(spacing: 8, children: [
                                    if (r.status == 'pendiente')
                                      FilledButton(onPressed: () => c.changeStatus(r, 'confirmada'), child: const Text('Confirmar')),
                                    if (r.status == 'confirmada')
                                      FilledButton(
                                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                          onPressed: () => c.changeStatus(r, 'finalizada'),
                                          child: const Text('Finalizar')),
                                    if (r.isActive)
                                      OutlinedButton(onPressed: () => c.changeStatus(r, 'cancelada'), child: const Text('Cancelar')),
                                  ]),
                                ]),
                              ),
                            ))
                        .toList(),
                  ),
          );
        }),
      ),
    ]);
  }
}
