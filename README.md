# NovaTech Personal

App del personal de NovaTech (operario, transportista, gerente y administrador), para **Android,
iOS y web** desde el mismo código. Solo se escribe
usuario y contraseña; todo lo demás se toca, se escanea o se elige. El servidor devuelve el rol al
iniciar sesión y la app abre la parte que corresponde, con su propia navegación inferior.

| Fase | Estado | Qué trae |
|---|---|---|
| P1 | ✅ | Base, tema, login con huella y navegación por rol. |
| P2 | ✅ | Todo lo que hace el **operario**. |
| P3 | ✅ | Todo lo que hace el **transportista**. |
| P4 | ✅ | **Gerencia** y **administración**, y pulido de interfaces según el documento de diseño. |

## Correr la app

```
flutter pub get
flutter test
flutter run
```

Por defecto usa el backend publicado (`https://novatech-backend.vercel.app`). Para probar contra tu
computador desde el emulador Android:

```
flutter run --dart-define=API_URL=http://10.0.2.2:8000
```

## Identidad visual

Sigue `NovaTech_Diseno_de_interfaces.pdf` (versión 1.0):

- **Logo oficial** en `assets/img/`: vertical (texto negro) en el login, horizontal blanco en la
  pantalla de carga y la espiral sola en el menú de la cuenta. El ícono de la app y el nombre
  visible («NovaTech») están en Android e iOS.
- **Encabezado** azul marino con el rol arriba y el título grande, y las cuatro franjas de la marca
  (rojo, naranja, verde y azul) debajo.
- **Tarjetas** grises con borde suave, **insignias** de estado de color («Registrado», «En ruta»,
  «Por recibir»…), botones grandes abajo y controles − / + en lugar de teclado.
- **Navegación inferior** según el rol. Los colores y estilos están en `lib/core/tema/tema.dart` y los
  componentes reutilizables en `lib/core/widgets/`.

## P2 · Operario

Pestañas: **Tareas · Recepción · Mi jornada**.

| Pantalla | Qué hace |
|---|---|
| Mis tareas (inicio) | Jornada de hoy en el encabezado. «Alistando» con barra de avance arriba; la cola (más antiguos primero) con «Tomar tarea» abajo; acceso a la mercancía por recibir. Aviso «tu jornada termina en N minutos» en los últimos 10 min; al llegar la hora de salida, la sesión se cierra sola. |
| Alistamiento | Cada producto con su avance y − / +. La cámara lee el QR o el código de barras (el **SKU**); cada lectura suma una unidad. Lo contado se conserva si sales y vuelves. «Listo para envío» solo se activa con todo completo. |
| Recepción de mercancía | Compras aprobadas → contar «en buen estado» y «dañadas» con −10, −1, +1, +10. Si todo coincide se crea el lote; si no, queda «con diferencias» para gerencia. |
| Mi jornada | Entrada real, salida configurada con la barra del día, horas extra con su estado y «Solicitar horas extra» eligiendo día, hora y motivo. |

**Probar con datos:** crea un pedido con una cuenta cliente desde Swagger y genera un QR con el
**SKU** del producto. Para recibir mercancía, sugiere y aprueba una compra (`/compras/generar`,
`/compras/{id}/aprobar`).

## P3 · Transportista

Pestañas: **Entregas · Ruta · Liquidación**.

| Pantalla | Qué hace |
|---|---|
| Entregas de hoy (inicio) | Paradas numeradas con su estado y los paquetes «Por recibir» de la zona de envíos. «Recibir paquete (escanear QR)» y, con paquetes recibidos, «Iniciar ruta». Mientras hay entregas en ruta comparte la ubicación cada 30 s (con la app abierta). |
| Ruta | Mapa (OpenStreetMap) con las paradas en orden, «Siguiente parada» con tiempo y distancia, y «Navegar» (abre Google Maps). |
| Confirmar entrega | Datos de la parada, cámara para el QR que muestra el cliente y verificación «GPS coincide con la dirección guardada» (a menos de 300 m). |
| Mi liquidación | Pendiente, pagado y total, y el detalle de cada entrega con tarifa y comisión. |

**Probar con datos:** el QR del paquete lleva el **código del pedido** (`PED-0007`); el de entrega es
el `qr_entrega` que muestra la app del cliente. Si se niega el GPS, todo funciona y la ruta se
calcula desde la bodega.

## P4 · Gerente

Pestañas: **Panel · Aprobar · Inventario · Stats · Energía**.

| Pantalla | Qué hace |
|---|---|
| Panel del día | Pedidos hoy, % a tiempo, stock bajo y por aprobar. Avisos de mercancía atrasada, recepciones con diferencias, jornadas con salida no registrada y transportistas en ruta. Accesos a horas extra y energía. |
| Aprobaciones | Con un toque: compras sugeridas (quedan / mínimo / sugerido), solicitudes de horas extra y recepciones con diferencias («Aceptar buenas» o «Descartar»). La aprobación es un registro interno, no se envía al proveedor. |
| Inventario | Todo el catálogo: productos, unidades, valor en bodega (a costo) y stock bajo. Filtros con toques (stock bajo, agotados, categoría) y orden por nombre, menor stock o mayor valor. Al tocar un producto: stock, mínimo, costo, precio, margen y sus lotes con lo que queda de cada uno. |
| Horas extra de la semana | Agregar personas, elegir días L–S y hora de fin. Quedan aprobadas, vencen el domingo a medianoche y no se copian a la semana siguiente. |
| Estadísticas | Semana o mes: más vendido, ventas por categoría, entregas a tiempo (con tiempos por etapa) y stock bajo con reposiciones pendientes. |
| Eficiencia energética | Consumo del mes, costo, CO₂, kWh por pedido, consumo por zona y alertas. |

## P4 · Administrador

Pestañas: **Usuarios · Parámetros · Inventario · Catálogo · Stats**.

| Pantalla | Qué hace |
|---|---|
| Usuarios y roles | Cuentas del personal con su rol y un interruptor para activar o desactivar (no la propia). «Crear cuenta del personal»: nombre, usuario y contraseña inicial, y el rol se elige. |
| Parámetros | Con − / +: tarifa por kWh, factor CO₂, alerta de consumo, tope de horas extra, margen, plazos de compra y entrega, tarifa y comisión del transportista y tiempos esperados; jornada con selector de hora. Solo se envía lo que cambió. |
| Zonas y equipos | Zonas con su potencia total, equipos con interruptor y creación de zonas y equipos (potencia con − / +, «en jornada» o «continuo»). |
| Bitácora | Aprobaciones, horarios e intentos de ingreso fuera de horario. |
| Importar catálogo | Elegir el Excel → vista previa → «Confirmar e importar». |
| Inventario y estadísticas | Las mismas pantallas del gerente. |

## Velocidad

- Al abrir la app se entra de inmediato con la sesión guardada; el servidor la confirma en segundo
  plano. Salir es inmediato: el aviso de cierre de jornada sale en segundo plano.
- La app «despierta» al servidor (Vercel apaga las funciones sin uso) mientras se escribe la clave.
- Al entrar se precargan las demás pestañas del rol, y cada una guarda sus datos 2 minutos. Al
  cambiar de sesión se descartan, para que nadie vea datos de otra persona.
- La versión de depuración (`flutter run`) es mucho más lenta que la final; para medir la velocidad
  real usa `flutter run --release`.

## Versión web

La misma app corre en el navegador. En pantallas anchas (computador) cambia a diseño de escritorio:
menú lateral azul marino con el logo, contenido centrado, indicadores de a cuatro, ruta con el mapa
grande al lado de las paradas y login con el panel de la marca. En el celular se ve igual que la app.

```
flutter run -d chrome          # probar en el navegador
flutter build web --release    # genera build/web para publicar
```

- El backend ya permite peticiones desde cualquier página (CORS), no hay que cambiarlo.
- Direcciones limpias (`/gerencia/panel`): el servidor debe devolver `index.html` en cualquier ruta.
  Para Vercel ya va `web/vercel.json`; en otro hosting configura esa misma redirección.
- La huella no existe en el navegador; la cámara (escáner) y el GPS piden permiso al navegador y
  solo funcionan con **https** (o en `localhost`).
- En la web la sesión se guarda cifrada en el navegador. Hay un botón «Actualizar» en cada pantalla
  porque con mouse no se puede jalar hacia abajo.

**Publicar en Vercel** (gratis, la misma cuenta del backend):

```
npm i -g vercel
flutter build web --release
vercel deploy build/web --prod
```

La primera vez pide iniciar sesión y el nombre del proyecto; luego da la dirección pública
(por ejemplo `https://novatech-personal.vercel.app`).

## Compartir la app (Android)

```
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`. Súbelo a **GitHub → Releases**
(o a Drive) y comparte el enlace; en el celular hay que permitir «instalar apps de fuentes
desconocidas». Antes de cada entrega sube `version` en `pubspec.yaml` para que se instale encima.

La versión final se firma con la clave de depuración de este computador: las actualizaciones deben
compilarse en el mismo PC, o el celular pedirá desinstalar la anterior. Para publicar en Play Store
hace falta una clave propia (ver «Signing the app» en la documentación de Flutter).

## Notas

- El servidor es quien valida reglas y roles en cada petición; la app solo ordena la navegación y
  muestra el mensaje del servidor cuando algo no se puede hacer.
- `GET /configuracion` no documenta su forma en el OpenAPI: Parámetros busca cada valor por nombre
  (también dentro de grupos). Si alguno no llega se muestra «—» y ese grupo no se puede cambiar, para
  no reemplazarlo por un valor inventado.
- La lectura de **factura PDF con IA** y «Reportar problema» del transportista aparecen en el diseño
  pero el backend aún no tiene ese servicio; la factura se muestra como «próximamente».
- Permisos: cámara y ubicación en `AndroidManifest.xml` e `Info.plist`. El Excel se elige con
  `file_selector` (selector oficial de Flutter).
- Sin cambios en el backend.

## Estructura

```
assets/img/    logos de NovaTech
lib/
  core/        API, sesión, rutas, tema, formatos y widgets comunes
  features/    una carpeta por rol: operario, transportista, gerencia, admin
web/           página de la versión web: carga con el logo, íconos, manifiesto y vercel.json
test/          lógica (conteos, modelos, parámetros, redirección por rol) y cada pantalla
               dibujada en tamaño de celular, con letra normal y grande
```
