// Formatos de fecha y hora para mostrar en pantalla (sin depender de intl).

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

String _dos(int n) => n.toString().padLeft(2, '0');

/// «14:05»
String hora(DateTime fecha) => '${_dos(fecha.hour)}:${_dos(fecha.minute)}';

/// «3 nov»
String fechaCorta(DateTime fecha) => '${fecha.day} ${_meses[fecha.month - 1]}';

/// «3 nov, 14:05»
String fechaHora(DateTime fecha) => '${fechaCorta(fecha)}, ${hora(fecha)}';

/// «hoy», «mañana», «ayer» o «martes 3 nov».
String diaRelativo(DateTime fecha, {DateTime? ahora}) {
  final hoy = soloFecha(ahora ?? DateTime.now());
  final dia = soloFecha(fecha);
  final diferencia = dia.difference(hoy).inDays;
  if (diferencia == 0) return 'hoy';
  if (diferencia == 1) return 'mañana';
  if (diferencia == -1) return 'ayer';
  return '${_dias[dia.weekday - 1]} ${fechaCorta(dia)}';
}

DateTime soloFecha(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

/// Fecha que espera el backend: «2026-11-03».
String fechaApi(DateTime fecha) => '${fecha.year}-${_dos(fecha.month)}-${_dos(fecha.day)}';

/// Hora que espera el backend: «18:30».
String horaApi(int horas, int minutos) => '${_dos(horas)}:${_dos(minutos)}';

/// Lee una fecha del servidor y la pasa a hora local. null si no viene o no se entiende.
DateTime? leerFecha(Object? valor) {
  if (valor is! String) return null;
  return DateTime.tryParse(valor)?.toLocal();
}

/// «$ 12.500» (pesos, sin decimales y con punto de miles).
String pesos(num valor) {
  final entero = valor.round();
  final digitos = entero.abs().toString();
  final grupos = <String>[];
  for (var fin = digitos.length; fin > 0; fin -= 3) {
    grupos.insert(0, digitos.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
  }
  return '${entero < 0 ? '-' : ''}\$ ${grupos.join('.')}';
}

/// «850 m» o «3,4 km».
String distancia(num km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// «45 min» o «1 h 20 min».
String duracion(int minutos) {
  if (minutos < 60) return '$minutos min';
  final resto = minutos % 60;
  return resto == 0 ? '${minutos ~/ 60} h' : '${minutos ~/ 60} h $resto min';
}

/// «hace 5 min», «hace 3 h», «hace 2 días».
String antiguedad(DateTime fecha, {DateTime? ahora}) {
  final minutos = (ahora ?? DateTime.now()).difference(fecha).inMinutes;
  if (minutos < 1) return 'recién';
  if (minutos < 60) return 'hace $minutos min';
  final horas = minutos ~/ 60;
  if (horas < 24) return 'hace $horas h';
  final dias = horas ~/ 24;
  return dias == 1 ? 'hace 1 día' : 'hace $dias días';
}
