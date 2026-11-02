import 'package:flutter/material.dart';

import '../tema/tema.dart';

/// Tarjeta grande de la pantalla de inicio de un rol, con un conteo opcional a la derecha.
class Acceso extends StatelessWidget {
  const Acceso({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
    this.conteo,
    this.etiquetaConteo,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  /// Texto del conteo; null mientras carga (se muestra «–»).
  final String? conteo;

  /// Si se da, se muestra el conteo con esta etiqueta debajo (p. ej. «en cola»).
  final String? etiquetaConteo;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: ColoresNovaTech.azul.withValues(alpha: 0.1),
                child: Icon(icono, color: ColoresNovaTech.azul, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(descripcion, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              if (etiquetaConteo != null)
                Column(
                  children: [
                    Text(
                      conteo ?? '–',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: ColoresNovaTech.marino,
                      ),
                    ),
                    Text(etiquetaConteo!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
