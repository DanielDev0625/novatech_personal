import '../../core/formato.dart';

double _num(Object? valor) => (valor as num? ?? 0).toDouble();

class Equipo {
  const Equipo({required this.id, required this.nombre, required this.potenciaKw, required this.tipo, required this.activo});

  final int id;
  final String nombre;
  final double potenciaKw;

  /// «jornada» (solo en horas de trabajo) o «continuo» (24 h).
  final String tipo;
  final bool activo;

  factory Equipo.fromJson(Map<String, dynamic> json) => Equipo(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        potenciaKw: _num(json['potencia_kw']),
        tipo: json['tipo'] as String? ?? 'jornada',
        activo: json['activo'] as bool? ?? true,
      );
}

class Zona {
  const Zona({
    required this.id,
    required this.nombre,
    required this.umbralKwhMensual,
    required this.potenciaTotalKw,
    required this.equipos,
  });

  final int id;
  final String nombre;
  final double? umbralKwhMensual;
  final double potenciaTotalKw;
  final List<Equipo> equipos;

  factory Zona.fromJson(Map<String, dynamic> json) => Zona(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        umbralKwhMensual: (json['umbral_kwh_mensual'] as num?)?.toDouble(),
        potenciaTotalKw: _num(json['potencia_total_kw']),
        equipos: [
          for (final e in (json['equipos'] as List? ?? const [])) Equipo.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
}

class EntradaBitacora {
  const EntradaBitacora({required this.fecha, required this.usuario, required this.accion, required this.detalle});

  final DateTime? fecha;
  final String? usuario;
  final String accion;
  final String? detalle;

  factory EntradaBitacora.fromJson(Map<String, dynamic> json) => EntradaBitacora(
        fecha: leerFecha(json['fecha']),
        usuario: json['usuario'] as String?,
        accion: json['accion'] as String? ?? '',
        detalle: json['detalle'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Parámetros
// ---------------------------------------------------------------------------

/// Busca la primera clave de [claves] en [datos], también dentro de mapas anidados
/// (la respuesta de GET /configuracion puede venir agrupada por tema).
Object? buscarClave(Object? datos, List<String> claves) {
  if (datos is Map) {
    for (final clave in claves) {
      if (datos.containsKey(clave) && datos[clave] is! Map) return datos[clave];
    }
    for (final valor in datos.values) {
      final encontrado = buscarClave(valor, claves);
      if (encontrado != null) return encontrado;
    }
  }
  return null;
}

double? buscarNumero(Object? datos, List<String> claves) {
  final valor = buscarClave(datos, claves);
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor.replaceAll(',', '.'));
  return null;
}

String? buscarHora(Object? datos, List<String> claves) {
  final valor = buscarClave(datos, claves);
  return valor is String && leerHora(valor) != null ? valor : null;
}

/// Parámetros que se pueden cambiar. Un valor null es que el servidor no lo envió:
/// ese grupo no se edita, para no reemplazarlo por un valor inventado.
class Parametros {
  Parametros({
    this.margen,
    this.plazoEntregaDias,
    this.plazoCompraDias,
    this.tarifaEntrega,
    this.comisionPorcentaje,
    this.horaInicio,
    this.horaSalida,
    this.topeHorasExtra,
    this.tarifaKwh,
    this.factorCo2,
    this.aumentoAlertaPorcentaje,
    this.alistamientoMinutos,
    this.rutaMinutos,
  });

  double? margen;
  double? plazoEntregaDias;
  double? plazoCompraDias;
  double? tarifaEntrega;
  double? comisionPorcentaje;
  String? horaInicio;
  String? horaSalida;
  double? topeHorasExtra;
  double? tarifaKwh;
  double? factorCo2;
  double? aumentoAlertaPorcentaje;
  double? alistamientoMinutos;
  double? rutaMinutos;

  factory Parametros.desde(Object? config) => Parametros(
        margen: buscarNumero(config, ['margen', 'margen_porcentaje', 'margen_venta']),
        plazoEntregaDias: buscarNumero(config, ['plazo_entrega_dias', 'plazo_entrega', 'dias_entrega']),
        plazoCompraDias: buscarNumero(config, ['plazo_compra_dias', 'plazo_compra', 'dias_compra']),
        tarifaEntrega: buscarNumero(config, ['tarifa_entrega', 'tarifa_por_entrega']),
        comisionPorcentaje: buscarNumero(config, ['comision_porcentaje', 'comision']),
        horaInicio: buscarHora(config, ['hora_inicio', 'jornada_inicio', 'hora_inicio_jornada']),
        horaSalida: buscarHora(config, ['hora_salida', 'jornada_salida', 'hora_salida_jornada']),
        topeHorasExtra: buscarNumero(config, ['tope_horas_extra', 'tope_horas_extra_dia']),
        tarifaKwh: buscarNumero(config, ['tarifa_kwh', 'tarifa_energia']),
        factorCo2: buscarNumero(config, ['factor_co2', 'factor_emision_co2']),
        aumentoAlertaPorcentaje: buscarNumero(config, ['aumento_alerta_porcentaje', 'porcentaje_alerta']),
        alistamientoMinutos: buscarNumero(config, ['alistamiento_minutos', 'etapa_alistamiento_minutos']),
        rutaMinutos: buscarNumero(config, ['ruta_minutos', 'etapa_ruta_minutos']),
      );

  Parametros copia() => Parametros(
        margen: margen,
        plazoEntregaDias: plazoEntregaDias,
        plazoCompraDias: plazoCompraDias,
        tarifaEntrega: tarifaEntrega,
        comisionPorcentaje: comisionPorcentaje,
        horaInicio: horaInicio,
        horaSalida: horaSalida,
        topeHorasExtra: topeHorasExtra,
        tarifaKwh: tarifaKwh,
        factorCo2: factorCo2,
        aumentoAlertaPorcentaje: aumentoAlertaPorcentaje,
        alistamientoMinutos: alistamientoMinutos,
        rutaMinutos: rutaMinutos,
      );

  /// El margen puede venir como fracción (0,18) o como porcentaje (18).
  bool get margenEsFraccion => (margen ?? 0) <= 1;

  bool get conLiquidacion => tarifaEntrega != null && comisionPorcentaje != null;
  bool get conJornada => horaInicio != null && horaSalida != null && topeHorasExtra != null;
  bool get conEnergia => tarifaKwh != null && factorCo2 != null && aumentoAlertaPorcentaje != null;
  bool get conEtapas => alistamientoMinutos != null && rutaMinutos != null;

  /// Peticiones (ruta, cuerpo) para guardar solo lo que cambió frente a [original].
  List<(String, Map<String, dynamic>)> cambiosFrente(Parametros original) {
    bool distinto(Object? a, Object? b) => a != b;
    return [
      if (margen != null && distinto(margen, original.margen)) ('/configuracion/margen', {'margen': margen}),
      if (plazoEntregaDias != null && distinto(plazoEntregaDias, original.plazoEntregaDias))
        ('/configuracion/plazo-entrega', {'dias': plazoEntregaDias!.round()}),
      if (plazoCompraDias != null && distinto(plazoCompraDias, original.plazoCompraDias))
        ('/configuracion/plazo-compra', {'dias': plazoCompraDias!.round()}),
      if (conLiquidacion &&
          (distinto(tarifaEntrega, original.tarifaEntrega) ||
              distinto(comisionPorcentaje, original.comisionPorcentaje)))
        ('/configuracion/liquidacion', {'tarifa_entrega': tarifaEntrega, 'comision_porcentaje': comisionPorcentaje}),
      if (conJornada &&
          (distinto(horaInicio, original.horaInicio) ||
              distinto(horaSalida, original.horaSalida) ||
              distinto(topeHorasExtra, original.topeHorasExtra)))
        (
          '/configuracion/jornada',
          {'hora_inicio': _hhmm(horaInicio!), 'hora_salida': _hhmm(horaSalida!), 'tope_horas_extra': topeHorasExtra},
        ),
      if (conEnergia &&
          (distinto(tarifaKwh, original.tarifaKwh) ||
              distinto(factorCo2, original.factorCo2) ||
              distinto(aumentoAlertaPorcentaje, original.aumentoAlertaPorcentaje)))
        (
          '/configuracion/energia',
          {'tarifa_kwh': tarifaKwh, 'factor_co2': factorCo2, 'aumento_alerta_porcentaje': aumentoAlertaPorcentaje},
        ),
      if (conEtapas &&
          (distinto(alistamientoMinutos, original.alistamientoMinutos) ||
              distinto(rutaMinutos, original.rutaMinutos)))
        (
          '/configuracion/etapas',
          {'alistamiento_minutos': alistamientoMinutos!.round(), 'ruta_minutos': rutaMinutos!.round()},
        ),
    ];
  }
}

String _hhmm(String hora) {
  final hm = leerHora(hora)!;
  return horaApi(hm.$1, hm.$2);
}
