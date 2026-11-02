import '../formato.dart';

/// Roles del sistema: los mismos que devuelve el backend.
enum Rol {
  usuario,
  operario,
  transportista,
  gerente,
  administrador;

  static Rol desde(String? valor) =>
      Rol.values.firstWhere((r) => r.name == valor, orElse: () => Rol.usuario);

  String get etiqueta => switch (this) {
        Rol.usuario => 'Cliente',
        Rol.operario => 'Operario',
        Rol.transportista => 'Transportista',
        Rol.gerente => 'Gerente',
        Rol.administrador => 'Administrador',
      };

  /// Parte de la app de cada rol: todas sus rutas empiezan así (navegación por rol).
  String get prefijo => switch (this) {
        Rol.operario => '/operario',
        Rol.transportista => '/transportista',
        Rol.gerente => '/gerencia',
        Rol.administrador => '/admin',
        Rol.usuario => '/login',
      };

  /// Primera pestaña del rol al entrar.
  String get rutaInicio => switch (this) {
        Rol.operario => '/operario/tareas',
        Rol.transportista => '/transportista/entregas',
        Rol.gerente => '/gerencia/panel',
        Rol.administrador => '/admin/usuarios',
        Rol.usuario => '/login',
      };

  /// El cliente tiene su propia app; aquí solo entra el personal.
  bool get esPersonal => this != Rol.usuario;

  /// Operario y transportista tienen horario: su sesión vence a la hora de salida.
  bool get tieneJornada => this == Rol.operario || this == Rol.transportista;
}

/// Pedido tal como aparece en las listas del personal (cola, zona de envíos...).
class PedidoResumen {
  const PedidoResumen({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.cliente,
    required this.unidades,
    required this.fechaPrometida,
    required this.creadoEn,
  });

  final int id;
  final String codigo;
  final String estado;
  final String? cliente;
  final int unidades;
  final DateTime? fechaPrometida;
  final DateTime? creadoEn;

  factory PedidoResumen.fromJson(Map<String, dynamic> json) => PedidoResumen(
        id: json['id'] as int,
        codigo: json['codigo'] as String,
        estado: json['estado'] as String,
        cliente: json['cliente'] as String?,
        unidades: json['unidades'] as int? ?? 0,
        fechaPrometida: leerFecha(json['fecha_prometida']),
        creadoEn: leerFecha(json['creado_en']),
      );
}

class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.usuario,
    required this.rol,
    required this.activo,
  });

  final int id;
  final String nombre;
  final String usuario;
  final Rol rol;
  final bool activo;

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        usuario: json['usuario'] as String,
        rol: Rol.desde(json['rol'] as String?),
        activo: json['activo'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'usuario': usuario,
        'rol': rol.name,
        'activo': activo,
      };
}

/// Compra a proveedor (la sugiere el sistema, la aprueba gerencia y la recibe el operario).
class Compra {
  const Compra({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.sku,
    required this.producto,
    required this.cantidad,
    required this.proveedor,
    required this.fechaEstimada,
    required this.atrasada,
    required this.diasAtraso,
    required this.lote,
    required this.diferencia,
    required this.nota,
    this.stockActual = 0,
    this.stockMinimo = 0,
    this.cantidadBuena,
    this.cantidadDanada,
    this.recibidaPor,
  });

  final int id;
  final String codigo;
  final String estado;
  final String sku;
  final String producto;

  /// Cantidad sugerida, que es la que se aprueba y debe llegar.
  final int cantidad;
  final String? proveedor;
  final DateTime? fechaEstimada;
  final bool atrasada;
  final int diasAtraso;
  final String? lote;
  final int? diferencia;
  final String? nota;
  final int stockActual;
  final int stockMinimo;
  final int? cantidadBuena;
  final int? cantidadDanada;
  final String? recibidaPor;

  bool get sugerida => estado == 'sugerida';
  bool get recibida => estado == 'recibida';
  bool get conDiferencias => estado == 'con_diferencias';

  factory Compra.fromJson(Map<String, dynamic> json) => Compra(
        id: json['id'] as int,
        codigo: json['codigo'] as String,
        estado: json['estado'] as String,
        sku: json['sku'] as String,
        producto: json['producto'] as String,
        cantidad: json['cantidad_sugerida'] as int,
        proveedor: json['proveedor'] as String?,
        fechaEstimada: leerFecha(json['fecha_estimada']),
        atrasada: json['atrasada'] as bool? ?? false,
        diasAtraso: json['dias_atraso'] as int? ?? 0,
        lote: json['lote'] as String?,
        diferencia: json['diferencia'] as int?,
        nota: json['nota'] as String?,
        stockActual: json['stock_actual'] as int? ?? 0,
        stockMinimo: json['stock_minimo'] as int? ?? 0,
        cantidadBuena: json['cantidad_buena'] as int?,
        cantidadDanada: json['cantidad_danada'] as int?,
        recibidaPor: json['recibida_por'] as String?,
      );
}

enum EstadoHoraExtra {
  solicitada('Pendiente'),
  aprobada('Aprobada'),
  rechazada('Rechazada');

  const EstadoHoraExtra(this.etiqueta);
  final String etiqueta;

  static EstadoHoraExtra desde(String? valor) =>
      values.firstWhere((e) => e.name == valor, orElse: () => EstadoHoraExtra.solicitada);
}

/// Motivos fijos que acepta el backend (no se escribe nada).
enum MotivoHoraExtra {
  pedidosUrgentes('pedidos_urgentes', 'Pedidos urgentes'),
  inventario('inventario', 'Inventario'),
  mercanciaPorRecibir('mercancia_por_recibir', 'Mercancía por recibir'),
  apoyoLogistica('apoyo_logistica', 'Apoyo a logística'),
  otro('otro', 'Otro');

  const MotivoHoraExtra(this.valor, this.etiqueta);

  /// Texto que espera el backend.
  final String valor;
  final String etiqueta;

  static MotivoHoraExtra? desde(String? valor) {
    for (final motivo in values) {
      if (motivo.valor == valor) return motivo;
    }
    return null;
  }
}

class HoraExtra {
  const HoraExtra({
    required this.id,
    required this.fecha,
    required this.horaFin,
    required this.estado,
    required this.motivo,
    required this.esCorreccion,
    required this.resueltaPor,
    this.usuarioId = 0,
    this.usuario = '',
  });

  final int id;
  final DateTime fecha;
  final String horaFin;
  final EstadoHoraExtra estado;
  final MotivoHoraExtra? motivo;
  final bool esCorreccion;
  final String? resueltaPor;
  final int usuarioId;

  /// Nombre de la persona (lo ve gerencia).
  final String usuario;

  factory HoraExtra.fromJson(Map<String, dynamic> json) => HoraExtra(
        id: json['id'] as int,
        fecha: DateTime.parse(json['fecha'] as String),
        horaFin: json['hora_fin'] as String,
        estado: EstadoHoraExtra.desde(json['estado'] as String?),
        motivo: MotivoHoraExtra.desde(json['motivo'] as String?),
        esCorreccion: json['es_correccion'] as bool? ?? false,
        resueltaPor: json['resuelta_por'] as String?,
        usuarioId: json['usuario_id'] as int? ?? 0,
        usuario: json['usuario'] as String? ?? '',
      );
}
