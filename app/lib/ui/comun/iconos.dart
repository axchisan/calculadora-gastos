import 'package:flutter/widgets.dart';

import '../../dominio/modelos.dart';

const String _regular = 'PhosphorRegular';
const String _negrita = 'PhosphorBold';
const String _relleno = 'PhosphorFill';

/// Iconos de la aplicación: trazo fino de Phosphor (licencia MIT), uno por concepto.
///
/// Se reúnen aquí para que una categoría tenga el mismo icono en todas las pantallas, y para
/// que cambiar la familia de iconos sea tocar un solo archivo.
///
/// Las fuentes van en `assets/iconos/` y los códigos se escriben aquí a mano. El paquete
/// `phosphor_flutter` dejó de compilar con Flutter 3.44 (extiende `IconData`, que ahora es
/// `final`) y no se actualiza desde 2024. Los códigos salen de las tablas de ese paquete
/// (versión 2.1.0), que son las de las fuentes copiadas. Al ser constantes, la compilación de publicación recorta de cada
/// fuente los iconos que no se usan.
class Iconos {
  const Iconos._();

  // Navegación.
  static const IconData inicio = IconData(0xe2c2, fontFamily: _regular);
  static const IconData inicioActivo = IconData(0xe2c2, fontFamily: _relleno);
  static const IconData movimientos = IconData(0xe2f0, fontFamily: _regular);
  static const IconData movimientosActivo = IconData(
    0xe2f0,
    fontFamily: _negrita,
  );
  static const IconData deudas = IconData(0xe1d2, fontFamily: _regular);
  static const IconData deudasActivo = IconData(0xe1d2, fontFamily: _relleno);
  static const IconData analisis = IconData(0xe150, fontFamily: _regular);
  static const IconData analisisActivo = IconData(0xe150, fontFamily: _relleno);

  // Acciones.
  static const IconData anadir = IconData(0xe3d4, fontFamily: _negrita);
  static const IconData listo = IconData(0xe182, fontFamily: _negrita);
  static const IconData atencion = IconData(0xe4e2, fontFamily: _regular);
  static const IconData desplegar = IconData(0xe136, fontFamily: _regular);
  static const IconData entrar = IconData(0xe13a, fontFamily: _regular);
  static const IconData borrar = IconData(0xe4a6, fontFamily: _regular);
  static const IconData editar = IconData(0xe3b4, fontFamily: _regular);
  static const IconData buscar = IconData(0xe30c, fontFamily: _regular);
  static const IconData cerrar = IconData(0xe4f6, fontFamily: _regular);
  static const IconData retroceso = IconData(0xe0ae, fontFamily: _regular);
  static const IconData deshacer = IconData(0xe038, fontFamily: _regular);
  static const IconData ajustes = IconData(0xe272, fontFamily: _regular);
  static const IconData calendario = IconData(0xe10a, fontFamily: _regular);
  static const IconData sinConexion = IconData(0xe1b6, fontFamily: _regular);
  static const IconData entro = IconData(0xe03e, fontFamily: _regular);
  static const IconData salio = IconData(0xe08e, fontFamily: _regular);

  // Tema.
  static const IconData claro = IconData(0xe472, fontFamily: _regular);
  static const IconData oscuro = IconData(0xe330, fontFamily: _regular);
  static const IconData sistema = IconData(0xe560, fontFamily: _regular);

  // Dinero y cuentas.
  static const IconData banco = IconData(0xe0b4, fontFamily: _regular);
  static const IconData efectivo = IconData(0xe588, fontFamily: _regular);
  static const IconData billetera = IconData(0xe1e0, fontFamily: _regular);
  static const IconData tarjeta = IconData(0xe1d2, fontFamily: _regular);
  static const IconData dolar = IconData(0xe550, fontFamily: _regular);
  static const IconData trabajo = IconData(0xe0ee, fontFamily: _regular);
  static const IconData prestamo = IconData(0xea8c, fontFamily: _regular);
  static const IconData familia = IconData(0xe4d6, fontFamily: _regular);
  static const IconData intereses = IconData(0xe3b6, fontFamily: _regular);
  static const IconData meta = IconData(0xe47c, fontFamily: _regular);
  static const IconData ahorro = IconData(0xea04, fontFamily: _regular);
  static const IconData mascota = IconData(0xe74a, fontFamily: _regular);
  static const IconData recibo = IconData(0xe3ec, fontFamily: _regular);

  /// El icono de cada tipo de ingreso.
  static IconData deIngreso(TipoIngreso tipo) => switch (tipo) {
    TipoIngreso.trabajo => trabajo,
    TipoIngreso.familia => familia,
    TipoIngreso.prestamo => prestamo,
    TipoIngreso.intereses => intereses,
    TipoIngreso.saldo => banco,
    TipoIngreso.otro => entro,
  };

  /// El icono de cada categoría de gasto.
  static IconData deCategoria(CategoriaGasto categoria) => switch (categoria) {
    CategoriaGasto.vivienda => const IconData(0xe2c2, fontFamily: _regular),
    CategoriaGasto.alimentacion => const IconData(0xe262, fontFamily: _regular),
    CategoriaGasto.transporte => const IconData(0xe106, fontFamily: _regular),
    CategoriaGasto.servicios => const IconData(0xe4ea, fontFamily: _regular),
    CategoriaGasto.suscripciones => const IconData(
      0xe754,
      fontFamily: _regular,
    ),
    CategoriaGasto.salud => const IconData(0xe2ac, fontFamily: _regular),
    CategoriaGasto.educacion => const IconData(0xe62c, fontFamily: _regular),
    CategoriaGasto.deporte => const IconData(0xe0b6, fontFamily: _regular),
    CategoriaGasto.herramientas => const IconData(0xe5d4, fontFamily: _regular),
    CategoriaGasto.deuda => const IconData(0xe1d2, fontFamily: _regular),
    CategoriaGasto.ahorro => const IconData(0xea04, fontFamily: _regular),
    CategoriaGasto.antojos => const IconData(0xe1c2, fontFamily: _regular),
    CategoriaGasto.cuidadoPersonal => const IconData(
      0xe6a2,
      fontFamily: _regular,
    ),
    CategoriaGasto.comisiones => const IconData(0xe3b6, fontFamily: _regular),
    CategoriaGasto.ocio => const IconData(0xe26e, fontFamily: _regular),
    CategoriaGasto.ropa => const IconData(0xe670, fontFamily: _regular),
    CategoriaGasto.hogar => const IconData(0xe7f6, fontFamily: _regular),
    CategoriaGasto.mascota => mascota,
    CategoriaGasto.otro => const IconData(0xe416, fontFamily: _regular),
  };
}
