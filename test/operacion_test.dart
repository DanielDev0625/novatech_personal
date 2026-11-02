import 'package:flutter_test/flutter_test.dart';
import 'package:novatech_personal/core/api/modelos.dart';
import 'package:novatech_personal/core/formato.dart';
import 'package:novatech_personal/core/widgets/aviso_salida.dart';
import 'package:novatech_personal/features/operario/modelos_operario.dart';

const _cable = LineaPedido(productoId: 1, sku: 'CAB-USB-01', nombre: 'Cable USB', cantidad: 2);
const _mouse = LineaPedido(productoId: 2, sku: 'MOU-01', nombre: 'Mouse', cantidad: 1);

void main() {
  group('ConteoAlistamiento', () {
    test('cada lectura del SKU suma una unidad hasta completar', () {
      final conteo = ConteoAlistamiento([_cable, _mouse]);
      expect(conteo.completo, isFalse);

      expect(conteo.leer('CAB-USB-01'), ResultadoLectura.sumado);
      expect(conteo.leer(' cab-usb-01 '), ResultadoLectura.sumado, reason: 'ignora espacios y mayúsculas');
      expect(conteo.leer('CAB-USB-01'), ResultadoLectura.yaCompleto);
      expect(conteo.escaneados(1), 2);

      expect(conteo.leer('OTRO'), ResultadoLectura.noEsDelPedido);
      expect(conteo.leer('MOU-01'), ResultadoLectura.sumado);
      expect(conteo.completo, isTrue);
      expect(conteo.totalEscaneado, 3);
      expect(conteo.totalPedido, 3);
    });

    test('+ y − corrigen sin pasar de lo pedido ni bajar de cero', () {
      final conteo = ConteoAlistamiento([_mouse]);
      conteo.restar(_mouse);
      expect(conteo.escaneados(2), 0);
      conteo.sumar(_mouse);
      conteo.sumar(_mouse);
      expect(conteo.escaneados(2), 1);
      conteo.restar(_mouse);
      expect(conteo.completo, isFalse);
    });

    test('se puede retomar desde lo guardado', () {
      final conteo = ConteoAlistamiento([_cable, _mouse], {1: 2, 2: 1});
      expect(conteo.completo, isTrue);
      expect(conteo.comoMapa, {1: 2, 2: 1});
    });

    test('el cuerpo de «listo» solo lleva productos con unidades', () {
      final conteo = ConteoAlistamiento([_cable, _mouse])..leer('MOU-01');
      expect(conteo.cuerpoListo(), {
        'escaneados': [
          {'producto_id': 2, 'cantidad': 1},
        ],
      });
    });
  });

  group('Pedido y compra desde JSON', () {
    test('pedido con líneas', () {
      final pedido = Pedido.fromJson({
        'id': 7,
        'codigo': 'PED-0007',
        'estado': 'alistando',
        'cliente': 'Ana',
        'total': 100.0,
        'fecha_prometida': '2026-11-04T17:00:00',
        'creado_en': null,
        'lineas': [
          {'producto_id': 1, 'sku': 'CAB-USB-01', 'nombre': 'Cable USB', 'cantidad': 2, 'precio_unitario': 10, 'subtotal': 20},
        ],
      });
      expect(pedido.alistando, isTrue);
      expect(pedido.lineas.single.sku, 'CAB-USB-01');
      expect(pedido.fechaPrometida, isNotNull);
    });

    test('la cantidad de la compra es la aprobada (cantidad_sugerida)', () {
      final compra = Compra.fromJson({
        'id': 3,
        'codigo': 'COM-0003',
        'estado': 'aprobada',
        'producto_id': 1,
        'sku': 'CAB-USB-01',
        'producto': 'Cable USB',
        'cantidad_sugerida': 40,
        'proveedor': null,
        'fecha_estimada': null,
        'atrasada': false,
        'dias_atraso': 0,
        'lote': null,
        'diferencia': null,
        'nota': null,
      });
      expect(compra.cantidad, 40);
      expect(compra.recibida, isFalse);
    });
  });

  group('resumenRecepcion', () {
    test('todo coincide', () {
      expect(resumenRecepcion(aprobada: 10, buenas: 10, danadas: 0), contains('se creará el lote'));
    });

    test('faltantes, sobrantes y dañadas', () {
      expect(resumenRecepcion(aprobada: 10, buenas: 7, danadas: 0), contains('faltan 3'));
      expect(resumenRecepcion(aprobada: 10, buenas: 12, danadas: 0), contains('sobran 2'));
      expect(resumenRecepcion(aprobada: 10, buenas: 9, danadas: 1), contains('1 dañada'));
    });
  });

  group('Horas extra', () {
    test('los motivos usan el texto del backend', () {
      expect(MotivoHoraExtra.pedidosUrgentes.valor, 'pedidos_urgentes');
      expect(MotivoHoraExtra.desde('apoyo_logistica'), MotivoHoraExtra.apoyoLogistica);
      expect(MotivoHoraExtra.desde('raro'), isNull);
    });

    test('se lee del JSON', () {
      final h = HoraExtra.fromJson({
        'id': 1,
        'usuario_id': 4,
        'usuario': 'op1',
        'fecha': '2026-11-03',
        'hora_fin': '19:30',
        'estado': 'aprobada',
        'motivo': 'inventario',
        'es_correccion': false,
        'resuelta_por': 'Gerente',
      });
      expect(h.estado, EstadoHoraExtra.aprobada);
      expect(h.motivo, MotivoHoraExtra.inventario);
      expect(h.fecha, DateTime(2026, 11, 3));
    });
  });

  group('Aviso de salida', () {
    final ahora = DateTime(2026, 11, 3, 17, 50);

    test('sale en los últimos 10 minutos', () {
      expect(mostrarAvisoSalida(minutosHastaSalida(DateTime(2026, 11, 3, 18, 0), ahora: ahora)), isTrue);
      expect(mostrarAvisoSalida(minutosHastaSalida(DateTime(2026, 11, 3, 18, 1), ahora: ahora)), isFalse);
      expect(mostrarAvisoSalida(minutosHastaSalida(DateTime(2026, 11, 3, 17, 50), ahora: ahora)), isFalse);
      expect(mostrarAvisoSalida(null), isFalse);
    });
  });

  group('formato', () {
    test('fecha y hora para el backend', () {
      expect(fechaApi(DateTime(2026, 1, 5)), '2026-01-05');
      expect(horaApi(7, 5), '07:05');
    });

    test('día relativo', () {
      final hoy = DateTime(2026, 11, 3, 9);
      expect(diaRelativo(DateTime(2026, 11, 3, 20), ahora: hoy), 'hoy');
      expect(diaRelativo(DateTime(2026, 11, 4), ahora: hoy), 'mañana');
      expect(diaRelativo(DateTime(2026, 11, 2), ahora: hoy), 'ayer');
      expect(diaRelativo(DateTime(2026, 11, 6), ahora: hoy), 'viernes 6 nov');
    });
  });
}
