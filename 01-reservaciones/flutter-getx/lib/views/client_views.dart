import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers.dart';
import '../models.dart';
import 'auth_views.dart';

final dateFmt = DateFormat("EEE d MMM yyyy, HH:mm", 'es_MX');
final hourFmt = DateFormat('HH:mm');
const statusColors = {
  'pendiente': Colors.orange,
  'confirmada': Colors.blue,
  'cancelada': Colors.red,
  'finalizada': Colors.green,
};

Widget statusChip(String s) => Chip(
    label: Text(s.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11)),
    backgroundColor: statusColors[s],
    visualDensity: VisualDensity.compact);

class ClientHomeView extends StatelessWidget {
  const ClientHomeView({super.key});
  @override
  Widget build(BuildContext context) {
    final tab = 0.obs;
    final notif = Get.find<NotificationsController>();
    const pages = [ExploreTab(), MyReservationsTab(), NotificationsTab(), ProfileTab()];
    const titles = ['Explorar', 'Mis citas', 'Notificaciones', 'Perfil'];
    return Obx(() => Scaffold(
          appBar: AppBar(title: Text(titles[tab.value])),
          body: pages[tab.value],
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab.value,
            onDestinationSelected: (i) => tab.value = i,
            destinations: [
              const NavigationDestination(icon: Icon(Icons.search), label: 'Explorar'),
              const NavigationDestination(icon: Icon(Icons.event), label: 'Mis citas'),
              NavigationDestination(
                  icon: Badge(isLabelVisible: notif.unread > 0, label: Text('${notif.unread}'), child: const Icon(Icons.notifications)),
                  label: 'Avisos'),
              const NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        ));
  }
}

class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ExploreController>();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar establecimiento o servicio', border: OutlineInputBorder()),
          onChanged: (v) => c.query.value = v,
        ),
      ),
      Expanded(
        child: Obx(() {
          if (c.loading.value && c.items.isEmpty) return const Center(child: CircularProgressIndicator());
          if (c.items.isEmpty) return const Center(child: Text('No se encontraron establecimientos'));
          return RefreshIndicator(
            onRefresh: c.search,
            child: ListView(
              children: c.items
                  .map((e) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.store),
                          title: Text(e.name),
                          subtitle: Text('${e.description}\n${e.address} · ${e.openTime}-${e.closeTime}'),
                          isThreeLine: true,
                          onTap: () => Get.toNamed('/establishment', arguments: e),
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

class EstablishmentDetailView extends StatelessWidget {
  const EstablishmentDetailView({super.key});
  @override
  Widget build(BuildContext context) {
    final Establishment e = Get.arguments;
    final c = Get.put(ServicesController(), tag: e.id)..load(e.id);
    return Scaffold(
      appBar: AppBar(title: Text(e.name)),
      body: Obx(() {
        if (c.loading.value) return const Center(child: CircularProgressIndicator());
        return ListView(padding: const EdgeInsets.all(12), children: [
          Text(e.description),
          Text('Horario: ${e.openTime} - ${e.closeTime}', style: const TextStyle(color: Colors.grey)),
          const Divider(),
          if (c.items.isEmpty) const Center(child: Text('Este establecimiento aún no tiene servicios')),
          ...c.items.map((s) => Card(
                child: ListTile(
                  title: Text(s.name),
                  subtitle: Text('${s.description}\n\$${s.price.toStringAsFixed(2)} · ${s.durationMin} min'),
                  isThreeLine: true,
                  trailing: FilledButton(onPressed: () => Get.toNamed('/booking', arguments: s), child: const Text('Reservar')),
                ),
              )),
        ]);
      }),
    );
  }
}

class BookingView extends StatelessWidget {
  const BookingView({super.key});
  @override
  Widget build(BuildContext context) {
    final Service s = Get.arguments;
    final c = Get.put(BookingController(s), tag: s.id);
    final days = List.generate(14, (i) => DateTime.now().add(Duration(days: i)));
    return Scaffold(
      appBar: AppBar(title: Text('Reservar ${s.name}')),
      body: Column(children: [
        ListTile(title: Text(s.name), subtitle: Text('${s.durationMin} min · \$${s.price.toStringAsFixed(2)}')),
        SizedBox(
          height: 60,
          child: Obx(() => ListView(
                scrollDirection: Axis.horizontal,
                children: days.map((d) {
                  final sel = DateUtils.isSameDay(d, c.date.value);
                  return Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                      label: Text(DateFormat('EEE d MMM', 'es_MX').format(d)),
                      selected: sel,
                      onSelected: (_) => c.loadSlots(d),
                    ),
                  );
                }).toList(),
              )),
        ),
        Expanded(
          child: Obx(() {
            if (c.loading.value) return const Center(child: CircularProgressIndicator());
            if (c.slots.isEmpty) return const Center(child: Text('No hay horarios disponibles este día'));
            return GridView.count(
              crossAxisCount: 4,
              padding: const EdgeInsets.all(8),
              childAspectRatio: 2,
              children: c.slots
                  .map((t) => Padding(
                        padding: const EdgeInsets.all(4),
                        child: ChoiceChip(
                          label: Text(hourFmt.format(t)),
                          selected: c.selected.value == t,
                          onSelected: (_) => c.selected.value = t,
                        ),
                      ))
                  .toList(),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() => FilledButton(
                onPressed: c.selected.value == null || c.loading.value
                    ? null
                    : () async {
                        final ok = await Get.dialog<bool>(AlertDialog(
                          title: const Text('Confirmar reservación'),
                          content: Text('${s.name}\n${dateFmt.format(c.selected.value!)}\n\$${s.price.toStringAsFixed(2)}'),
                          actions: [
                            TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancelar')),
                            FilledButton(onPressed: () => Get.back(result: true), child: const Text('Reservar')),
                          ],
                        ));
                        if (ok == true && await c.book()) {
                          Get.find<ReservationsController>().load();
                          Get.back();
                          showOk('Tu reservación quedó registrada');
                        }
                      },
                child: const Text('Reservar horario'),
              )),
        ),
      ]),
    );
  }
}

class MyReservationsTab extends StatelessWidget {
  const MyReservationsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ReservationsController>();
    return Obx(() {
      if (c.loading.value && c.items.isEmpty) return const Center(child: CircularProgressIndicator());
      return RefreshIndicator(
        onRefresh: c.load,
        child: c.items.isEmpty
            ? ListView(children: const [SizedBox(height: 100), Center(child: Text('Aún no tienes reservaciones'))])
            : ListView(
                children: c.items
                    .map((r) => Card(
                          child: ListTile(
                            title: Text('${r.service?.name} — ${r.establishment?.name}'),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${dateFmt.format(r.start)} a ${hourFmt.format(r.end)}'),
                              statusChip(r.status),
                            ]),
                            trailing: r.isActive && r.start.isAfter(DateTime.now())
                                ? IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                    tooltip: 'Cancelar',
                                    onPressed: () => Get.defaultDialog(
                                      title: 'Cancelar cita',
                                      middleText: '¿Seguro que deseas cancelar?',
                                      textCancel: 'No',
                                      textConfirm: 'Sí, cancelar',
                                      onConfirm: () {
                                        Get.back();
                                        c.changeStatus(r, 'cancelada');
                                      },
                                    ),
                                  )
                                : null,
                          ),
                        ))
                    .toList(),
              ),
      );
    });
  }
}
