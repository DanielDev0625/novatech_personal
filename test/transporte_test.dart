import 'package:flutter_test/flutter_test.dart';
import 'package:novatech_personal/core/api/modelos.dart';
import 'package:novatech_personal/core/formato.dart';
import 'package:novatech_personal/features/transportista/modelos_transportista.dart';

Map<String, dynamic> _parada(int orden, String estado) => {
      'orden': orden,
      'pedido_id': orden * 10,
      'codigo': 'PED-00$orden',
      'cliente': 'Cliente $orden',
      'estado': estado,
      'direccion': {
        'id': 1,
        'etiqueta': 'Casa',
        'texto': 'Calle $orden # 1-2',
        'latitud': 4.6,
        'longitud': -74.1,
        'indicaciones': null,
        'principal': true,
      },
      'distancia_km': 1.5,
      'km_acumulados': 1.5 * orden,
      'eta_minutos': 10 * orden,
    };

void main() {
  test('la parada trae lo que se cobra contra entrega', () {
    final json = {
      'orden': 2,
      'pedido_id': 7,
      'codigo': 'PED-2026-0007',
      'cliente': 'Ana',
      'estado': 'en_ruta',
      'direccion': {'etiqueta': 'casa', 'texto': 'Cra 43 #84-20', 'latitud': 10.9, 'longitud': -74.8},
      'distancia_km': 1.2,
      'km_acumulados': 3.4,
      'eta_minutos': 12,
      'total_a_pagar': 1806000,
    };
    final parada = Parada.fromJson(json);
    expect(parada.totalAPagar, 1806000);
    expect(pesos(parada.totalAPagar), '\$ 1.806.000');
    // Un servidor viejo sin el campo no rompe nada.
    expect(Parada.fromJson({...json}..remove('total_a_pagar')).totalAPagar, 0);
  });

  group('Ruta', () {
    test('las paradas quedan en orden y se sabe si se puede iniciar', () {
      final ruta = Ruta.fromJson({
        'origen_latitud': 4.65,
        'origen_longitud': -74.05,
        'origen_es_posicion_real': false,
        'paradas': [_parada(2, 'recibido_transportista'), _parada(1, 'en_ruta')],
        'total_km': 3,
        'tiempo_total_minutos': 25,
      });
      expect(ruta.paradas.map((p) => p.orden), [1, 2]);
      expect(ruta.puedeIniciar, isTrue);
      expect(ruta.hayEnRuta, isTrue);
      expect(ruta.paradas.first.direccion.texto, 'Calle 1 # 1-2');
      expect(ruta.totalKm, 3.0);
    });

    test('sin paradas no hay nada que iniciar', () {
      final ruta = Ruta.fromJson({
        'origen_latitud': 4.65,
        'origen_longitud': -74.05,
        'origen_es_posicion_real': true,
        'paradas': [],
        'total_km': 0,
        'tiempo_total_minutos': 0,
      });
      expect(ruta.puedeIniciar, isFalse);
      expect(ruta.hayEnRuta, isFalse);
    });
  });

  test('el QR del paquete se busca por código de pedido', () {
    const pedidos = [
      PedidoResumen(id: 7, codigo: 'PED-0007', estado: 'en_zona_envios', cliente: null, unidades: 1, fechaPrometida: null, creadoEn: null),
    ];
    expect(pedidoDeCodigo(pedidos, ' ped-0007 ')?.id, 7);
    expect(pedidoDeCodigo(pedidos, 'PED-0008'), isNull);
  });

  test('liquidación desde JSON', () {
    final resumen = ResumenLiquidacion.fromJson({
      'items': [
        {
          'id': 1,
          'pedido_id': 7,
          'pedido': 'PED-0007',
          'transportista_id': 5,
          'transportista': 'Luis',
          'fecha': '2026-11-02T15:00:00',
          'tarifa': 8000,
          'comision_porcentaje': 10,
          'comision': 800,
          'pagada': false,
          'fecha_pago': null,
        },
      ],
      'total_comision': 800,
      'total_pendiente': 800,
      'total_pagado': 0,
    });
    expect(resumen.items.single.comision, 800.0);
    expect(resumen.totalPendiente, 800.0);
  });

  group('formato', () {
    test('pesos con punto de miles', () {
      expect(pesos(0), '\$ 0');
      expect(pesos(800), '\$ 800');
      expect(pesos(12500), '\$ 12.500');
      expect(pesos(1234567.6), '\$ 1.234.568');
      expect(pesos(-3000), '-\$ 3.000');
    });

    test('distancia y duración', () {
      expect(distancia(0.85), '850 m');
      expect(distancia(3.42), '3,4 km');
      expect(duracion(45), '45 min');
      expect(duracion(60), '1 h');
      expect(duracion(80), '1 h 20 min');
    });
  });
}
