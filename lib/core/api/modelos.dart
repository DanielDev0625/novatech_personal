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

  /// Pantalla de inicio de cada rol (navegación por rol).
  String get rutaInicio => switch (this) {
        Rol.operario => '/operario',
        Rol.transportista => '/transportista',
        Rol.gerente => '/gerencia',
        Rol.administrador => '/admin',
        Rol.usuario => '/login',
      };

  /// El cliente tiene su propia app; aquí solo entra el personal.
  bool get esPersonal => this != Rol.usuario;

  /// Operario y transportista tienen horario: su sesión vence a la hora de salida.
  bool get tieneJornada => this == Rol.operario || this == Rol.transportista;
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
