import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../tema/tema.dart';

/// QR dibujado en la app (sin imprimir etiquetas), negro sobre blanco.
class CodigoQr extends StatelessWidget {
  const CodigoQr({super.key, required this.codigo, this.tamano = 240});

  final String codigo;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresNovaTech.borde),
      ),
      child: QrImageView(
        data: codigo,
        size: tamano,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
      ),
    );
  }
}

/// Pantalla con el QR de un código (paquete o producto), sus datos y un botón para seguir.
/// Devuelve true si la persona tocó [accion]; false o null si volvió atrás.
Future<bool?> mostrarCodigoQr(
  BuildContext context, {
  required String titulo,
  required String codigo,
  required String accion,
  List<String> detalles = const [],
  Widget? extra,
  IconData iconoAccion = Icons.check,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (contexto) => Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (contexto, limites) {
              final lado = (limites.maxWidth - 80).clamp(140.0, 280.0);
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(child: CodigoQr(codigo: codigo, tamano: lado)),
                  const SizedBox(height: 14),
                  Text(
                    codigo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                  for (final detalle in detalles)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        detalle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 15),
                      ),
                    ),
                  if (extra != null) ...[const SizedBox(height: 10), extra],
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: ColoresNovaTech.verde),
              onPressed: () => Navigator.of(contexto).pop(true),
              icon: Icon(iconoAccion),
              label: Text(accion),
            ),
          ),
        ),
      ),
    ),
  );
}
