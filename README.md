# NovaTech Personal

App del personal de NovaTech (operario, transportista, gerente y administrador). Solo se escribe
usuario y contraseña; todo lo demás se toca, se escanea o se elige. El servidor devuelve el rol al
iniciar sesión y la app abre la parte que corresponde.

| Fase | Estado | Qué trae |
|---|---|---|
| P1 | ✅ | Base, tema, login con huella y navegación por rol. |
| P2 | ✅ | Todo lo que hace el **operario**. |
| P3 | ✅ | Todo lo que hace el **transportista**. |
| P4 | Pendiente | Gerencia y administración. |

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

## P2 · Operario

| Pantalla | Qué hace |
|---|---|
| Inicio del operario | Accesos con conteos (en cola, por recibir) y aviso «tu jornada termina en N minutos» en los últimos 10 min. Al llegar la hora de salida, la sesión se cierra sola. |
| Mis tareas | «Estoy alistando» arriba; la cola (más antiguos primero) abajo. «Tomar» reserva el pedido; si otro lo tomó antes, avisa. |
| Alistamiento | Cámara que lee el QR/código de barras (el código es el **SKU** del producto). Cada lectura suma una unidad; + y − corrigen. Lo contado se conserva si sales y vuelves. «Listo para envío» solo se activa cuando todo está completo. |
| Recepción de mercancía | Lista de compras aprobadas → contar «en buen estado» y «dañadas» con botones −10, −1, +1, +10. Si todo coincide se crea el lote; si no, queda «con diferencias» para gerencia. |
| Mi jornada | Horario y entrada de hoy, tus horas extra con su estado, y «Solicitar horas extra» eligiendo día, hora y motivo (sin escribir). Cuentan solo cuando gerencia aprueba. |

### Probar con datos

- **Pedido para alistar:** desde Swagger del backend crea un pedido con una cuenta cliente y genera un
  QR (cualquier generador) cuyo texto sea exactamente el **SKU** del producto.
- **Compra para recibir:** sugiere y aprueba una compra (`/compras/generar`, `/compras/{id}/aprobar`).
- La primera vez que abras un alistamiento, el celular pedirá permiso de cámara: acéptalo.

### Notas

- El servidor es quien valida: si lo escaneado no coincide con el pedido responde 422 y la app
  muestra el mensaje. Los roles se comprueban en cada petición.
- Rutas: `/operario/tareas`, `/operario/alistar/:id`, `/operario/recepcion`,
  `/operario/recibir/:id`, `/operario/jornada`.
- Permiso de cámara declarado en `AndroidManifest.xml` e `Info.plist` (paquete `mobile_scanner`).
- Sin cambios en el backend.

## P3 · Transportista

| Pantalla | Qué hace |
|---|---|
| Inicio del transportista | Accesos con conteos (paquetes listos, paradas) y lo pendiente por pagar. Mismo aviso de fin de jornada y cierre automático que el operario. Mientras hay entregas en ruta, comparte la ubicación cada 30 s (con la app abierta) para el seguimiento del cliente. |
| Recibir paquetes | Lista de pedidos en la zona de envíos. «Escanear paquete» lee el QR del paquete y lo pasa a tu ruta (traspaso de custodia). |
| Mi ruta | Mapa (OpenStreetMap) con las paradas numeradas en el orden más eficiente, distancia y hora aproximada de llegada. «Iniciar ruta» pone en ruta todos los paquetes recibidos. En cada parada: «Cómo llegar» (abre Google Maps) y «Entregar», que escanea el QR que muestra el cliente. |
| Mi liquidación | Totales pendiente, pagado y total, y el detalle de cada entrega con tarifa y comisión. |

### Probar con datos

- **Paquete para recibir:** alista un pedido como operario hasta «Listo para envío» y genera un QR
  cuyo texto sea el **código del pedido** (por ejemplo `PED-0007`).
- **Entrega:** el QR de entrega es el que la app del cliente muestra (`qr_entrega` del pedido); para
  probar, genera un QR con ese texto.
- El celular pedirá permiso de ubicación al recibir un paquete o iniciar la ruta. Si se niega, todo
  funciona igual y la ruta se calcula desde la bodega.

### Notas

- Rutas: `/transportista/recibir`, `/transportista/ruta`, `/transportista/liquidacion`.
- Paquetes nuevos: `flutter_map` + `latlong2` (mapa), `geolocator` (GPS) y `url_launcher`
  («Cómo llegar»). Permisos de ubicación en `AndroidManifest.xml` e `Info.plist`.
- Sin cambios en el backend.

## Estructura

```
lib/
  core/        API, sesión, rutas, tema y widgets comunes (cámara, avisos, listas)
  features/    una carpeta por rol: operario, transportista, gerencia, admin
test/          pruebas de la lógica (conteos, modelos, formatos)
```
