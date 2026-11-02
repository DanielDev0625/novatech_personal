import '../../core/api/modelos.dart';
import '../../core/formato.dart';

double _num(Object? valor) => (valor as num? ?? 0).toDouble();
double? _numONulo(Object? valor) => (valor as num?)?.toDouble();

List<Map<String, dynamic>> _lista(Object? valor) =>
    [for (final item in (valor as List? ?? const [])) Map<String, dynamic>.from(item as Map)];

/// Tarjetas del «Panel del día».
class Panel {
  const Panel({
    required this.pedidos,
    required this.ventasTotal,
    required this.porcentajeATiempo,
    required this.pedidosVencidos,
    required this.productosStockBajo,
    required this.comprasPendientes,
    required this.mercanciaAtrasada,
    required this.jornadasSinSalida,
    required this.horasExtraTotal,
    required this.energiaKwh,
    required this.energiaCosto,
  });

  final int pedidos;
  final double ventasTotal;
  final double? porcentajeATiempo;
  final int pedidosVencidos;
  final int productosStockBajo;
  final int comprasPendientes;
  final int mercanciaAtrasada;
  final int jornadasSinSalida;
  final double horasExtraTotal;
  final double energiaKwh;
  final double energiaCosto;

  factory Panel.fromJson(Map<String, dynamic> json) => Panel(
        pedidos: json['pedidos'] as int? ?? 0,
        ventasTotal: _num(json['ventas_total']),
        porcentajeATiempo: _numONulo(json['porcentaje_a_tiempo']),
        pedidosVencidos: json['pedidos_vencidos_en_curso'] as int? ?? 0,
        productosStockBajo: json['productos_stock_bajo'] as int? ?? 0,
        comprasPendientes: json['compras_pendientes'] as int? ?? 0,
        mercanciaAtrasada: json['mercancia_atrasada'] as int? ?? 0,
        jornadasSinSalida: json['jornadas_salida_no_registrada'] as int? ?? 0,
        horasExtraTotal: _num(json['horas_extra_total']),
        energiaKwh: _num(json['energia_kwh']),
        energiaCosto: _num(json['energia_costo']),
      );
}

/// Un transportista visto desde gerencia.
class TransportistaEstado {
  const TransportistaEstado({required this.nombre, required this.placa, required this.entregasActivas});

  final String nombre;
  final String? placa;
  final int entregasActivas;

  bool get enRuta => entregasActivas > 0;

  factory TransportistaEstado.fromJson(Map<String, dynamic> json) => TransportistaEstado(
        nombre: json['nombre'] as String? ?? '',
        placa: json['placa'] as String?,
        entregasActivas: json['entregas_activas'] as int? ?? 0,
      );
}

/// Persona con horario (operario o transportista) para programar horas extra.
class HorarioPersona {
  const HorarioPersona({
    required this.usuarioId,
    required this.nombre,
    required this.rol,
    required this.horaInicio,
    required this.horaSalida,
  });

  final int usuarioId;
  final String nombre;
  final Rol rol;
  final String horaInicio;
  final String horaSalida;

  factory HorarioPersona.fromJson(Map<String, dynamic> json) => HorarioPersona(
        usuarioId: json['usuario_id'] as int,
        nombre: json['nombre'] as String? ?? '',
        rol: Rol.desde(json['rol'] as String?),
        horaInicio: json['hora_inicio'] as String? ?? '',
        horaSalida: json['hora_salida'] as String? ?? '',
      );
}

// ---- Estadísticas ----

class ProductoVenta {
  const ProductoVenta({required this.nombre, required this.categoria, required this.unidades, required this.ingresos});

  final String nombre;
  final String categoria;
  final int unidades;
  final double ingresos;

  factory ProductoVenta.fromJson(Map<String, dynamic> json) => ProductoVenta(
        nombre: json['nombre'] as String? ?? '',
        categoria: json['categoria'] as String? ?? '',
        unidades: json['unidades'] as int? ?? 0,
        ingresos: _num(json['ingresos']),
      );
}

class VentaCategoria {
  const VentaCategoria({
    required this.categoria,
    required this.unidades,
    required this.ingresos,
    required this.porcentaje,
  });

  final String categoria;
  final int unidades;
  final double ingresos;
  final double porcentaje;

  factory VentaCategoria.fromJson(Map<String, dynamic> json) => VentaCategoria(
        categoria: json['categoria'] as String? ?? '',
        unidades: json['unidades'] as int? ?? 0,
        ingresos: _num(json['ingresos']),
        porcentaje: _num(json['porcentaje_ingresos']),
      );
}

class EtapaEntrega {
  const EtapaEntrega({
    required this.etapa,
    required this.promedioMinutos,
    required this.esperadoMinutos,
    required this.porcentajeFueraDePlazo,
  });

  final String etapa;
  final double? promedioMinutos;
  final int? esperadoMinutos;
  final double? porcentajeFueraDePlazo;

  factory EtapaEntrega.fromJson(Map<String, dynamic> json) => EtapaEntrega(
        etapa: json['etapa'] as String? ?? '',
        promedioMinutos: _numONulo(json['promedio_minutos']),
        esperadoMinutos: json['esperado_minutos'] as int?,
        porcentajeFueraDePlazo: _numONulo(json['porcentaje_fuera_de_plazo']),
      );
}

class EstadisticaEntregas {
  const EstadisticaEntregas({
    required this.entregadas,
    required this.aTiempo,
    required this.tardias,
    required this.porcentajeATiempo,
    required this.retrasoPromedioHoras,
    required this.etapas,
  });

  final int entregadas;
  final int aTiempo;
  final int tardias;
  final double? porcentajeATiempo;
  final double? retrasoPromedioHoras;
  final List<EtapaEntrega> etapas;

  factory EstadisticaEntregas.fromJson(Map<String, dynamic> json) => EstadisticaEntregas(
        entregadas: json['entregadas'] as int? ?? 0,
        aTiempo: json['a_tiempo'] as int? ?? 0,
        tardias: json['tardias'] as int? ?? 0,
        porcentajeATiempo: _numONulo(json['porcentaje_a_tiempo']),
        retrasoPromedioHoras: _numONulo(json['retraso_promedio_horas']),
        etapas: _lista(json['etapas']).map(EtapaEntrega.fromJson).toList(),
      );
}

class StockBajo {
  const StockBajo({
    required this.nombre,
    required this.stock,
    required this.stockMinimo,
    required this.compra,
    required this.compraEstado,
  });

  final String nombre;
  final int stock;
  final int stockMinimo;

  /// Código de la compra de reposición, si ya hay una.
  final String? compra;
  final String? compraEstado;

  factory StockBajo.fromJson(Map<String, dynamic> json) => StockBajo(
        nombre: json['nombre'] as String? ?? '',
        stock: json['stock'] as int? ?? 0,
        stockMinimo: json['stock_minimo'] as int? ?? 0,
        compra: json['compra'] as String?,
        compraEstado: json['compra_estado'] as String?,
      );
}

/// Todo lo que muestra la pantalla de estadísticas para un período.
class Estadisticas {
  const Estadisticas({
    required this.masVendido,
    required this.productos,
    required this.totalIngresos,
    required this.categorias,
    required this.entregas,
    required this.stockBajo,
  });

  final ProductoVenta? masVendido;
  final List<ProductoVenta> productos;
  final double totalIngresos;
  final List<VentaCategoria> categorias;
  final EstadisticaEntregas entregas;
  final List<StockBajo> stockBajo;

  /// Productos con stock bajo que ya tienen una compra en camino.
  int get reposicionesPendientes => stockBajo.where((s) => s.compra != null).length;

  factory Estadisticas.desde({
    required Map<String, dynamic> productos,
    required Map<String, dynamic> categorias,
    required Map<String, dynamic> entregas,
    required List<dynamic> stockBajo,
  }) {
    final masVendido = productos['mas_vendido'];
    return Estadisticas(
      masVendido: masVendido is Map ? ProductoVenta.fromJson(Map<String, dynamic>.from(masVendido)) : null,
      productos: _lista(productos['productos']).map(ProductoVenta.fromJson).toList(),
      totalIngresos: _num(categorias['total_ingresos']),
      categorias: _lista(categorias['categorias']).map(VentaCategoria.fromJson).toList()
        ..sort((a, b) => b.ingresos.compareTo(a.ingresos)),
      entregas: EstadisticaEntregas.fromJson(entregas),
      stockBajo: _lista(stockBajo).map(StockBajo.fromJson).toList(),
    );
  }
}

// ---- Energía ----

class ConsumoZona {
  const ConsumoZona({required this.zona, required this.kwh, required this.costo, required this.co2Kg});

  final String zona;
  final double kwh;
  final double costo;
  final double co2Kg;

  factory ConsumoZona.fromJson(Map<String, dynamic> json) => ConsumoZona(
        zona: json['zona'] as String? ?? '',
        kwh: _num(json['kwh']),
        costo: _num(json['costo']),
        co2Kg: _num(json['co2_kg']),
      );
}

class Consumo {
  const Consumo({
    required this.totalKwh,
    required this.totalCosto,
    required this.totalCo2Kg,
    required this.kwhPorPedido,
    required this.pedidosDespachados,
    required this.zonas,
  });

  final double totalKwh;
  final double totalCosto;
  final double totalCo2Kg;
  final double? kwhPorPedido;
  final int pedidosDespachados;
  final List<ConsumoZona> zonas;

  factory Consumo.fromJson(Map<String, dynamic> json) => Consumo(
        totalKwh: _num(json['total_kwh']),
        totalCosto: _num(json['total_costo']),
        totalCo2Kg: _num(json['total_co2_kg']),
        kwhPorPedido: _numONulo(json['kwh_por_pedido']),
        pedidosDespachados: json['pedidos_despachados'] as int? ?? 0,
        zonas: _lista(json['zonas']).map(ConsumoZona.fromJson).toList()..sort((a, b) => b.kwh.compareTo(a.kwh)),
      );
}

class AlertaEnergia {
  const AlertaEnergia({required this.zona, required this.mensaje});

  final String zona;
  final String mensaje;

  factory AlertaEnergia.fromJson(Map<String, dynamic> json) => AlertaEnergia(
        zona: json['zona'] as String? ?? '',
        mensaje: json['mensaje'] as String? ?? '',
      );
}

/// Período de las estadísticas: «Semana» o «Mes».
enum Periodo {
  semana('Semana', 7),
  mes('Mes', 30);

  const Periodo(this.etiqueta, this.dias);
  final String etiqueta;
  final int dias;

  /// Desde hace [dias] hasta hoy (incluido).
  (DateTime, DateTime) rango({DateTime? hoy}) {
    final fin = soloFecha(hoy ?? DateTime.now());
    return (fin.subtract(Duration(days: dias - 1)), fin);
  }
}

/// Lunes de la semana de [dia].
DateTime lunesDe(DateTime dia) {
  final d = soloFecha(dia);
  return d.subtract(Duration(days: d.weekday - 1));
}
