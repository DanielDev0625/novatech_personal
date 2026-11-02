import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/cliente_api.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/escaner.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_operario.dart';
import 'modelos_operario.dart';

/// Alistamiento de un pedido: la cámara lee el código (SKU) de cada unidad.
class PantallaAlistar extends ConsumerWidget {
  const PantallaAlistar({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedido = ref.watch(pedidoProvider(pedidoId));
    final codigo = pedido.valueOrNull?.codigo;
    return Scaffold(
      appBar: barraNovaTech(titulo: codigo == null ? 'Alistamiento' : 'Alistando $codigo'),
      body: VistaAsync(
        valor: pedido,
        alReintentar: () => ref.invalidate(pedidoProvider(pedidoId)),
        datos: (datos) => datos.alistando
            ? _Alistamiento(pedido: datos)
            : const ListaVacia(
                icono: Icons.info_outline,
                texto: 'Este pedido ya no está en alistamiento. Vuelve a «Mis tareas».',
              ),
      ),
    );
  }
}

class _Alistamiento extends ConsumerStatefulWidget {
  const _Alistamiento({required this.pedido});

  final Pedido pedido;

  @override
  ConsumerState<_Alistamiento> createState() => _AlistamientoState();
}

class _AlistamientoState extends ConsumerState<_Alistamiento> {
  late final ConteoAlistamiento _conteo;

  /// Para no contar dos veces la misma unidad mientras sigue frente a la cámara.
  String? _ultimoCodigo;
  DateTime _ultimaLectura = DateTime.fromMillisecondsSinceEpoch(0);

  /// Mensaje de la última lectura (verde si sumó, rojo si no).
  String? _aviso;
  bool _avisoBueno = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    final guardado = ref.read(progresoAlistamientoProvider)[widget.pedido.id];
    _conteo = ConteoAlistamiento(widget.pedido.lineas, guardado);
  }

  void _guardar() {
    ref.read(progresoAlistamientoProvider)[widget.pedido.id] = _conteo.comoMapa;
  }

  void _alLeer(String valor) {
    if (_enviando) return;
    final ahora = DateTime.now();
    final repetido = valor == _ultimoCodigo && ahora.difference(_ultimaLectura).inMilliseconds < 1500;
    _ultimaLectura = ahora;
    if (repetido) return;
    _ultimoCodigo = valor;

    final linea = _conteo.lineaDeCodigo(valor);
    final resultado = _conteo.leer(valor);
    switch (resultado) {
      case ResultadoLectura.sumado:
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);
        _avisar('+1 ${linea!.nombre} (${_conteo.escaneados(linea.productoId)} de ${linea.cantidad})', bueno: true);
      case ResultadoLectura.yaCompleto:
        HapticFeedback.heavyImpact();
        _avisar('Ya están todas las unidades de ${linea!.nombre}.', bueno: false);
      case ResultadoLectura.noEsDelPedido:
        HapticFeedback.heavyImpact();
        _avisar('El código $valor no es de este pedido.', bueno: false);
    }
    _guardar();
  }

  void _avisar(String texto, {required bool bueno}) {
    setState(() {
      _aviso = texto;
      _avisoBueno = bueno;
    });
  }

  void _corregir(LineaPedido linea, {required bool sumar}) {
    setState(() {
      sumar ? _conteo.sumar(linea) : _conteo.restar(linea);
      _aviso = null;
    });
    _guardar();
  }

  Future<void> _listo() async {
    final ok = await confirmar(
      context,
      titulo: 'Listo para envío',
      texto: 'Confirma que empacaste las ${_conteo.totalPedido} unidades del pedido '
          '${widget.pedido.codigo} y lo dejas en la zona de envíos.',
      aceptar: 'Listo',
    );
    if (!ok || !mounted) return;

    setState(() => _enviando = true);
    try {
      await ref.read(apiOperarioProvider).listoParaEnvio(widget.pedido.id, _conteo);
      ref.read(progresoAlistamientoProvider).remove(widget.pedido.id);
      if (!mounted) return;
      mostrarMensaje(context, 'Pedido ${widget.pedido.codigo} en zona de envíos.');
      recargarOperario(ref);
      context.pop();
    } catch (e) {
      // 422: lo escaneado no coincide con el pedido (el servidor explica qué).
      if (mounted) mostrarMensaje(context, errorDesde(e).mensaje, error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completo = _conteo.completo;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.pedido.cliente != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Cliente: ${widget.pedido.cliente}',
                    style: const TextStyle(color: ColoresNovaTech.textoSuave),
                  ),
                ),
              for (final linea in _conteo.lineas)
                _LineaAlistamiento(
                  linea: linea,
                  escaneados: _conteo.escaneados(linea.productoId),
                  onMenos: _enviando ? null : () => _corregir(linea, sumar: false),
                  onMas: _enviando ? null : () => _corregir(linea, sumar: true),
                ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: VistaCamara(alto: 200, alLeer: _alLeer),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _aviso == null
                    ? const Text(
                        'Escanea cada unidad o usa + / −',
                        key: ValueKey('ayuda'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ColoresNovaTech.textoSuave),
                      )
                    : Insignia(
                        key: ValueKey(_aviso),
                        texto: _aviso!,
                        color: _avisoBueno ? ColoresNovaTech.verde : ColoresNovaTech.rojo,
                        icono: _avisoBueno ? Icons.check : Icons.error_outline,
                      ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_conteo.totalEscaneado} de ${_conteo.totalPedido} unidades',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: ColoresNovaTech.verde),
                  onPressed: completo && !_enviando ? _listo : null,
                  child: _enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Listo para envío'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LineaAlistamiento extends StatelessWidget {
  const _LineaAlistamiento({
    required this.linea,
    required this.escaneados,
    required this.onMenos,
    required this.onMas,
  });

  final LineaPedido linea;
  final int escaneados;
  final VoidCallback? onMenos;
  final VoidCallback? onMas;

  @override
  Widget build(BuildContext context) {
    final completa = escaneados == linea.cantidad;
    return Card(
      shape: completa
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: ColoresNovaTech.verde),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(linea.nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('SKU ${linea.sku}', style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13)),
                    ],
                  ),
                ),
                Pasos(
                  texto: '$escaneados de ${linea.cantidad}',
                  onMenos: escaneados > 0 ? onMenos : null,
                  onMas: completa ? null : onMas,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: BarraAvance(valor: linea.cantidad == 0 ? 0 : escaneados / linea.cantidad),
            ),
          ],
        ),
      ),
    );
  }
}
