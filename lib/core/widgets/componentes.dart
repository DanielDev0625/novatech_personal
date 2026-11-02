import 'package:flutter/material.dart';

import '../tema/tema.dart';

/// Píldora de estado («Registrado», «En ruta», «Aprobada»...).
class Insignia extends StatelessWidget {
  const Insignia({super.key, required this.texto, required this.color, this.icono});

  final String texto;
  final Color color;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 14, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta con un número grande («Pedidos hoy 18»).
class Indicador extends StatelessWidget {
  const Indicador({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.color = ColoresNovaTech.texto,
    this.detalle,
    this.onTap,
  });

  final String etiqueta;
  final String valor;
  final Color color;
  final String? detalle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 14)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
              ),
              if (detalle != null)
                Text(detalle!, style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicadores en rejilla: dos por fila en el celular, cuatro cuando hay espacio.
class RejillaIndicadores extends StatelessWidget {
  const RejillaIndicadores({super.key, required this.indicadores});

  final List<Widget> indicadores;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        final porFila = limites.maxWidth >= 640 ? 4 : 2;
        return Column(
          children: [
            for (var i = 0; i < indicadores.length; i += porFila)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = i; j < i + porFila; j++) ...[
                        if (j > i) const SizedBox(width: 10),
                        Expanded(child: j < indicadores.length ? indicadores[j] : const SizedBox()),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Barra de avance redondeada (0 a 1).
class BarraAvance extends StatelessWidget {
  const BarraAvance({super.key, required this.valor, this.color = ColoresNovaTech.verde, this.alto = 6});

  final double valor;
  final Color color;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(alto),
      child: LinearProgressIndicator(
        value: valor.clamp(0, 1).toDouble(),
        minHeight: alto,
        color: color,
        backgroundColor: ColoresNovaTech.borde,
      ),
    );
  }
}

/// Fila de un gráfico de barras horizontal: etiqueta, barra y valor.
class FilaBarra extends StatelessWidget {
  const FilaBarra({
    super.key,
    required this.etiqueta,
    required this.proporcion,
    required this.valor,
    required this.color,
  });

  final String etiqueta;

  /// Largo de la barra frente a la mayor (0 a 1).
  final double proporcion;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, limites) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: (limites.maxWidth * proporcion.clamp(0.02, 1)).toDouble(),
                  height: 12,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso destacado con borde de color (alertas del panel).
class TarjetaAviso extends StatelessWidget {
  const TarjetaAviso({super.key, required this.icono, required this.texto, required this.color, this.onTap});

  final IconData icono;
  final String texto;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icono, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(texto, style: const TextStyle(fontSize: 15))),
              if (onTap != null) const Icon(Icons.chevron_right, color: ColoresNovaTech.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}

/// Control − valor + para cambiar números sin teclado.
class Pasos extends StatelessWidget {
  const Pasos({
    super.key,
    required this.texto,
    required this.onMenos,
    required this.onMas,
  });

  final String texto;
  final VoidCallback? onMenos;
  final VoidCallback? onMas;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BotonRedondo(icono: Icons.remove, onTap: onMenos, tooltip: 'Menos'),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        _BotonRedondo(icono: Icons.add, onTap: onMas, tooltip: 'Más'),
      ],
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({required this.icono, required this.onTap, required this.tooltip});

  final IconData icono;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        side: const BorderSide(color: ColoresNovaTech.borde),
        backgroundColor: Colors.white,
      ),
      icon: Icon(icono, size: 20),
    );
  }
}
