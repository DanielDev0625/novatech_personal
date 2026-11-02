import 'package:flutter/material.dart';

import '../../core/widgets/scaffold_rol.dart';

/// Inicio del administrador. Las funciones llegan en la fase P4.
class PantallaAdmin extends StatelessWidget {
  const PantallaAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScaffoldRol(
      titulo: 'Administración',
      fase: 'fase P4',
      modulos: [
        ModuloPendiente(Icons.group_outlined, 'Usuarios y roles', 'Crear cuentas del personal.'),
        ModuloPendiente(Icons.bolt_outlined, 'Zonas y equipos de energía', 'Potencia en kW de cada equipo.'),
        ModuloPendiente(Icons.tune, 'Parámetros', 'Tarifa de kWh, margen, tope de horas extra y más.'),
        ModuloPendiente(Icons.upload_file, 'Importaciones', 'Catálogo desde Excel.'),
        ModuloPendiente(Icons.history, 'Bitácora', 'Aprobaciones e intentos fuera de horario.'),
      ],
    );
  }
}
