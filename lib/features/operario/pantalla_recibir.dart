import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/cliente_api.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/vista_async.dart';
import 'api_operario.dart';
import 'modelos_operario.dart';

/// Recepción de una compra: se cuentan las unidades en buen estado y las dañadas.
class PantallaRecibir extends ConsumerWidget {
  const PantallaRecibir({super.key, required this.compraId});

  final int compraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compra = ref.watch(compraProvider(compraId));
    return Scaffold(
      appBar: AppBar(title: Text(compra.valueOrNull?.codigo ?? 'Recibir compra')),
      body: VistaAsync(
        valor: compra,
        alReintentar: () => ref.invalidate(compraProvider(compraId)),
        datos: (datos) => datos.estado == 'aprobada'
            ? _Conteo(compra: datos)
            : const ListaVacia(
                icono: Icons.info_outline,
                texto: 'Esta compra ya no está pendiente de recibir.',
              ),
      ),
    );
  }
}

class _Conteo extends ConsumerStatefulWidget {
  const _Conteo({required this.compra});

  final Compra compra;

  @override
  ConsumerState<_Conteo> createState() => _ConteoState();
}

class _ConteoState extends ConsumerState<_Conteo> {
  int _buenas = 0;
  int _danadas = 0;
  bool _enviando = false;

  Future<void> _registrar() async {
    final compra = widget.compra;
    final ok = await confirmar(
      context,
      titulo: 'Registrar recepción',
      texto: 'En buen estado: $_buenas\nDañadas: $_danadas\n\n'
          '${resumenRecepcion(aprobada: compra.cantidad, buenas: _buenas, danadas: _danadas)}',
      aceptar: 'Registrar',
    );
    if (!ok || !mounted) return;

    setState(() => _enviando = true);
    try {
      final resultado = await ref.read(apiOperarioProvider).recibir(compra.id, buenas: _buenas, danadas: _danadas);
      if (!mounted) return;
      await _mostrarResultado(resultado);
      recargarOperario(ref);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) mostrarMensaje(context, errorDesde(e).mensaje, error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _mostrarResultado(Compra resultado) {
    final bien = resultado.recibida;
    return showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        icon: Icon(
          bien ? Icons.check_circle : Icons.report_problem_outlined,
          color: bien ? ColoresNovaTech.verde : ColoresNovaTech.naranja,
          size: 48,
        ),
        title: Text(bien ? 'Mercancía recibida' : 'Recibida con diferencias'),
        content: Text(
          bien
              ? 'Se creó el lote ${resultado.lote ?? ''} y el stock ya está disponible.'
              : 'La compra quedó «con diferencias». El stock queda retenido hasta que gerencia decida.'
                  '${resultado.nota != null ? '\n\n${resultado.nota}' : ''}',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compra = widget.compra;
    final coincide = _danadas == 0 && _buenas == compra.cantidad;
    final hayConteo = _buenas + _danadas > 0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(compra.producto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(compra.sku, style: const TextStyle(color: Colors.black54)),
                      if (compra.proveedor != null) Text('Proveedor: ${compra.proveedor}'),
                      const SizedBox(height: 8),
                      Text(
                        'Deben llegar ${compra.cantidad} unidades',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _enviando
                    ? null
                    : () => setState(() {
                          _buenas = compra.cantidad;
                          _danadas = 0;
                        }),
                icon: const Icon(Icons.done_all),
                label: Text('Llegaron las ${compra.cantidad} en buen estado'),
              ),
              const SizedBox(height: 8),
              _Contador(
                titulo: 'En buen estado',
                icono: Icons.check_circle_outline,
                color: ColoresNovaTech.verde,
                valor: _buenas,
                habilitado: !_enviando,
                alCambiar: (n) => setState(() => _buenas = n),
              ),
              _Contador(
                titulo: 'Dañadas',
                icono: Icons.broken_image_outlined,
                color: ColoresNovaTech.rojo,
                valor: _danadas,
                habilitado: !_enviando,
                alCambiar: (n) => setState(() => _danadas = n),
              ),
              if (hayConteo)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        coincide ? Icons.check_circle : Icons.info_outline,
                        color: coincide ? ColoresNovaTech.verde : ColoresNovaTech.naranja,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          resumenRecepcion(aprobada: compra.cantidad, buenas: _buenas, danadas: _danadas),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton(
              onPressed: hayConteo && !_enviando ? _registrar : null,
              child: _enviando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Registrar recepción'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Contador con botones grandes: −10, −1, +1, +10 (sin teclado).
class _Contador extends StatelessWidget {
  const _Contador({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.valor,
    required this.habilitado,
    required this.alCambiar,
  });

  final String titulo;
  final IconData icono;
  final Color color;
  final int valor;
  final bool habilitado;
  final ValueChanged<int> alCambiar;

  static const _maximo = 100000;

  Widget _boton(String texto, int paso) {
    final nuevo = (valor + paso).clamp(0, _maximo);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), padding: EdgeInsets.zero),
          onPressed: habilitado && nuevo != valor ? () => alCambiar(nuevo) : null,
          child: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icono, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                Text('$valor', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _boton('−10', -10),
                _boton('−1', -1),
                _boton('+1', 1),
                _boton('+10', 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
