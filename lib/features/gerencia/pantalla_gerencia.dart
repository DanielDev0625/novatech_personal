import 'package:flutter/material.dart';

import '../../core/widgets/scaffold_rol.dart';

/// Inicio del gerente. Las funciones llegan en la fase P4.
class PantallaGerencia extends StatelessWidget {
  const PantallaGerencia({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScaffoldRol(
      titulo: 'Gerencia',
      fase: 'fase P4',
      modulos: [
        ModuloPendiente(Icons.dashboard_outlined, 'Panel', 'Tarjetas con el estado del día.'),
        ModuloPendiente(Icons.task_alt, 'Aprobaciones', 'Compras sugeridas y horas extra, con un toque.'),
        ModuloPendiente(Icons.more_time, 'Horas extra de la semana', 'Operarios, días y hora de fin con selectores.'),
        ModuloPendiente(Icons.bar_chart, 'Estadísticas, energía y retrasos', 'Gráficos y jornadas con «salida no registrada».'),
      ],
    );
  }
}
