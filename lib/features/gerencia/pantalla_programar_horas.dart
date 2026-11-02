import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/adaptable.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_gerencia.dart';
import 'modelos_gerencia.dart';

const _letrasDias = ['L', 'M', 'X', 'J', 'V', 'S'];

/// Lo que se va a programar para una persona.
class _Plan {
  _Plan(this.hora);

  /// Días de la semana elegidos (1 = lunes ... 6 = sábado).
  final Set<int> dias = {};
  TimeOfDay hora;
}

/// «Horas extra de la semana»: el gerente elige personas, días y hora de fin.
/// Quedan aprobadas de una vez, vencen el domingo y no se copian a la semana siguiente.
class PantallaProgramarHoras extends ConsumerStatefulWidget {
  const PantallaProgramarHoras({super.key});

  @override
  ConsumerState<PantallaProgramarHoras> createState() => _PantallaProgramarHorasState();
}

class _PantallaProgramarHorasState extends ConsumerState<PantallaProgramarHoras> {
  final Map<int, _Plan> _planes = {};
  bool _guardando = false;

  DateTime get _lunes => lunesDe(DateTime.now());
  DateTime _fecha(int dia) => _lunes.add(Duration(days: dia - 1));
  bool _pasado(int dia) => _fecha(dia).isBefore(soloFecha(DateTime.now()));

  TimeOfDay _sugerida(HorarioPersona persona) {
    final salida = leerHora(persona.horaSalida) ?? (17, 0);
    return TimeOfDay(hour: (salida.$1 + 2).clamp(0, 23), minute: salida.$2);
  }

  Future<void> _agregar(List<HorarioPersona> personas) async {
    final disponibles = personas.where((p) => !_planes.containsKey(p.usuarioId)).toList();
    if (disponibles.isEmpty) {
      mostrarMensaje(context, 'Ya agregaste a todas las personas con horario.');
      return;
    }
    final elegida = await showModalBottomSheet<HorarioPersona>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (contexto) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(contexto).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Agregar persona', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              for (final p in disponibles)
                ListTile(
                  leading: AvatarPersona(nombre: p.nombre, rol: p.rol),
                  title: Text(p.nombre),
                  subtitle: Text('${p.rol.etiqueta} · sale a las ${horaCorta(p.horaSalida)}'),
                  onTap: () => Navigator.pop(contexto, p),
                ),
            ],
          ),
        ),
      ),
    );
    if (elegida != null) setState(() => _planes[elegida.usuarioId] = _Plan(_sugerida(elegida)));
  }

  Future<void> _elegirHora(_Plan plan) async {
    final hora = await showTimePicker(
      context: context,
      initialTime: plan.hora,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      helpText: 'Hora de fin',
    );
    if (hora != null) setState(() => plan.hora = hora);
  }

  Future<void> _guardar() async {
    final listos = _planes.entries.where((e) => e.value.dias.isNotEmpty).toList();
    if (listos.isEmpty) {
      mostrarMensaje(context, 'Elige al menos un día para alguna persona.', error: true);
      return;
    }
    setState(() => _guardando = true);
    final api = ref.read(apiGerenciaProvider);
    try {
      for (final MapEntry(key: usuario, value: plan) in listos) {
        await api.programarHorasExtra(
          usuarios: [usuario],
          fechas: [for (final d in plan.dias.toList()..sort()) _fecha(d)],
          horaFin: horaApi(plan.hora.hour, plan.hora.minute),
        );
      }
      ref.invalidate(horasExtraSemanaProvider);
      if (!mounted) return;
      mostrarMensaje(context, 'Programación guardada.');
      context.pop();
    } catch (e) {
      if (mounted) mostrarMensaje(context, errorDesde(e).mensaje, error: true);
      ref.invalidate(horasExtraSemanaProvider);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personas = ref.watch(horariosProvider);
    final semana = ref.watch(horasExtraSemanaProvider);

    return Scaffold(
      appBar: barraNovaTech(titulo: 'Horas extra de la semana'),
      body: ContenidoCentrado(
        child: VistaAsync(
          valor: personas,
          alReintentar: () => ref.invalidate(horariosProvider),
          datos: (lista) {
            final porId = {for (final p in lista) p.usuarioId: p};
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._yaProgramadas(semana.valueOrNull ?? const []),
                      for (final MapEntry(key: id, value: plan) in _planes.entries)
                        if (porId[id] case final persona?) _tarjetaPersona(persona, plan),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          title: const Text('Agregar persona'),
                          trailing: const Icon(Icons.add),
                          onTap: () => _agregar(lista),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ColoresNovaTech.naranja.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Vence el domingo a medianoche y no se copia a la semana siguiente. '
                          'Quedan aprobadas de una vez.',
                          style: TextStyle(color: Color(0xFF8A4B00)),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: FilledButton(
                      onPressed: _guardando || _planes.isEmpty ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Guardar programación'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Lo que ya quedó aprobado esta semana, agrupado por persona.
  List<Widget> _yaProgramadas(List<HoraExtra> horas) {
    if (horas.isEmpty) return const [];
    final porPersona = <String, List<HoraExtra>>{};
    for (final h in horas) {
      porPersona.putIfAbsent(h.usuario, () => []).add(h);
    }
    return [
      const TituloSeccion('Ya programadas'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              for (final MapEntry(key: nombre, value: lista) in porPersona.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final h in [...lista]..sort((a, b) => a.fecha.compareTo(b.fecha)))
                              Insignia(
                                texto: '${_letraDia(h.fecha)} ${horaCorta(h.horaFin)}',
                                color: ColoresNovaTech.verde,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      const TituloSeccion('Programar'),
    ];
  }

  String _letraDia(DateTime fecha) => fecha.weekday <= 6 ? _letrasDias[fecha.weekday - 1] : 'D';

  Widget _tarjetaPersona(HorarioPersona persona, _Plan plan) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${persona.nombre} · ${persona.rol.etiqueta}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: () => setState(() => _planes.remove(persona.usuarioId)),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                for (var dia = 1; dia <= 6; dia++)
                  _ChipDia(
                    letra: _letrasDias[dia - 1],
                    elegido: plan.dias.contains(dia),
                    habilitado: !_pasado(dia),
                    onTap: () => setState(() {
                      plan.dias.contains(dia) ? plan.dias.remove(dia) : plan.dias.add(dia);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Hora de fin', style: TextStyle(color: ColoresNovaTech.textoSuave)),
                ),
                ActionChip(
                  label: Text('${horaApi(plan.hora.hour, plan.hora.minute)} ▾'),
                  onPressed: () => _elegirHora(plan),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipDia extends StatelessWidget {
  const _ChipDia({required this.letra, required this.elegido, required this.habilitado, required this.onTap});

  final String letra;
  final bool elegido;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: habilitado ? onTap : null,
      radius: 22,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: elegido ? ColoresNovaTech.azul : Colors.white,
          border: Border.all(color: elegido ? ColoresNovaTech.azul : ColoresNovaTech.borde),
        ),
        child: Text(
          letra,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: elegido
                ? Colors.white
                : habilitado
                ? ColoresNovaTech.texto
                : ColoresNovaTech.borde,
          ),
        ),
      ),
    );
  }
}
