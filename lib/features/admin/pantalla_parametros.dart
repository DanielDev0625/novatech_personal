import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_admin.dart';
import 'modelos_admin.dart';

/// Suma [paso] a [valor] sin salirse de [minimo]..[maximo] y sin errores de coma flotante.
double ajustar(double valor, double paso, {double minimo = 0, double maximo = double.infinity, int decimales = 0}) {
  final factor = math.pow(10, decimales);
  final nuevo = ((valor + paso) * factor).round() / factor;
  return nuevo.clamp(minimo, maximo).toDouble();
}

String _decimal(double valor, int decimales) => valor.toStringAsFixed(decimales).replaceAll('.', ',');

/// «Parámetros» del administrador: todo con − / + y selectores, sin escribir.
class PantallaParametros extends ConsumerWidget {
  const PantallaParametros({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configuracionProvider);
    if (config.hasValue) return _Editor(config: config.value);
    return EsqueletoRol(
      titulo: 'Parámetros',
      hijos: [
        VistaAsync(
          valor: config,
          alReintentar: () => ref.invalidate(configuracionProvider),
          datos: (_) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.config});

  /// Respuesta de GET /configuracion tal como llegó.
  final Object? config;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late Parametros _original = Parametros.desde(widget.config);
  late Parametros _p = _original.copia();
  bool _guardando = false;

  @override
  void didUpdateWidget(covariant _Editor anterior) {
    super.didUpdateWidget(anterior);
    // Llegó una configuración nueva del servidor (después de guardar o recargar).
    if (!identical(anterior.config, widget.config)) {
      _original = Parametros.desde(widget.config);
      _p = _original.copia();
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await ref.read(apiAdminProvider).guardarParametros(_p, _original);
      if (!mounted) return;
      mostrarMensaje(context, 'Cambios guardados.');
      ref.invalidate(configuracionProvider);
    } catch (e) {
      if (mounted) mostrarMensaje(context, errorDesde(e).mensaje, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _elegirJornada() async {
    final inicio = leerHora(_p.horaInicio)!;
    final salida = leerHora(_p.horaSalida)!;
    final nuevoInicio = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: inicio.$1, minute: inicio.$2),
      initialEntryMode: TimePickerEntryMode.dialOnly,
      helpText: 'Inicio de la jornada',
    );
    if (nuevoInicio == null || !mounted) return;
    final nuevaSalida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: salida.$1, minute: salida.$2),
      initialEntryMode: TimePickerEntryMode.dialOnly,
      helpText: 'Salida de la jornada',
    );
    if (nuevaSalida == null) return;
    if (nuevaSalida.hour * 60 + nuevaSalida.minute <= nuevoInicio.hour * 60 + nuevoInicio.minute) {
      if (mounted) mostrarMensaje(context, 'La salida debe ser después del inicio.', error: true);
      return;
    }
    setState(() {
      _p.horaInicio = horaApi(nuevoInicio.hour, nuevoInicio.minute);
      _p.horaSalida = horaApi(nuevaSalida.hour, nuevaSalida.minute);
    });
  }

  /// Fila con − / + para un número. Si el servidor no envió el valor, queda deshabilitada.
  Widget _numero({
    required String titulo,
    String? subtitulo,
    required double? valor,
    required String Function(double) texto,
    required double paso,
    required void Function(double) cambiar,
    double minimo = 0,
    double maximo = double.infinity,
    int decimales = 0,
  }) {
    final v = valor;
    return _Fila(
      titulo: titulo,
      subtitulo: subtitulo,
      control: v == null
          ? const Text('—', style: TextStyle(color: ColoresNovaTech.textoSuave))
          : Pasos(
              texto: texto(v),
              onMenos: v - paso < minimo - 1e-9 || _guardando
                  ? null
                  : () => setState(() => cambiar(ajustar(v, -paso, minimo: minimo, maximo: maximo, decimales: decimales))),
              onMas: v + paso > maximo + 1e-9 || _guardando
                  ? null
                  : () => setState(() => cambiar(ajustar(v, paso, minimo: minimo, maximo: maximo, decimales: decimales))),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cambios = _p.cambiosFrente(_original);
    final fraccion = _p.margenEsFraccion;
    final faltan = [
      _p.margen,
      _p.plazoCompraDias,
      _p.plazoEntregaDias,
      _p.tarifaEntrega,
      _p.topeHorasExtra,
      _p.tarifaKwh,
      _p.alistamientoMinutos,
    ].any((v) => v == null);

    return EsqueletoRol(
      titulo: 'Parámetros',
      alRecargar: () async => ref.invalidate(configuracionProvider),
      accionInferior: FilledButton(
        onPressed: cambios.isEmpty || _guardando ? null : _guardar,
        child: _guardando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(cambios.isEmpty ? 'Sin cambios' : 'Guardar cambios'),
      ),
      hijos: [
        const TituloSeccion('Energía'),
        _numero(
          titulo: 'Tarifa por kWh',
          valor: _p.tarifaKwh,
          texto: pesos,
          paso: 10,
          minimo: 10,
          cambiar: (v) => _p.tarifaKwh = v,
        ),
        _numero(
          titulo: 'Factor CO₂',
          subtitulo: 'kg por kWh',
          valor: _p.factorCo2,
          texto: (v) => _decimal(v, 3),
          paso: 0.001,
          decimales: 3,
          cambiar: (v) => _p.factorCo2 = v,
        ),
        _numero(
          titulo: 'Alerta de consumo',
          subtitulo: 'aumento frente al mes anterior',
          valor: _p.aumentoAlertaPorcentaje,
          texto: (v) => '${_decimal(v, 0)}%',
          paso: 1,
          maximo: 100,
          cambiar: (v) => _p.aumentoAlertaPorcentaje = v,
        ),
        const TituloSeccion('Jornada'),
        _Fila(
          titulo: 'Jornada',
          subtitulo: 'inicio y salida',
          control: _p.horaInicio == null || _p.horaSalida == null
              ? const Text('—', style: TextStyle(color: ColoresNovaTech.textoSuave))
              : ActionChip(
                  label: Text('${horaCorta(_p.horaInicio!)} a ${horaCorta(_p.horaSalida!)}'),
                  onPressed: _guardando || !_p.conJornada ? null : _elegirJornada,
                ),
        ),
        _numero(
          titulo: 'Tope horas extra',
          subtitulo: 'por día',
          valor: _p.topeHorasExtra,
          texto: (v) => '${_decimal(v, v % 1 == 0 ? 0 : 1)} h',
          paso: 0.5,
          maximo: 12,
          decimales: 1,
          cambiar: (v) => _p.topeHorasExtra = v,
        ),
        const TituloSeccion('Ventas y compras'),
        _numero(
          titulo: 'Margen de venta',
          subtitulo: 'el precio se recalcula en todo el catálogo',
          valor: _p.margen,
          texto: (v) => '${_decimal(fraccion ? v * 100 : v, 0)}%',
          paso: fraccion ? 0.01 : 1,
          maximo: fraccion ? 5 : 500,
          decimales: fraccion ? 2 : 0,
          cambiar: (v) => _p.margen = v,
        ),
        _numero(
          titulo: 'Plazo de compra',
          subtitulo: 'días que tarda en llegar',
          valor: _p.plazoCompraDias,
          texto: (v) => '${v.round()} ${v.round() == 1 ? 'día' : 'días'}',
          paso: 1,
          minimo: 1,
          maximo: 90,
          cambiar: (v) => _p.plazoCompraDias = v,
        ),
        _numero(
          titulo: 'Plazo de entrega',
          subtitulo: 'días prometidos al cliente',
          valor: _p.plazoEntregaDias,
          texto: (v) => '${v.round()} ${v.round() == 1 ? 'día' : 'días'}',
          paso: 1,
          minimo: 1,
          maximo: 30,
          cambiar: (v) => _p.plazoEntregaDias = v,
        ),
        const TituloSeccion('Transportistas'),
        _numero(
          titulo: 'Tarifa por entrega',
          valor: _p.tarifaEntrega,
          texto: pesos,
          paso: 500,
          minimo: 500,
          cambiar: (v) => _p.tarifaEntrega = v,
        ),
        _numero(
          titulo: 'Comisión',
          valor: _p.comisionPorcentaje,
          texto: (v) => '${_decimal(v, 0)}%',
          paso: 1,
          maximo: 100,
          cambiar: (v) => _p.comisionPorcentaje = v,
        ),
        const TituloSeccion('Tiempos esperados'),
        _numero(
          titulo: 'Alistamiento',
          valor: _p.alistamientoMinutos,
          texto: (v) => duracion(v.round()),
          paso: 5,
          minimo: 5,
          cambiar: (v) => _p.alistamientoMinutos = v,
        ),
        _numero(
          titulo: 'Ruta',
          valor: _p.rutaMinutos,
          texto: (v) => duracion(v.round()),
          paso: 5,
          minimo: 5,
          cambiar: (v) => _p.rutaMinutos = v,
        ),
        if (faltan)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Los valores con «—» no llegaron del servidor y no se pueden cambiar desde aquí.',
              style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: const Text('Zonas y equipos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/zonas'),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Bitácora'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/bitacora'),
          ),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.titulo, required this.control, this.subtitulo});

  final String titulo;
  final String? subtitulo;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ColoresNovaTech.borde))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (subtitulo != null)
                  Text(subtitulo!, style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13)),
              ],
            ),
          ),
          control,
        ],
      ),
    );
  }
}
