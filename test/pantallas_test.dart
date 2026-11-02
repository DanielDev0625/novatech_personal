// Dibuja cada pantalla principal con datos de ejemplo en tamaño de celular
// (360 × 780) para detectar desbordes y errores de diseño sin backend.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novatech_personal/core/api/modelos.dart';
import 'package:novatech_personal/core/sesion/pantalla_login.dart';
import 'package:novatech_personal/core/sesion/sesion.dart';
import 'package:novatech_personal/core/tema/tema.dart';
import 'package:novatech_personal/features/admin/api_admin.dart';
import 'package:novatech_personal/features/admin/modelos_admin.dart';
import 'package:novatech_personal/features/admin/pantalla_bitacora.dart';
import 'package:novatech_personal/features/admin/pantalla_catalogo.dart';
import 'package:novatech_personal/features/admin/pantalla_parametros.dart';
import 'package:novatech_personal/features/admin/pantalla_usuarios.dart';
import 'package:novatech_personal/features/admin/pantalla_zonas.dart';
import 'package:novatech_personal/features/gerencia/api_gerencia.dart';
import 'package:novatech_personal/features/gerencia/modelos_gerencia.dart';
import 'package:novatech_personal/features/gerencia/pantalla_aprobaciones.dart';
import 'package:novatech_personal/features/gerencia/pantalla_energia.dart';
import 'package:novatech_personal/features/gerencia/pantalla_estadisticas.dart';
import 'package:novatech_personal/features/gerencia/pantalla_inventario.dart';
import 'package:novatech_personal/features/gerencia/pantalla_panel.dart';
import 'package:novatech_personal/features/gerencia/pantalla_programar_horas.dart';
import 'package:novatech_personal/features/operario/api_operario.dart';
import 'package:novatech_personal/features/operario/modelos_operario.dart';
import 'package:novatech_personal/features/operario/pantalla_jornada.dart';
import 'package:novatech_personal/features/operario/pantalla_recibir.dart';
import 'package:novatech_personal/features/operario/pantalla_tareas.dart';
import 'package:novatech_personal/features/transportista/api_transportista.dart';
import 'package:novatech_personal/features/transportista/modelos_transportista.dart';
import 'package:novatech_personal/features/transportista/pantalla_entregas.dart';
import 'package:novatech_personal/features/transportista/pantalla_liquidacion.dart';

/// Sesión fija para las pruebas (no toca el almacén seguro ni la biometría).
class _SesionFija extends SesionNotifier {
  _SesionFija(this.estado);

  final EstadoSesion estado;

  @override
  EstadoSesion build() => estado;
}

Override _sesion(Rol? rol) => sesionProvider.overrideWith(
      () => _SesionFija(
        rol == null
            ? const EstadoSesion()
            : EstadoSesion(
                usuario: Usuario(id: 1, nombre: 'Laura Pérez', usuario: 'laura', rol: rol, activo: true),
                token: 't',
              ),
      ),
    );

/// Tamaño de letra del celular: normal y grande (accesibilidad).
final _letra = ValueVariant<double>({1.0, 1.3});

Future<void> _mostrar(WidgetTester tester, Widget pantalla, List<Override> overrides) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = _letra.currentValue ?? 1.0;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: TemaNovaTech.claro(), home: pantalla),
    ),
  );
  await tester.pumpAndSettle();
}

final _compra = Compra.fromJson({
  'id': 1,
  'codigo': 'COM-0031',
  'estado': 'sugerida',
  'producto_id': 1,
  'sku': 'RAM-DDR5-16',
  'producto': 'RAM DDR5 16 GB',
  'stock_actual': 4,
  'stock_minimo': 10,
  'cantidad_sugerida': 24,
  'proveedor': null,
  'fecha_estimada': null,
  'atrasada': false,
  'dias_atraso': 0,
  'lote': null,
  'diferencia': null,
  'nota': null,
});

const _pedido = PedidoResumen(
  id: 412,
  codigo: 'PED-0412',
  estado: 'registrado',
  cliente: 'Carlos Ruiz',
  unidades: 5,
  fechaPrometida: null,
  creadoEn: null,
);

void main() {
  testWidgets('Login con el logo de NovaTech', (tester) async {
    await _mostrar(tester, const PantallaLogin(), [_sesion(null)]);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('El rol lo define tu cuenta'), findsOneWidget);
    expect(find.bySemanticsLabel('NovaTech'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Operario · Mis tareas', (tester) async {
    await _mostrar(tester, const PantallaTareas(), [
      _sesion(Rol.operario),
      colaProvider.overrideWith((ref) async => [_pedido]),
      alistandoProvider.overrideWith(
        (ref) async => [const PedidoResumen(
              id: 409,
              codigo: 'PED-0409',
              estado: 'alistando',
              cliente: null,
              unidades: 4,
              fechaPrometida: null,
              creadoEn: null,
            )],
      ),
      comprasPorRecibirProvider.overrideWith((ref) async => [_compra]),
      jornadaHoyProvider.overrideWith(
        (ref) async => JornadaHoy.fromJson({
          'hora_inicio': '07:00:00',
          'hora_salida': '19:00:00',
          'minutos_para_salida': 300,
          'aviso_salida': false,
        }),
      ),
    ]);
    expect(find.text('Mis tareas'), findsOneWidget);
    expect(find.text('Jornada 7:00 a 19:00'), findsOneWidget);
    expect(find.text('Tomar tarea'), findsOneWidget);
    expect(find.text('Escaneadas 0 de 4'), findsOneWidget);
    expect(find.text('Recibir mercancía'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Transportista · Entregas de hoy', (tester) async {
    await _mostrar(tester, const PantallaEntregas(), [
      _sesion(Rol.transportista),
      zonaEnviosProvider.overrideWith((ref) async => [_pedido]),
      rutaProvider.overrideWith(
        (ref) async => Ruta.fromJson({
          'origen_latitud': 10.98,
          'origen_longitud': -74.8,
          'origen_es_posicion_real': false,
          'paradas': [
            {
              'orden': 1,
              'pedido_id': 401,
              'codigo': 'PED-0401',
              'cliente': 'Ana',
              'estado': 'recibido_transportista',
              'direccion': {'texto': 'Calle 76 #52-18', 'latitud': 10.99, 'longitud': -74.81},
              'distancia_km': 3.4,
              'km_acumulados': 3.4,
              'eta_minutos': 12,
            },
          ],
          'total_km': 3.4,
          'tiempo_total_minutos': 12,
        }),
      ),
    ]);
    expect(find.text('Entregas de hoy'), findsOneWidget);
    expect(find.text('Por salir'), findsOneWidget);
    expect(find.text('Por recibir'), findsOneWidget);
    expect(find.text('Iniciar ruta'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Gerente · Panel del día', (tester) async {
    await _mostrar(tester, const PantallaPanel(), [
      _sesion(Rol.gerente),
      panelProvider.overrideWith(
        (ref) async => Panel.fromJson({
          'pedidos': 18,
          'ventas_total': 12500000,
          'porcentaje_a_tiempo': 94,
          'productos_stock_bajo': 5,
          'jornadas_salida_no_registrada': 2,
          'energia_kwh': 160,
          'energia_costo': 136000,
        }),
      ),
      comprasSugeridasProvider.overrideWith((ref) async => [_compra, _compra]),
      comprasConDiferenciasProvider.overrideWith((ref) async => <Compra>[]),
      horasExtraSolicitadasProvider.overrideWith((ref) async => <HoraExtra>[]),
      comprasAtrasadasProvider.overrideWith((ref) async => [_compra]),
      transportistasProvider.overrideWith(
        (ref) async => [TransportistaEstado.fromJson({'nombre': 'Marco', 'entregas_activas': 2})],
      ),
    ]);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);
    expect(find.text('Por aprobar'), findsOneWidget);
    expect(find.text('2 jornadas con salida no registrada'), findsOneWidget);
    expect(find.text('1 transportista en ruta'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Gerente · Aprobaciones', (tester) async {
    await _mostrar(tester, const PantallaAprobaciones(), [
      _sesion(Rol.gerente),
      comprasSugeridasProvider.overrideWith((ref) async => [_compra]),
      comprasConDiferenciasProvider.overrideWith((ref) async => <Compra>[]),
      horasExtraSolicitadasProvider.overrideWith((ref) async => <HoraExtra>[]),
    ]);
    expect(find.text('Compras 1'), findsOneWidget);
    expect(find.text('Quedan 4 · mínimo 10'), findsOneWidget);
    expect(find.text('Aprobar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Gerente · Estadísticas', (tester) async {
    final estadisticas = Estadisticas.desde(
      productos: {
        'mas_vendido': {'nombre': 'SSD 1 TB NVMe', 'categoria': 'SSD', 'unidades': 46, 'ingresos': 1},
      },
      categorias: {
        'total_ingresos': 300,
        'categorias': [
          {'categoria': 'Tarjetas gráficas', 'unidades': 1, 'ingresos': 200, 'porcentaje_ingresos': 66.7},
          {'categoria': 'Procesadores', 'unidades': 1, 'ingresos': 100, 'porcentaje_ingresos': 33.3},
        ],
      },
      entregas: {'entregadas': 50, 'a_tiempo': 47, 'tardias': 3, 'porcentaje_a_tiempo': 94, 'etapas': []},
      stockBajo: [
        {'nombre': 'RAM DDR5 16 GB', 'stock': 4, 'stock_minimo': 10, 'compra': 'COM-0031'},
      ],
    );
    await _mostrar(tester, const PantallaEstadisticas(), [
      _sesion(Rol.gerente),
      estadisticasProvider.overrideWith((ref, periodo) async => estadisticas),
    ]);
    expect(find.text('SSD 1 TB NVMe · 46 uds'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Gerente · Eficiencia energética', (tester) async {
    await _mostrar(tester, const PantallaEnergia(), [
      _sesion(Rol.gerente),
      consumoProvider.overrideWith(
        (ref) async => Consumo.fromJson({
          'total_kwh': 4860,
          'total_costo': 4131000,
          'total_co2_kg': 797,
          'kwh_por_pedido': 3.2,
          'pedidos_despachados': 1500,
          'zonas': [
            {'zona': 'Bodega', 'kwh': 2000},
            {'zona': 'Montacargas', 'kwh': 900},
          ],
        }),
      ),
      alertasEnergiaProvider.overrideWith(
        (ref) async => [AlertaEnergia.fromJson({'zona': 'Bodega', 'mensaje': 'Bodega subió 18% frente al mes anterior'})],
      ),
    ]);
    expect(find.text('4.860 kWh'), findsOneWidget);
    expect(find.text('\$4,1 M'), findsOneWidget);
    expect(find.text('Bodega subió 18% frente al mes anterior'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Administrador · Usuarios y roles', (tester) async {
    await _mostrar(tester, const PantallaUsuarios(), [
      _sesion(Rol.administrador),
      usuariosProvider.overrideWith(
        (ref) async => const [
          Usuario(id: 2, nombre: 'Marco Gil', usuario: 'marco', rol: Rol.transportista, activo: true),
          Usuario(id: 3, nombre: 'Ana Soto', usuario: 'ana', rol: Rol.gerente, activo: false),
        ],
      ),
    ]);
    expect(find.text('MG'), findsOneWidget);
    expect(find.text('Transportista'), findsOneWidget);
    expect(find.text('Crear cuenta del personal'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Administrador · Parámetros', (tester) async {
    await _mostrar(tester, const PantallaParametros(), [
      _sesion(Rol.administrador),
      configuracionProvider.overrideWith(
        (ref) async => {
          'margen': 18,
          'plazo_compra_dias': 2,
          'tarifa_kwh': 850,
          'factor_co2': 0.164,
          'aumento_alerta_porcentaje': 15,
          'hora_inicio': '07:00',
          'hora_salida': '19:00',
          'tope_horas_extra': 2,
        },
      ),
    ]);
    expect(find.text('\$ 850'), findsOneWidget);
    expect(find.text('0,164'), findsOneWidget);
    expect(find.text('Sin cambios'), findsOneWidget);
    for (final texto in ['7:00 a 19:00', '18%']) {
      await tester.scrollUntilVisible(find.text(texto), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text(texto), findsOneWidget);
    }

    // Un toque en «+» del margen habilita «Guardar cambios».
    final masMargen = find.descendant(
      of: find.ancestor(of: find.text('18%'), matching: find.byType(Row)).first,
      matching: find.byTooltip('Más'),
    );
    await tester.tap(masMargen);
    await tester.pump();
    expect(find.text('19%'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Operario · Mi jornada', (tester) async {
    await _mostrar(tester, const PantallaJornada(), [
      _sesion(Rol.operario),
      jornadaHoyProvider.overrideWith(
        (ref) async => JornadaHoy.fromJson({
          'hora_inicio': '07:00:00',
          'hora_salida': '19:00:00',
          'entrada_real': '2026-11-02T07:02:00',
          'minutos_para_salida': 300,
          'aviso_salida': false,
        }),
      ),
      horasExtraProvider.overrideWith(
        (ref) async => [
          HoraExtra.fromJson({
            'id': 1,
            'fecha': '2026-11-04',
            'hora_fin': '21:00',
            'estado': 'aprobada',
            'motivo': 'mercancia_por_recibir',
            'es_correccion': false,
            'resuelta_por': 'Ana Soto',
          }),
        ],
      ),
    ]);
    expect(find.text('7:02'), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);
    expect(find.text('hasta 21:00'), findsOneWidget);
    expect(find.text('Solicitar horas extra'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Operario · Recepción de una compra', (tester) async {
    final aprobada = Compra.fromJson({
      'id': 31,
      'codigo': 'COM-0031',
      'estado': 'aprobada',
      'sku': 'RAM-DDR5-16',
      'producto': 'RAM DDR5 16 GB',
      'cantidad_sugerida': 24,
      'proveedor': 'Mayorista Andino',
    });
    await _mostrar(tester, const PantallaRecibir(compraId: 31), [
      _sesion(Rol.operario),
      compraProvider.overrideWith((ref, id) async => aprobada),
    ]);
    expect(find.text('Recepción COM-0031'), findsOneWidget);
    expect(find.text('Deben llegar 24 unidades'), findsOneWidget);
    await tester.tap(find.text('Llegaron las 24 en buen estado'));
    await tester.pump();
    expect(find.text('Todo coincide: se creará el lote y el stock subirá.'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Transportista · Mi liquidación', (tester) async {
    await _mostrar(tester, const PantallaLiquidacion(), [
      _sesion(Rol.transportista),
      liquidacionProvider.overrideWith(
        (ref) async => ResumenLiquidacion.fromJson({
          'items': [
            {
              'id': 1,
              'pedido_id': 398,
              'pedido': 'PED-0398',
              'fecha': '2026-11-02T10:00:00',
              'tarifa': 8000,
              'comision_porcentaje': 10,
              'comision': 800,
              'pagada': false,
            },
          ],
          'total_comision': 800,
          'total_pendiente': 800,
          'total_pagado': 0,
        }),
      ),
    ]);
    expect(find.text('PED-0398'), findsOneWidget);
    expect(find.text('Pendiente'), findsWidgets);
  }, variant: _letra);

  testWidgets('Gerente · Horas extra de la semana', (tester) async {
    await _mostrar(tester, const PantallaProgramarHoras(), [
      _sesion(Rol.gerente),
      horariosProvider.overrideWith(
        (ref) async => [
          HorarioPersona.fromJson({
            'usuario_id': 7,
            'nombre': 'Carlos Ruiz',
            'rol': 'operario',
            'hora_inicio': '07:00',
            'hora_salida': '19:00',
          }),
        ],
      ),
      horasExtraSemanaProvider.overrideWith((ref) async => <HoraExtra>[]),
    ]);
    await tester.tap(find.text('Agregar persona'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlos Ruiz'));
    await tester.pumpAndSettle();
    expect(find.text('Carlos Ruiz · Operario'), findsOneWidget);
    expect(find.text('21:00 ▾'), findsOneWidget, reason: 'sugiere dos horas después de la salida');
    expect(find.text('Guardar programación'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Administrador · Zonas y equipos', (tester) async {
    await _mostrar(tester, const PantallaZonas(), [
      _sesion(Rol.administrador),
      zonasProvider.overrideWith(
        (ref) async => [
          Zona.fromJson({
            'id': 1,
            'nombre': 'Bodega',
            'umbral_kwh_mensual': 2500,
            'potencia_total_kw': 12.5,
            'equipos': [
              {'id': 1, 'nombre': 'Iluminación LED', 'potencia_kw': 2.5, 'tipo': 'jornada', 'activo': true},
              {'id': 2, 'nombre': 'Cuarto frío', 'potencia_kw': 10, 'tipo': 'continuo', 'activo': true},
            ],
          }),
        ],
      ),
    ]);
    expect(find.text('12,5 kW'), findsOneWidget);
    expect(find.text('10 kW · continuo (24 h)'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Administrador · Bitácora', (tester) async {
    await _mostrar(tester, const PantallaBitacora(), [
      _sesion(Rol.administrador),
      bitacoraProvider.overrideWith(
        (ref) async => [
          EntradaBitacora.fromJson({
            'id': 1,
            'fecha': '2026-11-02T05:40:00',
            'usuario': 'laura',
            'accion': 'ingreso_fuera_de_horario',
            'detalle': 'Intentó entrar antes de las 7:00',
          }),
        ],
      ),
    ]);
    expect(find.text('Ingreso fuera de horario'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Administrador · Importar catálogo', (tester) async {
    await _mostrar(tester, const PantallaCatalogo(), [_sesion(Rol.administrador)]);
    expect(find.text('Excel'), findsOneWidget);
    expect(find.text('Factura PDF'), findsOneWidget);
  }, variant: _letra);

  testWidgets('Gerente · Inventario', (tester) async {
    Map<String, dynamic> producto(int id, String nombre, int stock, {bool bajo = false}) => {
      'id': id,
      'sku': 'SKU-$id',
      'nombre': nombre,
      'marca': 'AMD',
      'categoria': 'Procesadores',
      'costo': 700000,
      'precio': 899000,
      'stock': stock,
      'stock_minimo': 5,
      'stock_bajo': bajo,
      'activo': true,
    };
    await _mostrar(tester, const PantallaInventario(), [
      _sesion(Rol.gerente),
      inventarioProvider.overrideWith(
        (ref) async => [
          ProductoInventario.fromJson(producto(1, 'Ryzen 5 7600', 12)),
          ProductoInventario.fromJson(producto(2, 'Ryzen 7 7700', 2, bajo: true)),
        ],
      ),
      lotesProvider.overrideWith(
        (ref, id) async => [
          Lote.fromJson({
            'codigo': 'LOT-0007',
            'cantidad_inicial': 20,
            'cantidad_restante': 12,
            'costo_unitario': 700000,
            'proveedor': 'Mayorista Andino',
            'fecha_recepcion': '2026-10-20T09:00:00',
            'estado': 'almacenado',
          }),
        ],
      ),
    ]);
    expect(find.text('Valor en bodega'), findsOneWidget);
    expect(find.text('2 productos'), findsOneWidget);

    await tester.tap(find.text('Stock bajo · 1'));
    await tester.pumpAndSettle();
    expect(find.text('1 producto'), findsOneWidget);

    await tester.tap(find.text('Ryzen 7 7700'));
    await tester.pumpAndSettle();
    expect(find.text('LOT-0007'), findsOneWidget);
    expect(find.text('Almacenado'), findsOneWidget);
  }, variant: _letra);
}
