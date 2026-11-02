import '../../core/api/modelos.dart';
import '../../core/formato.dart';

/// Dirección de entrega con sus coordenadas.
class Direccion {
  const Direccion({
    required this.etiqueta,
    required this.texto,
    required this.latitud,
    required this.longitud,
    required this.indicaciones,
  });

  final String etiqueta;
  final String texto;
  final double latitud;
  final double longitud;
  final String? indicaciones;

  factory Direccion.fromJson(Map<String, dynamic> json) => Direccion(
        etiqueta: json['etiqueta'] as String? ?? '',
        texto: json['texto'] as String? ?? '',
        latitud: (json['latitud'] as num).toDouble(),
        longitud: (json['longitud'] as num).toDouble(),
        indicaciones: json['indicaciones'] as String?,
      );
}

/// Una parada de la ruta (un pedido por entregar), ya en el orden más eficiente.
class Parada {
  const Parada({
    required this.orden,
    required this.pedidoId,
    required this.codigo,
    required this.cliente,
    required this.estado,
    required this.direccion,
    required this.distanciaKm,
    required this.kmAcumulados,
    required this.etaMinutos,
  });

  final int orden;
  final int pedidoId;
  final String codigo;
  final String cliente;
  final String estado;
  final Direccion direccion;

  /// Distancia desde la parada anterior.
  final double distanciaKm;
  final double kmAcumulados;

  /// Minutos estimados hasta llegar a esta parada.
  final int etaMinutos;

  /// Recibido del operario pero la ruta aún no empieza.
  bool get porSalir => estado == 'recibido_transportista';
  bool get enRuta => estado == 'en_ruta';

  factory Parada.fromJson(Map<String, dynamic> json) => Parada(
        orden: json['orden'] as int,
        pedidoId: json['pedido_id'] as int,
        codigo: json['codigo'] as String,
        cliente: json['cliente'] as String? ?? '',
        estado: json['estado'] as String,
        direccion: Direccion.fromJson(Map<String, dynamic>.from(json['direccion'] as Map)),
        distanciaKm: (json['distancia_km'] as num? ?? 0).toDouble(),
        kmAcumulados: (json['km_acumulados'] as num? ?? 0).toDouble(),
        etaMinutos: json['eta_minutos'] as int? ?? 0,
      );
}

class Ruta {
  const Ruta({
    required this.origenLatitud,
    required this.origenLongitud,
    required this.origenEsPosicionReal,
    required this.paradas,
    required this.totalKm,
    required this.tiempoTotalMinutos,
  });

  final double origenLatitud;
  final double origenLongitud;

  /// true si el origen es la posición GPS del transportista; false si es la bodega.
  final bool origenEsPosicionReal;
  final List<Parada> paradas;
  final double totalKm;
  final int tiempoTotalMinutos;

  /// Hay paquetes recibidos que todavía no salen: se puede tocar «Iniciar ruta».
  bool get puedeIniciar => paradas.any((p) => p.porSalir);

  /// Hay entregas en camino: la app comparte la ubicación.
  bool get hayEnRuta => paradas.any((p) => p.enRuta);

  factory Ruta.fromJson(Map<String, dynamic> json) {
    final paradas = [
      for (final p in (json['paradas'] as List? ?? const [])) Parada.fromJson(Map<String, dynamic>.from(p as Map)),
    ]..sort((a, b) => a.orden.compareTo(b.orden));
    return Ruta(
      origenLatitud: (json['origen_latitud'] as num).toDouble(),
      origenLongitud: (json['origen_longitud'] as num).toDouble(),
      origenEsPosicionReal: json['origen_es_posicion_real'] as bool? ?? false,
      paradas: paradas,
      totalKm: (json['total_km'] as num? ?? 0).toDouble(),
      tiempoTotalMinutos: json['tiempo_total_minutos'] as int? ?? 0,
    );
  }
}

/// Una entrega hecha con su tarifa y comisión.
class Liquidacion {
  const Liquidacion({
    required this.id,
    required this.pedido,
    required this.fecha,
    required this.tarifa,
    required this.comisionPorcentaje,
    required this.comision,
    required this.pagada,
    required this.fechaPago,
  });

  final int id;
  final String pedido;
  final DateTime? fecha;
  final double tarifa;
  final double comisionPorcentaje;
  final double comision;
  final bool pagada;
  final DateTime? fechaPago;

  factory Liquidacion.fromJson(Map<String, dynamic> json) => Liquidacion(
        id: json['id'] as int,
        pedido: json['pedido'] as String,
        fecha: leerFecha(json['fecha']),
        tarifa: (json['tarifa'] as num).toDouble(),
        comisionPorcentaje: (json['comision_porcentaje'] as num).toDouble(),
        comision: (json['comision'] as num).toDouble(),
        pagada: json['pagada'] as bool? ?? false,
        fechaPago: leerFecha(json['fecha_pago']),
      );
}

class ResumenLiquidacion {
  const ResumenLiquidacion({
    required this.items,
    required this.totalComision,
    required this.totalPendiente,
    required this.totalPagado,
  });

  final List<Liquidacion> items;
  final double totalComision;
  final double totalPendiente;
  final double totalPagado;

  factory ResumenLiquidacion.fromJson(Map<String, dynamic> json) => ResumenLiquidacion(
        items: [
          for (final i in (json['items'] as List? ?? const []))
            Liquidacion.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
        totalComision: (json['total_comision'] as num? ?? 0).toDouble(),
        totalPendiente: (json['total_pendiente'] as num? ?? 0).toDouble(),
        totalPagado: (json['total_pagado'] as num? ?? 0).toDouble(),
      );
}

/// El QR del paquete lleva el código del pedido (p. ej. «PED-0007»).
PedidoResumen? pedidoDeCodigo(List<PedidoResumen> pedidos, String codigo) {
  final limpio = codigo.trim().toUpperCase();
  for (final pedido in pedidos) {
    if (pedido.codigo.trim().toUpperCase() == limpio) return pedido;
  }
  return null;
}
