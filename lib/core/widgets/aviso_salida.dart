import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sesion/sesion.dart';
import '../tema/tema.dart';

/// Minutos que faltan para [salida]; null si no hay hora de salida conocida.
int? minutosHastaSalida(DateTime? salida, {DateTime? ahora}) {
  if (salida == null) return null;
  final segundos = salida.difference(ahora ?? DateTime.now()).inSeconds;
  return (segundos / 60).ceil();
}

/// El aviso «tu jornada termina en N minutos» sale en los últimos 10 minutos.
bool mostrarAvisoSalida(int? minutos) => minutos != null && minutos > 0 && minutos <= 10;

/// Aviso naranja en los últimos 10 minutos de la jornada (operario y transportista).
/// Revisa la hora cada 30 s; fuera de esos 10 minutos no ocupa espacio.
class AvisoSalida extends ConsumerStatefulWidget {
  const AvisoSalida({super.key});

  @override
  ConsumerState<AvisoSalida> createState() => _AvisoSalidaState();
}

class _AvisoSalidaState extends ConsumerState<AvisoSalida> {
  late final Timer _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutos = minutosHastaSalida(ref.watch(sesionProvider).expira);
    if (!mostrarAvisoSalida(minutos)) return const SizedBox.shrink();
    return Card(
      color: ColoresNovaTech.naranja,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tu jornada termina en $minutos ${minutos == 1 ? 'minuto' : 'minutos'}. '
                'Al llegar la hora, la sesión se cerrará sola.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
