import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

/// 1) STREAM PERIÓDICO (single-subscription): cronómetro con pausa y reinicio.
class StopwatchStream {
  final _elapsed = BehaviorSubject<int>.seeded(0); // observable con último valor
  StreamSubscription<int>? _ticker;

  ValueStream<int> get elapsed => _elapsed.stream;
  bool get running => _ticker != null;

  void start() {
    if (running) return;
    final base = _elapsed.value;
    _ticker = Stream.periodic(const Duration(milliseconds: 100), (i) => base + (i + 1) * 100).listen(_elapsed.add);
  }

  void pause() {
    _ticker?.cancel();
    _ticker = null;
  }

  void reset() {
    pause();
    _elapsed.add(0);
  }

  void dispose() {
    pause();
    _elapsed.close();
  }
}

/// 2) GENERADOR async*: cuenta regresiva que emite valores y termina (evento "done").
Stream<int> countdown(int from) async* {
  for (var i = from; i >= 0; i--) {
    yield i;
    if (i > 0) await Future.delayed(const Duration(seconds: 1));
  }
}

/// 3) BÚSQUEDA REACTIVA con operadores: debounce, distinct, switchMap y manejo de errores.
class SearchBloc {
  static const _data = [
    'Flutter', 'Dart', 'Kotlin', 'Swift', 'React Native', 'Ionic', 'Xamarin', 'Java', 'JavaScript', 'TypeScript',
    'Python', 'Go', 'Rust', 'C#', 'Firebase', 'SQLite', 'Hive', 'GetX', 'BLoC', 'Provider', 'Riverpod', 'Streams',
  ];
  final _query = BehaviorSubject<String>.seeded('');
  late final Stream<List<String>> results;
  final _loading = BehaviorSubject<bool>.seeded(false);

  SearchBloc() {
    results = _query
        .map((q) => q.trim().toLowerCase())
        .debounceTime(const Duration(milliseconds: 400)) // espera a que el usuario deje de escribir
        .distinct() // ignora consultas repetidas
        .doOnData((_) => _loading.add(true))
        .switchMap(_search) // cancela la búsqueda anterior si llega una nueva
        .doOnData((_) => _loading.add(false))
        .shareReplay(maxSize: 1);
  }

  Sink<String> get query => _query.sink;
  Stream<bool> get loading => _loading.stream;

  Stream<List<String>> _search(String q) async* {
    await Future.delayed(const Duration(milliseconds: 300)); // simula una API
    if (q == 'error') throw Exception('Error simulado en la búsqueda');
    yield _data.where((e) => e.toLowerCase().contains(q)).toList();
  }

  void dispose() {
    _query.close();
    _loading.close();
  }
}

/// 4) BROADCAST STREAM: bus de eventos con varios suscriptores a la vez.
class EventBus {
  final _controller = StreamController<String>.broadcast();
  Stream<String> get events => _controller.stream;
  void emit(String e) => _controller.add(e);
  void dispose() => _controller.close();
}

/// 5) COMBINACIÓN de streams: un carrito cuyo total se recalcula al cambiar cantidad o descuento.
class CartBloc {
  final quantity = BehaviorSubject<int>.seeded(1);
  final discount = BehaviorSubject<double>.seeded(0);
  static const unitPrice = 149.90;

  late final Stream<double> total = Rx.combineLatest2<int, double, double>(
    quantity, discount, (q, d) => q * unitPrice * (1 - d),
  );

  void dispose() {
    quantity.close();
    discount.close();
  }
}

/// 6) OBSERVABLE con ChangeNotifier (patrón observador de Flutter).
class ThemeObservable extends ChangeNotifier {
  bool _dark = false;
  bool get dark => _dark;
  void toggle() {
    _dark = !_dark;
    notifyListeners(); // avisa a todos los observadores
  }
}
