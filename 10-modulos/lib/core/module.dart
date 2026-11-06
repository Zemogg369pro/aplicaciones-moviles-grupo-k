import 'package:flutter/material.dart';

/// Contenedor de dependencias (inyección simple). Cada módulo registra sus propios servicios.
class Injector {
  Injector._();
  static final instance = Injector._();
  final _factories = <Type, Object Function()>{};
  final _singletons = <Type, Object>{};

  void singleton<T extends Object>(T Function() create) => _factories[T] = create;

  T get<T extends Object>() {
    final s = _singletons[T];
    if (s != null) return s as T;
    final f = _factories[T];
    if (f == null) throw StateError('Dependencia $T no registrada. ¿Olvidaste registrar su módulo?');
    return (_singletons[T] = f()) as T;
  }
}

/// Contrato que cumple cada módulo: nombre, dependencias, rutas y (opcional) acceso en el menú.
abstract class AppModule {
  String get name;
  void registerDependencies(Injector i);
  Map<String, WidgetBuilder> get routes;
  ModuleMenuEntry? get menuEntry => null;
}

class ModuleMenuEntry {
  final String label;
  final IconData icon;
  final String route;
  const ModuleMenuEntry(this.label, this.icon, this.route);
}

/// Registro central: une los módulos sin que se conozcan entre sí.
class ModuleRegistry {
  final List<AppModule> modules;
  ModuleRegistry(this.modules) {
    for (final m in modules) {
      m.registerDependencies(Injector.instance);
    }
  }

  Map<String, WidgetBuilder> get routes {
    final all = <String, WidgetBuilder>{};
    for (final m in modules) {
      for (final r in m.routes.entries) {
        assert(!all.containsKey(r.key), 'Ruta duplicada ${r.key} en el módulo ${m.name}');
        all[r.key] = r.value;
      }
    }
    return all;
  }

  List<ModuleMenuEntry> get menu => modules.map((m) => m.menuEntry).whereType<ModuleMenuEntry>().toList();
}
