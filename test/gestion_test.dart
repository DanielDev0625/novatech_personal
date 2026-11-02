import 'package:flutter_test/flutter_test.dart';
import 'package:novatech_personal/core/api/modelos.dart';
import 'package:novatech_personal/core/formato.dart';
import 'package:novatech_personal/core/rutas/rutas.dart';
import 'package:novatech_personal/core/sesion/sesion.dart';
import 'package:novatech_personal/core/widgets/scaffold_rol.dart';
import 'package:novatech_personal/features/admin/modelos_admin.dart';
import 'package:novatech_personal/features/admin/pantalla_parametros.dart';
import 'package:novatech_personal/features/gerencia/modelos_gerencia.dart';

EstadoSesion _con(Rol rol) => EstadoSesion(
      usuario: Usuario(id: 1, nombre: 'Ana', usuario: 'ana', rol: rol, activo: true),
      token: 't',
    );

void main() {
  group('redireccionPorRol', () {
    test('sin sesión todo va al login; restaurando, a la pantalla de carga', () {
      expect(redireccionPorRol(const EstadoSesion(), '/operario/tareas'), '/login');
      expect(redireccionPorRol(const EstadoSesion(), '/login'), isNull);
      expect(redireccionPorRol(const EstadoSesion(restaurando: true), '/login'), '/cargando');
    });

    test('cada rol entra a su primera pestaña y no puede ver la de otro', () {
      expect(redireccionPorRol(_con(Rol.gerente), '/login'), '/gerencia/panel');
      expect(redireccionPorRol(_con(Rol.gerente), '/gerencia'), '/gerencia/panel');
      expect(redireccionPorRol(_con(Rol.gerente), '/gerencia/aprobar'), isNull);
      expect(redireccionPorRol(_con(Rol.gerente), '/admin/usuarios'), '/gerencia/panel');
      expect(redireccionPorRol(_con(Rol.operario), '/operario/alistar/4'), isNull);
      expect(redireccionPorRol(_con(Rol.operario), '/operariox'), '/operario/tareas');
      expect(redireccionPorRol(_con(Rol.administrador), '/admin/zonas'), isNull);
    });
  });

  group('Parámetros', () {
    final config = {
      'margen': 0.18,
      'plazo_compra_dias': 2,
      'liquidacion': {'tarifa_entrega': 8000, 'comision_porcentaje': 10},
      'jornada': {'hora_inicio': '07:00:00', 'hora_salida': '19:00:00', 'tope_horas_extra': 2},
      'energia': {'tarifa_kwh': 850, 'factor_co2': 0.164, 'aumento_alerta_porcentaje': 15},
    };

    test('se leen aunque vengan anidados; lo que no llega queda en null', () {
      final p = Parametros.desde(config);
      expect(p.margen, 0.18);
      expect(p.margenEsFraccion, isTrue);
      expect(p.tarifaEntrega, 8000);
      expect(p.horaSalida, '19:00:00');
      expect(p.factorCo2, 0.164);
      expect(p.plazoEntregaDias, isNull);
      expect(p.conEtapas, isFalse);
    });

    test('solo se envía lo que cambió, con el grupo completo', () {
      final original = Parametros.desde(config);
      final editado = original.copia();
      expect(editado.cambiosFrente(original), isEmpty);

      editado.tarifaKwh = 900;
      editado.horaSalida = '20:00';
      final cambios = editado.cambiosFrente(original);
      expect(cambios.map((c) => c.$1), ['/configuracion/jornada', '/configuracion/energia']);
      expect(cambios.first.$2, {'hora_inicio': '07:00', 'hora_salida': '20:00', 'tope_horas_extra': 2.0});
      expect(cambios.last.$2['tarifa_kwh'], 900);
    });

    test('ajustar respeta límites y decimales', () {
      expect(ajustar(0.164, 0.001, decimales: 3), 0.165);
      expect(ajustar(0.1, 0.2, decimales: 1), 0.3);
      expect(ajustar(1, -5, minimo: 1), 1);
      expect(ajustar(2, 0.5, maximo: 2), 2);
    });
  });

  group('Gerencia', () {
    test('período de estadísticas y lunes de la semana', () {
      final (desde, hasta) = Periodo.semana.rango(hoy: DateTime(2026, 11, 4, 15));
      expect(hasta, DateTime(2026, 11, 4));
      expect(desde, DateTime(2026, 10, 29));
      expect(lunesDe(DateTime(2026, 11, 8)), DateTime(2026, 11, 2));
      expect(lunesDe(DateTime(2026, 11, 2)), DateTime(2026, 11, 2));
    });

    test('estadísticas desde las cuatro respuestas', () {
      final e = Estadisticas.desde(
        productos: {
          'mas_vendido': {'nombre': 'SSD 1 TB NVMe', 'categoria': 'SSD', 'unidades': 46, 'ingresos': 100},
          'productos': [],
        },
        categorias: {
          'total_ingresos': 300,
          'categorias': [
            {'categoria': 'RAM', 'unidades': 1, 'ingresos': 100, 'porcentaje_ingresos': 33.3},
            {'categoria': 'GPU', 'unidades': 1, 'ingresos': 200, 'porcentaje_ingresos': 66.7},
          ],
        },
        entregas: {'entregadas': 10, 'a_tiempo': 9, 'tardias': 1, 'porcentaje_a_tiempo': 90, 'etapas': []},
        stockBajo: [
          {'nombre': 'RAM', 'stock': 4, 'stock_minimo': 10, 'compra': 'COM-0001'},
          {'nombre': 'SSD', 'stock': 3, 'stock_minimo': 8, 'compra': null},
        ],
      );
      expect(e.masVendido!.unidades, 46);
      expect(e.categorias.first.categoria, 'GPU', reason: 'ordenadas por ingresos');
      expect(e.entregas.porcentajeATiempo, 90);
      expect(e.reposicionesPendientes, 1);
    });
  });

  test('búsqueda de claves en mapas anidados', () {
    expect(buscarClave({'a': {'b': {'c': 1}}}, ['c']), 1);
    expect(buscarNumero({'x': '0,5'}, ['x']), 0.5);
    expect(buscarHora({'h': 'nada'}, ['h']), isNull);
  });

  test('iniciales y horas', () {
    expect(iniciales('Laura Pérez'), 'LP');
    expect(iniciales('marco'), 'M');
    expect(iniciales('  '), '?');
    expect(horaCorta('07:00:00'), '7:00');
    expect(horaCorta('19:30'), '19:30');
    expect(leerHora('nada'), isNull);
  });
}
