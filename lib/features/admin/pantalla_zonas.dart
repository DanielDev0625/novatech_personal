import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/adaptable.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_admin.dart';
import 'modelos_admin.dart';
import 'pantalla_parametros.dart';

String _kw(double valor) => '${valor.toStringAsFixed(valor % 1 == 0 ? 0 : 1).replaceAll('.', ',')} kW';

/// «Zonas y equipos»: dónde se consume energía y con qué potencia.
class PantallaZonas extends ConsumerStatefulWidget {
  const PantallaZonas({super.key});

  @override
  ConsumerState<PantallaZonas> createState() => _PantallaZonasState();
}

class _PantallaZonasState extends ConsumerState<PantallaZonas> {
  final Set<int> _cambiando = {};

  Future<void> _recargar() async {
    ref.invalidate(zonasProvider);
    try {
      await ref.read(zonasProvider.future);
    } catch (_) {
      // El error se ve en la lista.
    }
  }

  Future<void> _estadoEquipo(Equipo equipo, bool activo) async {
    setState(() => _cambiando.add(equipo.id));
    try {
      await ref.read(apiAdminProvider).cambiarEstadoEquipo(equipo.id, activo: activo);
      await _recargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, errorDesde(e).mensaje, error: true);
    } finally {
      if (mounted) setState(() => _cambiando.remove(equipo.id));
    }
  }

  Future<void> _nuevaZona() async {
    final creada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NuevaZona(),
    );
    if (creada == true) await _recargar();
  }

  Future<void> _nuevoEquipo(Zona zona) async {
    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NuevoEquipo(zona: zona),
    );
    if (creado == true) await _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final zonas = ref.watch(zonasProvider);
    return Scaffold(
      appBar: barraNovaTech(titulo: 'Zonas y equipos'),
      body: ContenidoCentrado(
        child: RefreshIndicator(
          onRefresh: _recargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              VistaAsync(
                valor: zonas,
                alReintentar: _recargar,
                datos: (lista) => lista.isEmpty
                    ? const ListaVacia(icono: Icons.bolt_outlined, texto: 'Aún no hay zonas. Crea la primera.')
                    : Column(children: [for (final zona in lista) _tarjetaZona(zona)]),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _nuevaZona,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Nueva zona'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaZona(Zona zona) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(zona.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                Insignia(texto: _kw(zona.potenciaTotalKw), color: ColoresNovaTech.verde),
              ],
            ),
            if (zona.umbralKwhMensual != null)
              Text(
                'Alerta si pasa de ${zona.umbralKwhMensual!.round()} kWh al mes',
                style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
              ),
            for (final equipo in zona.equipos)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(equipo.nombre),
                        Text(
                          '${_kw(equipo.potenciaKw)} · ${equipo.tipo == 'continuo' ? 'continuo (24 h)' : 'en jornada'}',
                          style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (_cambiando.contains(equipo.id))
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    )
                  else
                    Switch(
                      value: equipo.activo,
                      activeTrackColor: ColoresNovaTech.verde,
                      onChanged: (v) => _estadoEquipo(equipo, v),
                    ),
                ],
              ),
            TextButton.icon(
              onPressed: () => _nuevoEquipo(zona),
              icon: const Icon(Icons.add),
              label: const Text('Agregar equipo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NuevaZona extends ConsumerStatefulWidget {
  const _NuevaZona();

  @override
  ConsumerState<_NuevaZona> createState() => _NuevaZonaState();
}

class _NuevaZonaState extends ConsumerState<_NuevaZona> {
  final _nombre = TextEditingController();
  double _umbral = 0;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre de la zona.');
      return;
    }
    setState(() => _enviando = true);
    try {
      await ref.read(apiAdminProvider).crearZona(nombre, umbralKwhMensual: _umbral > 0 ? _umbral : null);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorDesde(e).mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Hoja(
      titulo: 'Nueva zona',
      error: _error,
      enviando: _enviando,
      onGuardar: _guardar,
      hijos: [
        TextField(
          controller: _nombre,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Nombre (p. ej. Bodega)'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Text('Alerta mensual')),
            Pasos(
              texto: _umbral == 0 ? 'Sin alerta' : '${_umbral.round()} kWh',
              onMenos: _umbral <= 0 ? null : () => setState(() => _umbral = ajustar(_umbral, -100)),
              onMas: () => setState(() => _umbral = ajustar(_umbral, 100)),
            ),
          ],
        ),
      ],
    );
  }
}

class _NuevoEquipo extends ConsumerStatefulWidget {
  const _NuevoEquipo({required this.zona});

  final Zona zona;

  @override
  ConsumerState<_NuevoEquipo> createState() => _NuevoEquipoState();
}

class _NuevoEquipoState extends ConsumerState<_NuevoEquipo> {
  final _nombre = TextEditingController();
  double _potencia = 1;
  String _tipo = 'jornada';
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre del equipo.');
      return;
    }
    setState(() => _enviando = true);
    try {
      await ref
          .read(apiAdminProvider)
          .crearEquipo(zonaId: widget.zona.id, nombre: nombre, potenciaKw: _potencia, tipo: _tipo);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorDesde(e).mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Hoja(
      titulo: 'Equipo en ${widget.zona.nombre}',
      error: _error,
      enviando: _enviando,
      onGuardar: _guardar,
      hijos: [
        TextField(
          controller: _nombre,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Nombre (p. ej. Montacargas)'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Text('Potencia')),
            Pasos(
              texto: _kw(_potencia),
              onMenos: _potencia <= 0.5
                  ? null
                  : () => setState(() => _potencia = ajustar(_potencia, -0.5, decimales: 1)),
              onMas: () => setState(() => _potencia = ajustar(_potencia, 0.5, decimales: 1)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('En jornada'),
              selected: _tipo == 'jornada',
              onSelected: (_) => setState(() => _tipo = 'jornada'),
            ),
            ChoiceChip(
              label: const Text('Continuo (24 h)'),
              selected: _tipo == 'continuo',
              onSelected: (_) => setState(() => _tipo = 'continuo'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Hoja inferior con título, campos, error y «Guardar».
class _Hoja extends StatelessWidget {
  const _Hoja({
    required this.titulo,
    required this.hijos,
    required this.error,
    required this.enviando,
    required this.onGuardar,
  });

  final String titulo;
  final List<Widget> hijos;
  final String? error;
  final bool enviando;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...hijos,
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: ColoresNovaTech.rojo)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: enviando ? null : onGuardar,
                child: enviando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
