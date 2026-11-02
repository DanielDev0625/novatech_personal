import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/modelos.dart';
import '../../core/api/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/aviso_salida.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_operario.dart';
import 'modelos_operario.dart';

/// Color de cada estado de una hora extra.
Color colorHoraExtra(EstadoHoraExtra estado) => switch (estado) {
      EstadoHoraExtra.aprobada => ColoresNovaTech.verde,
      EstadoHoraExtra.rechazada => ColoresNovaTech.rojo,
      EstadoHoraExtra.solicitada => ColoresNovaTech.naranja,
    };

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

    return EsqueletoRol(
      titulo: 'Mi jornada',
      alRecargar: () => _recargar(ref),
      accionInferior: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ColoresNovaTech.naranja),
        onPressed: () => _solicitar(context, ref, jornada.valueOrNull),
        child: const Text('Solicitar horas extra'),
      ),
      hijos: [
        const AvisoSalida(),
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
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, h) in lista.indexed) ...[
                          if (i > 0) const Divider(indent: 14, endIndent: 14),
                          _FilaHoraExtra(horaExtra: h),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Las horas extra programadas vencen el domingo a medianoche.',
            style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _TarjetaHoy extends StatelessWidget {
  const _TarjetaHoy({required this.jornada});

  final JornadaHoy jornada;

  Widget _fila(String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(etiqueta, style: const TextStyle(color: ColoresNovaTech.textoSuave))),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      );

  /// Parte del día de trabajo que ya pasó (0 a 1).
  double _avance() {
    final inicio = leerHora(jornada.horaInicio);
    final salida = leerHora(jornada.horaSalida);
    if (inicio == null || salida == null) return 0;
    final ahora = DateTime.now();
    final minutosAhora = ahora.hour * 60 + ahora.minute;
    final desde = inicio.$1 * 60 + inicio.$2;
    final hasta = salida.$1 * 60 + salida.$2;
    if (hasta <= desde) return 0;
    return ((minutosAhora - desde) / (hasta - desde)).clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final entrada = jornada.entradaReal;
    final extra = jornada.horaExtraHasta;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fila('Entrada real', entrada != null ? hora(entrada) : '—'),
            _fila('Salida configurada', horaCorta(jornada.horaSalida)),
            if (extra != null) _fila('Horas extra hasta', horaCorta(extra)),
            const SizedBox(height: 10),
            BarraAvance(valor: _avance(), color: ColoresNovaTech.azul),
            const SizedBox(height: 10),
            Insignia(
              texto: entrada == null ? 'Estado: sin entrada' : 'Estado: en curso',
              color: entrada == null ? ColoresNovaTech.naranja : ColoresNovaTech.verde,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaHoraExtra extends StatelessWidget {
  const _FilaHoraExtra({required this.horaExtra});

  final HoraExtra horaExtra;

  @override
  Widget build(BuildContext context) {
    final detalles = [
      if (horaExtra.motivo != null) horaExtra.motivo!.etiqueta,
      if (horaExtra.esCorreccion) 'corrección',
      if (horaExtra.resueltaPor != null) 'por ${horaExtra.resueltaPor}',
    ];
    final dia = diaRelativo(horaExtra.fecha);
    return ListTile(
      title: Text('${dia[0].toUpperCase()}${dia.substring(1)}'),
      subtitle: detalles.isEmpty ? null : Text(detalles.join(' · ')),
      trailing: Insignia(
        texto: horaExtra.estado == EstadoHoraExtra.aprobada
            ? 'hasta ${horaCorta(horaExtra.horaFin)}'
            : '${horaExtra.estado.etiqueta} · ${horaCorta(horaExtra.horaFin)}',
        color: colorHoraExtra(horaExtra.estado),
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
    final salida = leerHora(widget.horaSalida) ?? (17, 0);
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
            const Text('Solo cuentan cuando gerencia las aprueba.', style: TextStyle(color: ColoresNovaTech.textoSuave)),
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
