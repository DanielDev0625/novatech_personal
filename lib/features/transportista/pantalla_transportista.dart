import 'package:flutter/material.dart';

import '../../core/widgets/scaffold_rol.dart';

/// Inicio del transportista. Las funciones llegan en la fase P3.
class PantallaTransportista extends StatelessWidget {
  const PantallaTransportista({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScaffoldRol(
      titulo: 'Transportista',
      fase: 'fase P3',
      modulos: [
        ModuloPendiente(Icons.local_shipping_outlined, 'Entregas asignadas', 'Los pedidos de hoy.'),
        ModuloPendiente(Icons.qr_code_scanner, 'Recibir paquete', 'Escanea el QR al recibirlo.'),
        ModuloPendiente(Icons.map_outlined, 'Ruta', 'Mapa con el orden de paradas.'),
        ModuloPendiente(Icons.check_circle_outline, 'Confirmar entrega', 'Escanea el QR que muestra el cliente.'),
        ModuloPendiente(Icons.payments_outlined, 'Mi liquidación', 'Tarifas y comisiones.'),
      ],
    );
  }
}
