# 09 · Streams y observables (Flutter)

Una app con seis ejemplos prácticos de programación reactiva:

| # | Ejemplo | Concepto | Archivo |
|---|---|---|---|
| 1 | Cronómetro | `Stream.periodic`, `StreamSubscription` (pausar y cancelar), `BehaviorSubject` (observable que guarda su último valor) | `lib/streams.dart` → `StopwatchStream` |
| 2 | Cuenta regresiva | Generador `async*` / `yield` y estados `waiting / active / done` de `StreamBuilder` | `countdown()` |
| 3 | Búsqueda reactiva | Operadores `map`, `debounceTime`, `distinct`, `switchMap`, `shareReplay`, y manejo de errores en el stream (escribe "error") | `SearchBloc` |
| 4 | Total del carrito | `Rx.combineLatest2`: un valor derivado de dos streams | `CartBloc` |
| 5 | Contador | `ValueNotifier` + `ValueListenableBuilder` (observable simple) | `main.dart` |
| 6 | Bus de eventos | `StreamController.broadcast()` con dos suscriptores a la vez | `EventBus` |
| Extra | Tema claro/oscuro | `ChangeNotifier` + `ListenableBuilder` (patrón observador) | `ThemeObservable` |

**Buenas prácticas aplicadas:** todas las suscripciones y controladores se cierran en `dispose()` para evitar fugas de memoria. La UI solo escucha streams y la lógica vive en clases separadas, al estilo BLoC.

## Ejecutar
```bash
flutter create . --project-name streams_observables --platforms=android,ios
flutter pub get
flutter run
```
