import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/vista_async.dart';
import 'api_operario.dart';
import 'modelos_operario.dart';

/// «18:00» o «18:00:00» → (18, 0).
(int, int)? _leerHora(String? texto) {
  final partes = texto?.split(':');
  if (partes == null || partes.length < 2) return null;
  final h = int.tryParse(partes[0]);
  final m = int.tryParse(partes[1]);
  if (h == null || m == null) return null;
  return (h, m);
}

String _horaCorta(String texto) {
  final hm = _leerHora(texto);
  return hm == null ? texto : horaApi(hm.$1, hm.$2);
}

/// «Mi jornada»: horario de hoy, horas extra y la solicitud de horas extra.
class PantallaJornada extends ConsumerWidget {
  const PantallaJornada({super.key});

  Future<void> _recargar(WidgetRef ref) async {
    ref.invalidate(jornadaHoyProvider);
    ref.invalidate(horasExtraProvider);
    try {
      await Future.wait([ref.read(jornadaHoyProvider.future), ref.read(horasExtraProvider.future)]);
    } catch (_) {
      // El error se ve en cada sección.
    }
  }

  Future<void> _solicitar(BuildContext context, WidgetRef ref, JornadaHoy? jornada) async {
    final enviada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SolicitarHoraExtra(horaSalida: jornada?.horaSalida),
    );
    if (enviada == true && context.mounted) {
      mostrarMensaje(context, 'Solicitud enviada. Cuenta cuando gerencia la apruebe.');
      ref.invalidate(horasExtraProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jornada = ref.watch(jornadaHoyProvider);
    final horasExtra = ref.watch(horasExtraProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi jornada')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _solicitar(context, ref, jornada.valueOrNull),
        icon: const Icon(Icons.more_time),
        label: const Text('Solicitar horas extra'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _recargar(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const TituloSeccion('Hoy'),
            VistaAsync(
              valor: jornada,
              alReintentar: () => _recargar(ref),
              datos: (datos) => _TarjetaHoy(jornada: datos),
            ),
            const TituloSeccion('Mis horas extra'),
            VistaAsync(
              valor: horasExtra,
              alReintentar: () => _recargar(ref),
              datos: (lista) => lista.isEmpty
                  ? const ListaVacia(icono: Icons.more_time, texto: 'Aún no tienes horas extra.')
                  : Column(children: [for (final h in lista) _TarjetaHoraExtra(horaExtra: h)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaHoy extends StatelessWidget {
  const _TarjetaHoy({required this.jornada});

  final JornadaHoy jornada;

  Widget _fila(IconData icono, String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icono, size: 20, color: ColoresNovaTech.azul),
            const SizedBox(width: 8),
            Expanded(child: Text(etiqueta)),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final entrada = jornada.entradaReal;
    final extra = jornada.horaExtraHasta;
    final sesion = jornada.sesionHasta;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _fila(Icons.schedule, 'Horario', '${_horaCorta(jornada.horaInicio)} – ${_horaCorta(jornada.horaSalida)}'),
            _fila(Icons.login, 'Entrada', entrada != null ? hora(entrada) : 'sin registrar'),
            if (extra != null) _fila(Icons.more_time, 'Horas extra aprobadas hasta', _horaCorta(extra)),
            if (sesion != null) _fila(Icons.lock_clock, 'Tu sesión dura hasta', hora(sesion)),
            if (jornada.avisoSalida)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tu jornada termina en ${jornada.minutosParaSalida} minutos.',
                  style: const TextStyle(color: ColoresNovaTech.naranja, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaHoraExtra extends StatelessWidget {
  const _TarjetaHoraExtra({required this.horaExtra});

  final HoraExtra horaExtra;

  @override
  Widget build(BuildContext context) {
    final color = switch (horaExtra.estado) {
      EstadoHoraExtra.aprobada => ColoresNovaTech.verde,
      EstadoHoraExtra.rechazada => ColoresNovaTech.rojo,
      EstadoHoraExtra.solicitada => ColoresNovaTech.naranja,
    };
    final detalles = [
      if (horaExtra.motivo != null) horaExtra.motivo!.etiqueta,
      if (horaExtra.esCorreccion) 'corrección',
      if (horaExtra.resueltaPor != null) 'por ${horaExtra.resueltaPor}',
    ];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.more_time),
        title: Text('${diaRelativo(horaExtra.fecha)} · hasta las ${_horaCorta(horaExtra.horaFin)}'),
        subtitle: detalles.isEmpty ? null : Text(detalles.join(' · ')),
        trailing: Chip(
          label: Text(horaExtra.estado.etiqueta, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// Hoja para pedir horas extra: día, hora y motivo se eligen, no se escriben.
class _SolicitarHoraExtra extends ConsumerStatefulWidget {
  const _SolicitarHoraExtra({this.horaSalida});

  final String? horaSalida;

  @override
  ConsumerState<_SolicitarHoraExtra> createState() => _SolicitarHoraExtraState();
}

class _SolicitarHoraExtraState extends ConsumerState<_SolicitarHoraExtra> {
  late DateTime _fecha;
  late TimeOfDay _hora;
  MotivoHoraExtra? _motivo;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fecha = soloFecha(DateTime.now());
    // Sugerencia: una hora después de la salida normal.
    final salida = _leerHora(widget.horaSalida) ?? (17, 0);
    _hora = TimeOfDay(hour: (salida.$1 + 1).clamp(0, 23), minute: salida.$2);
  }

  Future<void> _elegirDia() async {
    final hoy = soloFecha(DateTime.now());
    final elegido = await showDatePicker(
      context: context,
      initialDate: _fecha,
      // Hasta 7 días atrás es una solicitud de corrección.
      firstDate: hoy.subtract(const Duration(days: 7)),
      lastDate: hoy.add(const Duration(days: 30)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Día de las horas extra',
    );
    if (elegido != null) setState(() => _fecha = elegido);
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: _hora,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      helpText: 'Hasta qué hora',
    );
    if (elegida != null) setState(() => _hora = elegida);
  }

  Future<void> _enviar() async {
    final motivo = _motivo;
    if (motivo == null) {
      setState(() => _error = 'Elige el motivo.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref.read(apiOperarioProvider).solicitarHoraExtra(
            fecha: _fecha,
            horas: _hora.hour,
            minutos: _hora.minute,
            motivo: motivo,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorDesde(e).mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = soloFecha(DateTime.now());
    final esCorreccion = _fecha.isBefore(hoy);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Solicitar horas extra', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Solo cuentan cuando gerencia las aprueba.', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            const Text('Día', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Hoy'),
                  selected: _fecha == hoy,
                  onSelected: (_) => setState(() => _fecha = hoy),
                ),
                ChoiceChip(
                  label: const Text('Mañana'),
                  selected: _fecha == hoy.add(const Duration(days: 1)),
                  onSelected: (_) => setState(() => _fecha = hoy.add(const Duration(days: 1))),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    _fecha == hoy || _fecha == hoy.add(const Duration(days: 1))
                        ? 'Otro día'
                        : diaRelativo(_fecha),
                  ),
                  onPressed: _elegirDia,
                ),
              ],
            ),
            if (esCorreccion)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Es un día pasado: se enviará como corrección.',
                  style: TextStyle(color: ColoresNovaTech.naranja),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Hasta qué hora', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _elegirHora,
              icon: const Icon(Icons.access_time),
              label: Text(horaApi(_hora.hour, _hora.minute), style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 16),
            const Text('Motivo', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final motivo in MotivoHoraExtra.values)
                  ChoiceChip(
                    label: Text(motivo.etiqueta),
                    selected: _motivo == motivo,
                    onSelected: (_) => setState(() => _motivo = motivo),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: ColoresNovaTech.rojo)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Enviar solicitud'),
            ),
          ],
        ),
      ),
    );
  }
}
