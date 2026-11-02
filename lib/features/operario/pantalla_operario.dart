import 'package:flutter/material.dart';

import '../../core/widgets/scaffold_rol.dart';

/// Inicio del operario. Las funciones llegan en la fase P2.
class PantallaOperario extends StatelessWidget {
  const PantallaOperario({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScaffoldRol(
      titulo: 'Operario',
      fase: 'fase P2',
      modulos: [
        ModuloPendiente(Icons.checklist, 'Mis tareas', 'Cola de alistamientos.'),
        ModuloPendiente(Icons.qr_code_scanner, 'Alistamiento', 'Escanea cada unidad, empaca y toca «Listo para envío».'),
        ModuloPendiente(Icons.inventory_2_outlined, 'Recepción de mercancía', 'Compara con la compra aprobada y marca el estado.'),
        ModuloPendiente(Icons.schedule, 'Mi jornada', 'Tus horas y las horas extra programadas.'),
      ],
    );
  }
}
