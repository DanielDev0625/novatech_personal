import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_admin.dart';

/// «Importar catálogo»: se sube el Excel, se revisa la vista previa y se confirma.
class PantallaCatalogo extends ConsumerStatefulWidget {
  const PantallaCatalogo({super.key});

  @override
  ConsumerState<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

/// Excel que acepta la importación (extensión para escritorio, tipo MIME para Android).
const _tiposExcel = XTypeGroup(
  label: 'Excel',
  extensions: ['xlsx', 'xls'],
  mimeTypes: [
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-excel',
  ],
  uniformTypeIdentifiers: ['org.openxmlformats.spreadsheetml.sheet', 'com.microsoft.excel.xls'],
);

/// Archivo elegido, ya leído.
typedef _Archivo = ({String name, List<int> bytes});

class _PantallaCatalogoState extends ConsumerState<PantallaCatalogo> {
  _Archivo? _archivo;
  Object? _vistaPrevia;
  Object? _resultado;
  bool _cargando = false;

  Future<void> _elegirExcel() async {
    final elegido = await openFile(acceptedTypeGroups: const [_tiposExcel]);
    if (elegido == null) return;
    final bytes = await elegido.readAsBytes();
    setState(() {
      _archivo = (name: elegido.name, bytes: bytes);
      _vistaPrevia = null;
      _resultado = null;
    });
    await _subir(confirmar: false);
  }

  Future<void> _subir({required bool confirmar}) async {
    final archivo = _archivo;
    if (archivo == null) return;
    setState(() => _cargando = true);
    try {
      final respuesta = await ref
          .read(apiAdminProvider)
          .importarCatalogo(archivo.bytes, archivo.name, confirmar: confirmar);
      if (!mounted) return;
      setState(() => confirmar ? _resultado = respuesta : _vistaPrevia = respuesta);
      if (confirmar) mostrarMensaje(context, 'Catálogo importado.');
    } catch (e) {
      if (mounted) mostrarMensaje(context, errorDesde(e).mensaje, error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _confirmar() async {
    final ok = await confirmar(
      context,
      titulo: 'Importar catálogo',
      texto: 'Se guardarán los productos y lotes de ${_archivo!.name}. ¿Continuar?',
      aceptar: 'Importar',
    );
    if (ok) await _subir(confirmar: true);
  }

  @override
  Widget build(BuildContext context) {
    final listo = _vistaPrevia != null && _resultado == null;
    return EsqueletoRol(
      titulo: 'Importar catálogo',
      accionInferior: listo
          ? FilledButton(
              onPressed: _cargando ? null : _confirmar,
              child: _cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Confirmar e importar'),
            )
          : null,
      hijos: [
        Row(
          children: [
            Expanded(
              child: _Opcion(
                icono: Icons.table_chart_outlined,
                color: ColoresNovaTech.verde,
                titulo: 'Excel',
                detalle: 'productos y lotes',
                onTap: _cargando ? null : _elegirExcel,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _Opcion(
                icono: Icons.picture_as_pdf_outlined,
                color: ColoresNovaTech.rojo,
                titulo: 'Factura PDF',
                detalle: 'próximamente',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_archivo == null)
          const ListaVacia(
            icono: Icons.upload_file,
            texto: 'Elige el Excel del catálogo. Primero verás una vista previa; nada se guarda hasta que confirmes.',
          ),
        if (_cargando && _vistaPrevia == null)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        if (_resultado != null) ...[
          TituloSeccion('Resultado · ${_archivo!.name}'),
          _Respuesta(datos: _resultado),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _elegirExcel,
            icon: const Icon(Icons.upload_file),
            label: const Text('Importar otro archivo'),
          ),
        ] else if (_vistaPrevia != null) ...[
          TituloSeccion('Vista previa · ${_archivo!.name}'),
          _Respuesta(datos: _vistaPrevia),
        ],
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.icono, required this.color, required this.titulo, required this.detalle, this.onTap});

  final IconData icono;
  final Color color;
  final String titulo;
  final String detalle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activo = onTap != null;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: activo ? ColoresNovaTech.azul : ColoresNovaTech.borde),
      ),
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: activo ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Icon(icono, color: color, size: 30),
                const SizedBox(height: 6),
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(detalle, style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Muestra la respuesta de la importación sin suponer su forma exacta:
/// números y textos como resumen, listas como tarjetas (las de errores en rojo).
class _Respuesta extends StatelessWidget {
  const _Respuesta({required this.datos});

  final Object? datos;

  static String _etiqueta(String clave) {
    final texto = clave.replaceAll('_', ' ');
    return texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';
  }

  static String _textoFila(Object? fila) {
    if (fila is Map) {
      final nombre = fila['nombre'] ?? fila['producto'] ?? fila['sku'];
      final resto = [
        for (final MapEntry(:key, :value) in fila.entries)
          if (value != null && value is! Map && value is! List && value != nombre) '${_etiqueta('$key')}: $value',
      ];
      return [if (nombre != null) '$nombre', ...resto].join(' · ');
    }
    return '$fila';
  }

  @override
  Widget build(BuildContext context) {
    final mapa = datos;
    if (mapa is! Map) {
      return Card(child: Padding(padding: const EdgeInsets.all(14), child: Text('$mapa')));
    }
    final resumen = mapa.entries.where((e) => e.value is! List && e.value is! Map).toList();
    final listas = mapa.entries.where((e) => e.value is List).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (resumen.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final e in resumen)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text(_etiqueta('${e.key}'))),
                          Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        for (final e in listas) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(_etiqueta('${e.key}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Insignia(
                  texto: '${(e.value as List).length}',
                  color: '${e.key}'.contains('error') ? ColoresNovaTech.rojo : ColoresNovaTech.azul,
                ),
              ],
            ),
          ),
          for (final fila in (e.value as List).take(50))
            Card(
              color: '${e.key}'.contains('error') ? ColoresNovaTech.rojo.withValues(alpha: 0.05) : null,
              child: Padding(padding: const EdgeInsets.all(12), child: Text(_textoFila(fila))),
            ),
          if ((e.value as List).length > 50)
            Text(
              'y ${(e.value as List).length - 50} más…',
              style: const TextStyle(color: ColoresNovaTech.textoSuave),
            ),
        ],
      ],
    );
  }
}
