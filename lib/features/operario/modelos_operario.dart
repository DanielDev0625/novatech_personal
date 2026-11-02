import '../../core/formato.dart';

// ---------------------------------------------------------------------------
// Pedidos (alistamiento)
// ---------------------------------------------------------------------------

/// Un producto dentro del pedido.
class LineaPedido {
  const LineaPedido({
    required this.productoId,
    required this.sku,
    required this.nombre,
    required this.cantidad,
  });

  final int productoId;
  final String sku;
  final String nombre;
  final int cantidad;

  factory LineaPedido.fromJson(Map<String, dynamic> json) => LineaPedido(
        productoId: json['producto_id'] as int,
        sku: json['sku'] as String,
        nombre: json['nombre'] as String,
        cantidad: json['cantidad'] as int,
      );
}

class Pedido {
  const Pedido({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.cliente,
    required this.fechaPrometida,
    required this.lineas,
  });

  final int id;
  final String codigo;
  final String estado;
  final String? cliente;
  final DateTime? fechaPrometida;
  final List<LineaPedido> lineas;

  bool get alistando => estado == 'alistando';

  factory Pedido.fromJson(Map<String, dynamic> json) => Pedido(
        id: json['id'] as int,
        codigo: json['codigo'] as String,
        estado: json['estado'] as String,
        cliente: json['cliente'] as String?,
        fechaPrometida: leerFecha(json['fecha_prometida']),
        lineas: [
          for (final linea in (json['lineas'] as List? ?? const []))
            LineaPedido.fromJson(Map<String, dynamic>.from(linea as Map)),
        ],
      );
}

/// Qué pasó con una lectura del escáner.
enum ResultadoLectura {
  /// Se sumó una unidad.
  sumado,

  /// El producto es del pedido, pero ya están todas sus unidades.
  yaCompleto,

  /// El código no corresponde a ningún producto del pedido.
  noEsDelPedido,
}

/// Cuenta lo escaneado contra lo pedido. El código que lee la cámara es el SKU.
class ConteoAlistamiento {
  ConteoAlistamiento(this.lineas, [Map<int, int>? inicial])
      : _escaneados = {for (final l in lineas) l.productoId: inicial?[l.productoId] ?? 0};

  final List<LineaPedido> lineas;
  final Map<int, int> _escaneados;

  int escaneados(int productoId) => _escaneados[productoId] ?? 0;

  /// Copia de lo contado, para guardarlo mientras se navega.
  Map<int, int> get comoMapa => Map.of(_escaneados);

  int get totalPedido => lineas.fold(0, (suma, l) => suma + l.cantidad);
  int get totalEscaneado => _escaneados.values.fold(0, (suma, n) => suma + n);

  bool lineaCompleta(LineaPedido linea) => escaneados(linea.productoId) == linea.cantidad;

  /// Todo lo pedido está escaneado, ni más ni menos.
  bool get completo => lineas.isNotEmpty && lineas.every(lineaCompleta);

  LineaPedido? lineaDeCodigo(String codigo) {
    final limpio = codigo.trim().toUpperCase();
    for (final linea in lineas) {
      if (linea.sku.trim().toUpperCase() == limpio) return linea;
    }
    return null;
  }

  ResultadoLectura leer(String codigo) {
    final linea = lineaDeCodigo(codigo);
    if (linea == null) return ResultadoLectura.noEsDelPedido;
    if (lineaCompleta(linea)) return ResultadoLectura.yaCompleto;
    _escaneados[linea.productoId] = escaneados(linea.productoId) + 1;
    return ResultadoLectura.sumado;
  }

  void sumar(LineaPedido linea) {
    if (!lineaCompleta(linea)) _escaneados[linea.productoId] = escaneados(linea.productoId) + 1;
  }

  void restar(LineaPedido linea) {
    final actual = escaneados(linea.productoId);
    if (actual > 0) _escaneados[linea.productoId] = actual - 1;
  }

  /// Cuerpo de POST /pedidos/{id}/listo.
  Map<String, dynamic> cuerpoListo() => {
        'escaneados': [
          for (final linea in lineas)
            if (escaneados(linea.productoId) > 0)
              {'producto_id': linea.productoId, 'cantidad': escaneados(linea.productoId)},
        ],
      };
}

/// Cómo quedaría la recepción con lo contado (lo mismo que decide el servidor).
String resumenRecepcion({required int aprobada, required int buenas, required int danadas}) {
  final llegaron = buenas + danadas;
  if (danadas == 0 && buenas == aprobada) {
    return 'Todo coincide: se creará el lote y el stock subirá.';
  }
  final partes = <String>[
    if (llegaron < aprobada) 'faltan ${aprobada - llegaron}',
    if (llegaron > aprobada) 'sobran ${llegaron - aprobada}',
    if (danadas > 0) danadas == 1 ? '1 dañada' : '$danadas dañadas',
  ];
  return 'Con diferencias (${partes.join(', ')}): quedará retenida para que gerencia decida.';
}

// ---------------------------------------------------------------------------
// Jornada y horas extra
// ---------------------------------------------------------------------------

class JornadaHoy {
  const JornadaHoy({
    required this.horaInicio,
    required this.horaSalida,
    required this.entradaReal,
    required this.horaExtraHasta,
    required this.sesionHasta,
    required this.minutosParaSalida,
    required this.avisoSalida,
  });

  final String horaInicio;
  final String horaSalida;
  final DateTime? entradaReal;
  final String? horaExtraHasta;
  final DateTime? sesionHasta;
  final int minutosParaSalida;
  final bool avisoSalida;

  factory JornadaHoy.fromJson(Map<String, dynamic> json) => JornadaHoy(
        horaInicio: json['hora_inicio'] as String,
        horaSalida: json['hora_salida'] as String,
        entradaReal: leerFecha(json['entrada_real']),
        horaExtraHasta: json['hora_extra_aprobada_hasta'] as String?,
        sesionHasta: leerFecha(json['sesion_hasta']),
        minutosParaSalida: json['minutos_para_salida'] as int? ?? 0,
        avisoSalida: json['aviso_salida'] as bool? ?? false,
      );
}
