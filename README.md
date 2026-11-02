# NovaTech Personal

App del personal de NovaTech (operario, transportista, gerente y administrador). Solo se escribe
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

Pestañas: **Panel · Aprobar · Stats · Energía**.

| Pantalla | Qué hace |
|---|---|
| Panel del día | Pedidos hoy, % a tiempo, stock bajo y por aprobar. Avisos de mercancía atrasada, recepciones con diferencias, jornadas con salida no registrada y transportistas en ruta. Accesos a horas extra y energía. |
| Aprobaciones | Con un toque: compras sugeridas (quedan / mínimo / sugerido), solicitudes de horas extra y recepciones con diferencias («Aceptar buenas» o «Descartar»). La aprobación es un registro interno, no se envía al proveedor. |
| Horas extra de la semana | Agregar personas, elegir días L–S y hora de fin. Quedan aprobadas, vencen el domingo a medianoche y no se copian a la semana siguiente. |
| Estadísticas | Semana o mes: más vendido, ventas por categoría, entregas a tiempo (con tiempos por etapa) y stock bajo con reposiciones pendientes. |
| Eficiencia energética | Consumo del mes, costo, CO₂, kWh por pedido, consumo por zona y alertas. |

## P4 · Administrador

Pestañas: **Usuarios · Parámetros · Catálogo · Stats**.

| Pantalla | Qué hace |
|---|---|
| Usuarios y roles | Cuentas del personal con su rol y un interruptor para activar o desactivar (no la propia). «Crear cuenta del personal»: nombre, usuario y contraseña inicial, y el rol se elige. |
| Parámetros | Con − / +: tarifa por kWh, factor CO₂, alerta de consumo, tope de horas extra, margen, plazos de compra y entrega, tarifa y comisión del transportista y tiempos esperados; jornada con selector de hora. Solo se envía lo que cambió. |
| Zonas y equipos | Zonas con su potencia total, equipos con interruptor y creación de zonas y equipos (potencia con − / +, «en jornada» o «continuo»). |
| Bitácora | Aprobaciones, horarios e intentos de ingreso fuera de horario. |
| Importar catálogo | Elegir el Excel → vista previa → «Confirmar e importar». |
| Estadísticas | La misma pantalla del gerente. |

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
test/          lógica (conteos, modelos, parámetros, redirección por rol) y cada pantalla
               dibujada en tamaño de celular, con letra normal y grande
```
