import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_gerencia.dart';

enum _Lista { compras, horasExtra, diferencias }

/// «Aprobaciones»: compras sugeridas, solicitudes de horas extra y recepciones
/// con diferencias, cada una se resuelve con un toque.
class PantallaAprobaciones extends ConsumerStatefulWidget {
  const PantallaAprobaciones({super.key});

  @override
  ConsumerState<PantallaAprobaciones> createState() => _PantallaAprobacionesState();
}

class _PantallaAprobacionesState extends ConsumerState<PantallaAprobaciones> {
  _Lista _lista = _Lista.compras;

  /// Elemento en proceso («c12», «h4») para mostrar la carga en su tarjeta.
  String? _ocupado;

  Future<void> _recargar() async {
    recargarGerencia(ref);
    try {
      await Future.wait([
        ref.read(comprasSugeridasProvider.future),
        ref.read(horasExtraSolicitadasProvider.future),
        ref.read(comprasConDiferenciasProvider.future),
      ]);
    } catch (_) {
      // El error se ve en la lista.
    }
  }

  Future<void> _hacer(String clave, Future<void> Function() accion, String exito) async {
    setState(() => _ocupado = clave);
    try {
      await accion();
      if (mounted) mostrarMensaje(context, exito);
    } catch (e) {
      if (mounted) mostrarMensaje(context, errorDesde(e).mensaje, error: true);
    } finally {
      if (mounted) setState(() => _ocupado = null);
      await _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiGerenciaProvider);
    final compras = ref.watch(comprasSugeridasProvider);
    final horas = ref.watch(horasExtraSolicitadasProvider);
    final diferencias = ref.watch(comprasConDiferenciasProvider);

    String conteo(AsyncValue<List<Object>> v) => v.whenOrNull(data: (l) => ' ${l.length}') ?? '';

    return EsqueletoRol(
      titulo: 'Aprobaciones',
      alRecargar: _recargar,
      hijos: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text('Compras${conteo(compras)}'),
              selected: _lista == _Lista.compras,
              onSelected: (_) => setState(() => _lista = _Lista.compras),
            ),
            ChoiceChip(
              label: Text('Horas extra${conteo(horas)}'),
              selected: _lista == _Lista.horasExtra,
              onSelected: (_) => setState(() => _lista = _Lista.horasExtra),
            ),
            ChoiceChip(
              label: Text('Diferencias${conteo(diferencias)}'),
              selected: _lista == _Lista.diferencias,
              onSelected: (_) => setState(() => _lista = _Lista.diferencias),
            ),
          ],
        ),
        const SizedBox(height: 8),
        switch (_lista) {
          _Lista.compras => VistaAsync(
              valor: compras,
              alReintentar: _recargar,
              datos: (lista) => lista.isEmpty
                  ? const ListaVacia(icono: Icons.task_alt, texto: 'No hay compras por aprobar.')
                  : Column(
                      children: [
                        for (final c in lista)
                          _TarjetaDecision(
                            titulo: c.producto,
                            lineas: [
                              Text(
                                'Quedan ${c.stockActual} · mínimo ${c.stockMinimo}',
                                style: const TextStyle(color: ColoresNovaTech.textoSuave),
                              ),
                              Text.rich(TextSpan(children: [
                                const TextSpan(text: 'Sugerido: '),
                                TextSpan(
                                  text: '${c.cantidad} unidades',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ])),
                              Text(
                                '${c.codigo}${c.proveedor != null ? ' · ${c.proveedor}' : ''}',
                                style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
                              ),
                            ],
                            ocupado: _ocupado == 'c${c.id}',
                            habilitado: _ocupado == null,
                            onRechazar: () =>
                                _hacer('c${c.id}', () => api.rechazarCompra(c.id), 'Compra ${c.codigo} rechazada.'),
                            onAprobar: () =>
                                _hacer('c${c.id}', () => api.aprobarCompra(c.id), 'Compra ${c.codigo} aprobada.'),
                          ),
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'La aprobación es un registro interno, no se envía al proveedor.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
            ),
          _Lista.horasExtra => VistaAsync(
              valor: horas,
              alReintentar: _recargar,
              datos: (lista) => lista.isEmpty
                  ? const ListaVacia(icono: Icons.task_alt, texto: 'No hay solicitudes de horas extra.')
                  : Column(
                      children: [
                        for (final h in lista)
                          _TarjetaDecision(
                            titulo: h.usuario,
                            lineas: [
                              Text.rich(TextSpan(children: [
                                TextSpan(text: '${_mayuscula(diaRelativo(h.fecha))} hasta las '),
                                TextSpan(
                                  text: horaCorta(h.horaFin),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ])),
                              Text(
                                [
                                  if (h.motivo != null) h.motivo!.etiqueta,
                                  if (h.esCorreccion) 'corrección de un día pasado',
                                ].join(' · '),
                                style: const TextStyle(color: ColoresNovaTech.textoSuave),
                              ),
                            ],
                            ocupado: _ocupado == 'h${h.id}',
                            habilitado: _ocupado == null,
                            onRechazar: () =>
                                _hacer('h${h.id}', () => api.rechazarHoraExtra(h.id), 'Solicitud rechazada.'),
                            onAprobar: () =>
                                _hacer('h${h.id}', () => api.aprobarHoraExtra(h.id), 'Horas extra aprobadas.'),
                          ),
                      ],
                    ),
            ),
          _Lista.diferencias => VistaAsync(
              valor: diferencias,
              alReintentar: _recargar,
              datos: (lista) => lista.isEmpty
                  ? const ListaVacia(icono: Icons.task_alt, texto: 'No hay recepciones con diferencias.')
                  : Column(
                      children: [
                        for (final c in lista)
                          _TarjetaDecision(
                            titulo: c.producto,
                            borde: ColoresNovaTech.naranja,
                            lineas: [
                              Text(
                                'Aprobado ${c.cantidad} · Buenas ${c.cantidadBuena ?? 0} · Dañadas ${c.cantidadDanada ?? 0}',
                                style: const TextStyle(color: ColoresNovaTech.textoSuave),
                              ),
                              if (c.recibidaPor != null)
                                Text(
                                  '${c.codigo} · recibió ${c.recibidaPor}',
                                  style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
                                ),
                            ],
                            textoRechazar: 'Descartar',
                            textoAprobar: 'Aceptar buenas',
                            ocupado: _ocupado == 'd${c.id}',
                            habilitado: _ocupado == null,
                            onRechazar: () => _confirmarDescarte(c),
                            onAprobar: () => _hacer(
                              'd${c.id}',
                              () => api.resolverCompra(c.id, aceptar: true),
                              'Se creó el lote con las ${c.cantidadBuena ?? 0} unidades buenas.',
                            ),
                          ),
                      ],
                    ),
            ),
        },
      ],
    );
  }

  Future<void> _confirmarDescarte(Compra c) async {
    final ok = await confirmar(
      context,
      titulo: 'Descartar recepción',
      texto: 'No entrará nada de ${c.codigo} al stock. ¿Continuar?',
      aceptar: 'Descartar',
    );
    if (!ok) return;
    await _hacer(
      'd${c.id}',
      () => ref.read(apiGerenciaProvider).resolverCompra(c.id, aceptar: false),
      'Recepción ${c.codigo} descartada.',
    );
  }
}

String _mayuscula(String texto) => texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';

/// Tarjeta con «Rechazar» (rojo) y «Aprobar» (verde), como en el diseño.
class _TarjetaDecision extends StatelessWidget {
  const _TarjetaDecision({
    required this.titulo,
    required this.lineas,
    required this.ocupado,
    required this.habilitado,
    required this.onRechazar,
    required this.onAprobar,
    this.textoRechazar = 'Rechazar',
    this.textoAprobar = 'Aprobar',
    this.borde,
  });

  final String titulo;
  final List<Widget> lineas;
  final bool ocupado;
  final bool habilitado;
  final VoidCallback onRechazar;
  final VoidCallback onAprobar;
  final String textoRechazar;
  final String textoAprobar;
  final Color? borde;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: borde == null
          ? null
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borde!)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            ...lineas,
            const SizedBox(height: 12),
            if (ocupado)
              const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        foregroundColor: ColoresNovaTech.rojo,
                        side: const BorderSide(color: ColoresNovaTech.rojo),
                      ),
                      onPressed: habilitado ? onRechazar : null,
                      child: Text(textoRechazar),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: ColoresNovaTech.verde,
                      ),
                      onPressed: habilitado ? onAprobar : null,
                      child: Text(textoAprobar),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
