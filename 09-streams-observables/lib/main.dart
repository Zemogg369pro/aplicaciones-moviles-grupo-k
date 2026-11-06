import 'dart:async';
import 'package:flutter/material.dart';
import 'streams.dart';

final theme = ThemeObservable();

void main() => runApp(const StreamsApp());

class StreamsApp extends StatelessWidget {
  const StreamsApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        // Observa el ChangeNotifier: se reconstruye cuando cambia el tema
        listenable: theme,
        builder: (_, __) => MaterialApp(
          title: 'Streams y observables',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true, brightness: theme.dark ? Brightness.dark : Brightness.light),
          home: const Home(),
        ),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final stopwatch = StopwatchStream();
  final search = SearchBloc();
  final bus = EventBus();
  final cart = CartBloc();
  final counter = ValueNotifier<int>(0); // observable simple
  Stream<int>? _countdown;
  final _log = <String>[];
  late final StreamSubscription _logSub;

  @override
  void initState() {
    super.initState();
    // Suscriptor 1 del broadcast stream: guarda historial
    _logSub = bus.events.listen((e) => setState(() => _log.insert(0, e)));
  }

  @override
  void dispose() {
    _logSub.cancel(); // siempre cancelar suscripciones para evitar fugas de memoria
    stopwatch.dispose();
    search.dispose();
    bus.dispose();
    cart.dispose();
    counter.dispose();
    super.dispose();
  }

  String _fmt(int ms) => '${(ms ~/ 60000).toString().padLeft(2, '0')}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${(ms % 1000) ~/ 100}';

  Widget _section(String title, String subtitle, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Streams y observables'), actions: [
        IconButton(icon: const Icon(Icons.brightness_6), onPressed: () {
          theme.toggle();
          bus.emit('Tema cambiado');
        }),
      ]),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        // 1. Stream.periodic + BehaviorSubject
        _section('1. Cronómetro', 'Stream.periodic + BehaviorSubject + StreamBuilder', Row(children: [
          StreamBuilder<int>(
            stream: stopwatch.elapsed,
            initialData: 0,
            builder: (_, s) => Text(_fmt(s.data!), style: Theme.of(context).textTheme.headlineMedium),
          ),
          const Spacer(),
          IconButton.filled(icon: const Icon(Icons.play_arrow), onPressed: () {
            stopwatch.start();
            bus.emit('Cronómetro iniciado');
          }),
          IconButton(icon: const Icon(Icons.pause), onPressed: () {
            stopwatch.pause();
            bus.emit('Cronómetro pausado en ${_fmt(stopwatch.elapsed.value)}');
          }),
          IconButton(icon: const Icon(Icons.replay), onPressed: stopwatch.reset),
        ])),

        // 2. async* generator
        _section('2. Cuenta regresiva', 'Generador async* · estados waiting / active / done', Row(children: [
          StreamBuilder<int>(
            stream: _countdown,
            builder: (_, s) => Text(switch (s.connectionState) {
              ConnectionState.none => 'Presiona iniciar',
              ConnectionState.waiting => 'Preparando...',
              ConnectionState.active => '${s.data}',
              ConnectionState.done => '¡Despegue! 🚀',
            }, style: Theme.of(context).textTheme.headlineSmall),
          ),
          const Spacer(),
          FilledButton(onPressed: () => setState(() => _countdown = countdown(5)), child: const Text('Iniciar')),
        ])),

        // 3. Búsqueda reactiva
        _section('3. Búsqueda reactiva', 'debounceTime · distinct · switchMap · manejo de errores (escribe "error")', Column(children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar tecnología...'),
            onChanged: search.query.add,
          ),
          StreamBuilder<bool>(stream: search.loading, builder: (_, s) => s.data == true ? const LinearProgressIndicator() : const SizedBox(height: 4)),
          StreamBuilder<List<String>>(
            stream: search.results,
            builder: (_, s) {
              if (s.hasError) return Text('${s.error}', style: const TextStyle(color: Colors.red));
              if (!s.hasData) return const Text('Escribe para buscar');
              if (s.data!.isEmpty) return const Text('Sin resultados');
              return Wrap(spacing: 6, children: s.data!.map((e) => Chip(label: Text(e))).toList());
            },
          ),
        ])),

        // 4. combineLatest
        _section('4. Total del carrito', 'Rx.combineLatest2: el total depende de dos streams', Column(children: [
          StreamBuilder<int>(
            stream: cart.quantity,
            builder: (_, s) => Row(children: [
              const Text('Cantidad:'),
              IconButton(icon: const Icon(Icons.remove), onPressed: () => cart.quantity.add((s.data ?? 1) > 1 ? s.data! - 1 : 1)),
              Text('${s.data ?? 1}'),
              IconButton(icon: const Icon(Icons.add), onPressed: () => cart.quantity.add((s.data ?? 1) + 1)),
            ]),
          ),
          StreamBuilder<double>(
            stream: cart.discount,
            builder: (_, s) => Row(children: [
              Text('Descuento: ${((s.data ?? 0) * 100).round()}%'),
              Expanded(child: Slider(value: s.data ?? 0, max: 0.5, divisions: 10, onChanged: cart.discount.add)),
            ]),
          ),
          StreamBuilder<double>(
            stream: cart.total,
            builder: (_, s) => Text('Total: \$${(s.data ?? 0).toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
          ),
        ])),

        // 5. ValueNotifier
        _section('5. Contador observable', 'ValueNotifier + ValueListenableBuilder', Row(children: [
          ValueListenableBuilder<int>(valueListenable: counter, builder: (_, v, __) => Text('$v', style: Theme.of(context).textTheme.headlineMedium)),
          const Spacer(),
          FilledButton(onPressed: () {
            counter.value++;
            bus.emit('Contador = ${counter.value}');
          }, child: const Text('+1')),
        ])),

        // 6. Broadcast stream con 2 suscriptores
        _section('6. Bus de eventos', 'StreamController.broadcast: varios suscriptores escuchan los mismos eventos', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Suscriptor 2: muestra solo el último evento
            StreamBuilder<String>(stream: bus.events, builder: (_, s) => Text('Último: ${s.data ?? '-'}')),
            const Divider(),
            if (_log.isEmpty) const Text('Sin eventos todavía'),
            ..._log.take(6).map((e) => Text('• $e')),
          ],
        )),
      ]),
    );
  }
}
