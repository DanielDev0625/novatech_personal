import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../tema/tema.dart';

/// Cámara que lee QR y códigos de barras, con marco guía y linterna.
/// [alLeer] recibe cada código leído (ya sin espacios).
class VistaCamara extends StatefulWidget {
  const VistaCamara({super.key, required this.alLeer, this.alto});

  final ValueChanged<String> alLeer;

  /// Alto fijo; si es null ocupa todo el espacio disponible.
  final double? alto;

  @override
  State<VistaCamara> createState() => _VistaCamaraState();
}

class _VistaCamaraState extends State<VistaCamara> {
  final _camara = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 400,
  );

  @override
  void dispose() {
    _camara.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    for (final codigo in captura.barcodes) {
      final valor = codigo.rawValue?.trim();
      if (valor != null && valor.isNotEmpty) widget.alLeer(valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camara = Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _camara,
          onDetect: _alDetectar,
          errorBuilder: (context, error, _) => _ErrorCamara(error: error),
        ),
        // Marco guía en el centro.
        Center(
          child: Container(
            width: 220,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: IconButton.filled(
            tooltip: 'Linterna',
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
            onPressed: () => _camara.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined, color: Colors.white),
          ),
        ),
      ],
    );
    final alto = widget.alto;
    return alto == null ? camara : SizedBox(height: alto, child: camara);
  }
}

class _ErrorCamara extends StatelessWidget {
  const _ErrorCamara({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final sinPermiso = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            sinPermiso
                ? 'La app no tiene permiso para usar la cámara. Actívalo en los ajustes del celular.'
                : 'No se pudo abrir la cámara.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Abre la cámara a pantalla completa y devuelve el primer código leído
/// (null si la persona vuelve atrás sin escanear).
Future<String?> escanearCodigo(BuildContext context, {required String titulo, required String instruccion}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PantallaEscanear(titulo: titulo, instruccion: instruccion),
    ),
  );
}

class _PantallaEscanear extends StatefulWidget {
  const _PantallaEscanear({required this.titulo, required this.instruccion});

  final String titulo;
  final String instruccion;

  @override
  State<_PantallaEscanear> createState() => _PantallaEscanearState();
}

class _PantallaEscanearState extends State<_PantallaEscanear> {
  bool _leido = false;

  void _alLeer(String codigo) {
    if (_leido) return;
    _leido = true;
    Navigator.of(context).pop(codigo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Column(
        children: [
          Expanded(child: VistaCamara(alLeer: _alLeer)),
          Container(
            width: double.infinity,
            color: ColoresNovaTech.marino,
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              top: false,
              child: Text(
                widget.instruccion,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
