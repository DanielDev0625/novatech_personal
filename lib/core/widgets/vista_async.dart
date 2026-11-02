import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/cliente_api.dart';
import '../tema/tema.dart';

/// Muestra los datos de un [AsyncValue], o la carga, o el error con «Reintentar».
class VistaAsync<T> extends StatelessWidget {
  const VistaAsync({
    super.key,
    required this.valor,
    required this.alReintentar,
    required this.datos,
  });

  final AsyncValue<T> valor;
  final VoidCallback alReintentar;
  final Widget Function(T datos) datos;

  @override
  Widget build(BuildContext context) {
    return valor.when(
      // Al recargar se siguen mostrando los datos anteriores.
      skipLoadingOnRefresh: true,
      data: datos,
      loading: () => const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      ),
      error: (error, _) => MensajeError(mensaje: errorDesde(error).mensaje, alReintentar: alReintentar),
    );
  }
}

class MensajeError extends StatelessWidget {
  const MensajeError({super.key, required this.mensaje, this.alReintentar});

  final String mensaje;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: ColoresNovaTech.rojo),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            if (alReintentar != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: alReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mensaje cuando una lista está vacía.
class ListaVacia extends StatelessWidget {
  const ListaVacia({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(icono, size: 48, color: ColoresNovaTech.borde),
          const SizedBox(height: 8),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: ColoresNovaTech.textoSuave)),
        ],
      ),
    );
  }
}

/// Título de sección dentro de una lista.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresNovaTech.texto),
      ),
    );
  }
}

void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? ColoresNovaTech.rojo : ColoresNovaTech.marino,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Pregunta antes de una acción importante. Devuelve true si se confirma.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  String aceptar = 'Confirmar',
}) async {
  final respuesta = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () => Navigator.pop(contexto, true),
          child: Text(aceptar),
        ),
      ],
    ),
  );
  return respuesta ?? false;
}
