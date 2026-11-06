# 10 · Módulos — Arquitectura modular en Flutter

La app está dividida en **módulos por funcionalidad**. Cada módulo registra sus dependencias y sus rutas, y opcionalmente una entrada en el menú. La app principal solo los enumera.

```
lib/
├── core/module.dart          # AppModule (contrato), ModuleRegistry, Injector (inyección de dependencias)
├── shared/shared.dart        # modelos y widgets compartidos (Product, EmptyView)
├── modules/
│   ├── auth/                 # AuthService + /login
│   ├── catalog/              # ProductRepository + /catalog   (usa CartService)
│   ├── cart/                 # CartService (ChangeNotifier) + /cart
│   └── profile/              # /profile                       (usa AuthService y CartService)
└── main.dart                 # ModuleRegistry([...]) → rutas y menú
```

## Principios aplicados
- **Alta cohesión:** todo lo de una funcionalidad (servicio, repositorio, pantallas y rutas) vive en su carpeta.
- **Bajo acoplamiento:** los módulos no crean dependencias de otros. Piden servicios públicos al `Injector`, y las pantallas privadas (por ejemplo `_LoginPage`) no se exportan.
- **Abierto a extensión:** para agregar una funcionalidad basta con crear una clase que extienda `AppModule` y añadirla a la lista en `main.dart`. El menú y las rutas se generan solos.
- **Validación de rutas:** `ModuleRegistry` detecta rutas duplicadas entre módulos.

## Ejecutar
```bash
flutter create . --project-name app_modular --platforms=android,ios
flutter run
```
