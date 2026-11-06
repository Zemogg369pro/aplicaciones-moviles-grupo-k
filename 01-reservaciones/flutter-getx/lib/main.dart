import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'controllers.dart';
import 'views/auth_views.dart';
import 'views/client_views.dart';
import 'views/admin_views.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await initializeDateFormatting('es_MX');
  Get.put(AuthController(), permanent: true);
  Get.put(NotificationsController(), permanent: true);
  runApp(const ReservacionesApp());
}

class ReservacionesApp extends StatelessWidget {
  const ReservacionesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final user = auth.user.value;
    return GetMaterialApp(
      title: 'Reservaciones GetX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      initialRoute: user == null ? '/login' : (user.isAdmin ? '/admin' : '/client'),
      getPages: [
        GetPage(name: '/login', page: () => const LoginView()),
        GetPage(name: '/register', page: () => const RegisterView()),
        GetPage(
          name: '/client',
          page: () => const ClientHomeView(),
          binding: BindingsBuilder(() {
            Get.find<NotificationsController>().start();
            Get.put(ExploreController());
            Get.put(ReservationsController());
          }),
        ),
        GetPage(name: '/establishment', page: () => const EstablishmentDetailView()),
        GetPage(name: '/booking', page: () => const BookingView()),
        GetPage(
          name: '/admin',
          page: () => const AdminHomeView(),
          binding: BindingsBuilder(() {
            Get.find<NotificationsController>().start();
            Get.put(ServicesController());
            Get.put(EstablishmentController());
            Get.put(ReservationsController(admin: true));
          }),
        ),
        GetPage(name: '/service-form', page: () => const ServiceFormView()),
      ],
    );
  }
}
