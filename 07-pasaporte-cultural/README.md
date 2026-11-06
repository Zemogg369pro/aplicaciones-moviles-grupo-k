# 07 · Proyecto ampliado — Pasaporte Cultural (Flutter)

Aplicación para descubrir museos, galerías y centros culturales, marcar favoritos, registrar visitas con el código del lugar y cumplir retos. Dos perfiles: **visitante** y **editor**.

## Instalación y ejecución
```bash
flutter create . --project-name pasaporte_cultural --platforms=android,ios   # genera android/ios
flutter pub get
flutter run
flutter test          # pruebas automatizadas
flutter analyze       # análisis estático
```

## Datos de demostración
| Dato | Valor |
|---|---|
| Visitante | `visitante` / `visitante123` |
| Editor | `editor` / `editor123` |
| Código de visita válido | **`MCH-001`** (Museo de la Cultura Huasteca). Cada lugar tiene el suyo, p. ej. `GME-005`, `ECM-009` |
| Lugares | 12 (4 museos, 4 galerías, 4 centros culturales) en Tampico, Madero y Altamira |
| Retos | 3: uno activo este mes (museos), uno finalizado (galerías), uno activo más largo (centros culturales) |

La carga inicial se ejecuta una sola vez (`seed_version` en `data/factories/demo_data.dart`), así que no reinicia favoritos, visitas ni cambios en cada inicio.

## Estructura de carpetas
| Carpeta | Contenido |
|---|---|
| `lib/core` | Categorías y roles (`constants.dart`), errores del dominio (`errors.dart`), fechas (`dates.dart`) y validadores puros (`validators.dart`) |
| `lib/data/models` | Las 5 entidades: `AppUser`, `Place`, `Visit`, `Favorite`, `Challenge`, con su conversión a mapas |
| `lib/data/providers` | `StorageProvider`: `PrefsStorageProvider` para persistir en el dispositivo y `MemoryStorageProvider` para pruebas |
| `lib/data/repositories` | Consultar y guardar usuarios, lugares, visitas, favoritos y retos |
| `lib/data/services` | Sesión, registro de visitas, cálculo de retos y autorización. Aquí van las reglas de negocio |
| `lib/data/factories` | Datos de demostración |
| `lib/modules` | `access`, `home`, `places`, `favorites`, `checkin`, `passport`, `challenges`, `profile`, `admin` |
| `lib/routes` | Destinos y su relación (`app_routes.dart`) |
| `lib/middlewares` | Guardas de invitado, sesión y rol (`guards.dart`). En Flutter equivalen a middlewares de ruta |
| `lib/widgets` | Componentes compartidos: estado vacío, mensajes, vista asíncrona |
| `test` | Pruebas de reglas, persistencia, permisos y recorrido principal |

Cada pantalla de `modules` recibe las acciones del usuario y llama a un **servicio**. Los servicios aplican las reglas y usan **repositorios**, y los repositorios usan el **proveedor**. Ninguna pantalla accede directo al almacenamiento.

## Dónde está cada operación requerida
| Operación | Implementación |
|---|---|
| `Lugares.buscar / obtener / guardar / desactivar` | `PlacesService.buscar`, `obtener`, `guardar`, `desactivar` |
| `Favoritos.establecer / listar` | `FavoritesService.establecer`, `listar` |
| `Visitas.listar(usuario, mes)` | `VisitsService.listar` (orden descendente) |
| `Registro.registrar(usuario, lugar, código)` | `VisitsService.registrar`: obtener lugar → comprobar activo → verificar código → buscar visita del mismo día → guardar |
| `Retos.calcularAvance` | `ChallengesService.calcularAvance`: cuenta lugares distintos a partir de las visitas, no guarda un contador |
| `Sesión.usuarioActual` | `SessionService.usuarioActual` (la sesión se conserva al cerrar la app) |

## Decisiones técnicas
- **Persistencia:** `shared_preferences`, con tablas JSON. Los datos se conservan entre ejecuciones y no requiere servidor.
- **Mismo día:** se usa la **fecha local del dispositivo** (`Dates.dayKey`). Se permite una visita por lugar por día, y otro día sí se permite.
- **Seguridad de roles:** las rutas de administración pasan por `Guards.requireEditor`, y además cada operación de editor vuelve a validar el rol en el servicio con `SessionService.requireEditor`. Si un visitante llama a la operación directamente, recibe `PermissionDeniedException`.
- **Contraseñas:** se guardan como hash SHA-256.
- **Errores:** cada error es una excepción tipada con un mensaje comprensible. Las validaciones ocurren antes de escribir, así que no quedan datos parciales, y el formulario conserva lo capturado.
- **QR:** no es requisito. El código se escribe a mano y el diseño permite agregar un lector QR que entregue el mismo código.

## Cómo probar los dos roles (recorrido de aceptación)
1. Entra como `visitante`. En **Lugares** busca "huasteca", filtra por *Museo* y *Tampico*, abre el detalle y marca ♥.
2. Usa **Registrar visita** con el código `MCH-001`. La visita aparece en **Pasaporte** y el reto de museos sube a 1/3.
3. Repítelo el mismo día: aparece "Ya registraste tu visita… hoy" y no se crea otra fila.
4. Prueba un código inválido o de otro lugar: aparece el error y no se registra.
5. Cierra sesión y entra como `editor`. En **Perfil → Administración** crea o edita un lugar o un reto, o desactiva un lugar. El lugar desactivado desaparece del catálogo, pero sigue en el pasaporte de quien lo visitó.

## Pruebas automatizadas (`test/reglas_test.dart`)
Cubren: validación de código, duplicado diario, progreso con lugares repetidos y fechas límite, unicidad de favoritos, permiso de editor, persistencia de una operación al "reiniciar", y el recorrido completo desde el acceso hasta el registro de visita.
