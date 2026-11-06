import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'models.dart';
import 'services/api.dart';

void showError(Object e) => Get.snackbar('Error', e.toString(),
    backgroundColor: Colors.red.shade600, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
void showOk(String msg) => Get.snackbar('Listo', msg,
    backgroundColor: Colors.green.shade600, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);

// ================= AUTH =================
class AuthController extends GetxController {
  final _box = GetStorage();
  final user = Rxn<User>();
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final raw = _box.read('user');
    if (raw != null) user.value = User.fromJson(Map.from(raw));
  }

  Future<void> _auth(String path, Map body) async {
    loading.value = true;
    try {
      final data = await Api.post(path, body);
      await _box.write('token', data['token']);
      await _box.write('user', data['user']);
      user.value = User.fromJson(data['user']);
      Get.offAllNamed(user.value!.isAdmin ? '/admin' : '/client');
    } catch (e) {
      showError(e);
    } finally {
      loading.value = false;
    }
  }

  Future<void> login(String email, String password) => _auth('/auth/login', {'email': email, 'password': password});
  Future<void> register(String name, String email, String password, bool admin) =>
      _auth('/auth/register', {'name': name, 'email': email, 'password': password, 'role': admin ? 'admin' : 'cliente'});

  Future<void> logout() async {
    await _box.erase();
    user.value = null;
    Get.find<NotificationsController>().stop();
    Get.offAllNamed('/login');
  }
}

// ================= CLIENTE: explorar =================
class ExploreController extends GetxController {
  final items = <Establishment>[].obs;
  final loading = false.obs;
  final query = ''.obs;

  @override
  void onInit() {
    super.onInit();
    debounce(query, (_) => search(), time: const Duration(milliseconds: 400));
    search();
  }

  Future<void> search() async {
    loading.value = true;
    try {
      final data = await Api.get('/establishments', {'q': query.value});
      items.assignAll((data as List).map((e) => Establishment.fromJson(e)));
    } catch (e) {
      showError(e);
    } finally {
      loading.value = false;
    }
  }
}

// ================= SERVICIOS (cliente lectura / admin CRUD) =================
class ServicesController extends GetxController {
  final items = <Service>[].obs;
  final loading = false.obs;
  String? establishmentId;

  Future<void> load(String estId) async {
    establishmentId = estId;
    loading.value = true;
    try {
      final data = await Api.get('/establishments/$estId/services');
      items.assignAll((data as List).map((e) => Service.fromJson(e)));
    } catch (e) {
      showError(e);
    } finally {
      loading.value = false;
    }
  }

  Future<bool> save({String? id, required String name, required String description, required double price, required int durationMin}) async {
    loading.value = true;
    try {
      final body = {'name': name, 'description': description, 'price': price, 'durationMin': durationMin};
      if (id == null) {
        items.add(Service.fromJson(await Api.post('/services', body)));
        showOk('Servicio agregado');
      } else {
        final s = Service.fromJson(await Api.put('/services/$id', body));
        items[items.indexWhere((x) => x.id == id)] = s;
        showOk('Servicio actualizado');
      }
      return true;
    } catch (e) {
      showError(e);
      return false;
    } finally {
      loading.value = false;
    }
  }

  Future<void> remove(String id) async {
    try {
      await Api.delete('/services/$id');
      items.removeWhere((x) => x.id == id);
      showOk('Servicio eliminado');
    } catch (e) {
      showError(e);
    }
  }
}

// ================= RESERVAR =================
class BookingController extends GetxController {
  final Service service;
  BookingController(this.service);

  final slots = <DateTime>[].obs;
  final loading = false.obs;
  final date = DateTime.now().obs;
  final selected = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    loadSlots(DateTime.now());
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> loadSlots(DateTime d) async {
    date.value = d;
    selected.value = null;
    loading.value = true;
    try {
      final data = await Api.get('/services/${service.id}/availability', {'date': _fmt(d)});
      slots.assignAll((data as List).map((s) => DateTime.parse(s).toLocal()));
    } catch (e) {
      showError(e);
    } finally {
      loading.value = false;
    }
  }

  Future<bool> book() async {
    final s = selected.value;
    if (s == null) return false;
    if (s.isBefore(DateTime.now())) {
      showError('No se puede reservar en fechas pasadas');
      return false;
    }
    loading.value = true;
    try {
      await Api.post('/reservations', {'serviceId': service.id, 'start': s.toUtc().toIso8601String()});
      slots.remove(s);
      selected.value = null;
      return true;
    } catch (e) {
      showError(e);
      await loadSlots(date.value); // refresca por si otro usuario ocupó el horario
      return false;
    } finally {
      loading.value = false;
    }
  }
}

// ================= RESERVACIONES =================
class ReservationsController extends GetxController {
  final bool admin;
  ReservationsController({this.admin = false});

  final items = <Reservation>[].obs;
  final loading = false.obs;
  final filter = 'todas'.obs;

  List<Reservation> get filtered => filter.value == 'todas' ? items : items.where((r) => r.status == filter.value).toList();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    try {
      final data = await Api.get(admin ? '/reservations/establishment' : '/reservations/mine');
      items.assignAll((data as List).map((e) => Reservation.fromJson(e)));
    } catch (e) {
      showError(e);
    } finally {
      loading.value = false;
    }
  }

  Future<void> changeStatus(Reservation r, String status) async {
    try {
      final updated = Reservation.fromJson(await Api.patch('/reservations/${r.id}/status', {'status': status}));
      items[items.indexWhere((x) => x.id == r.id)] = updated;
      showOk('Reservación $status');
    } catch (e) {
      showError(e);
    }
  }
}

// ================= ESTABLECIMIENTO (admin) =================
class EstablishmentController extends GetxController {
  final establishment = Rxn<Establishment>();
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    try {
      final data = await Api.get('/establishments/mine');
      establishment.value = data == null ? null : Establishment.fromJson(data);
      if (establishment.value != null) Get.find<ServicesController>().load(establishment.value!.id);
    } catch (e) {
      showError(e);
    } finally {
      loading.value = false;
    }
  }

  Future<void> save(Map<String, dynamic> body) async {
    loading.value = true;
    try {
      final data = establishment.value == null
          ? await Api.post('/establishments', body)
          : await Api.put('/establishments/mine', body);
      establishment.value = Establishment.fromJson(data);
      Get.find<ServicesController>().load(establishment.value!.id);
      showOk('Establecimiento guardado');
    } catch (e) {
      showError(e);
    } finally {
      loading.value = false;
    }
  }
}

// ================= NOTIFICACIONES (polling cada 15 s) =================
class NotificationsController extends GetxController {
  final items = <AppNotification>[].obs;
  int get unread => items.where((n) => !n.read).length;
  Timer? _timer;

  void start() {
    stop();
    poll();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => poll());
  }

  void stop() => _timer?.cancel();

  Future<void> poll() async {
    try {
      final data = await Api.get('/notifications');
      final list = (data as List).map((e) => AppNotification.fromJson(e)).toList();
      final known = items.map((n) => n.id).toSet();
      if (items.isNotEmpty) {
        for (final n in list.where((n) => !n.read && !known.contains(n.id))) {
          Get.snackbar('🔔 ${n.title}', n.body, snackPosition: SnackPosition.TOP);
          // Refresca listas abiertas para mantener actualizados los estados
          if (Get.isRegistered<ReservationsController>()) Get.find<ReservationsController>().load();
        }
      }
      items.assignAll(list);
    } catch (_) {/* sin conexión: reintenta en el siguiente ciclo */}
  }

  Future<void> markRead() async {
    try {
      await Api.post('/notifications/read');
      await poll();
    } catch (_) {}
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
