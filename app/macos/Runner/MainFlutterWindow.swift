import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Tamaño con el que se abre la ventana la primera vez, en puntos.
  ///
  /// Proporción vertical: la aplicación es una sucesión de tarjetas y listas; en horizontal las
  /// tarjetas quedan con demasiado aire a los lados.
  private static let tamanoInicial = NSSize(width: 460, height: 900)

  /// Por debajo de este ancho las filas de importes se parten en dos líneas y las etiquetas de
  /// la barra de navegación empiezan a truncarse.
  private static let tamanoMinimo = NSSize(width: 380, height: 560)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    self.contentMinSize = MainFlutterWindow.tamanoMinimo

    // El tamaño inicial solo se impone en el primer arranque: si macOS ya guardó un marco de
    // una sesión anterior, manda ese, para no deshacer lo que el usuario haya ajustado. Hay que
    // restaurar antes de registrar el nombre de autoguardado, o se guarda el marco de la
    // plantilla encima del que se quería recuperar.
    let nombreDelMarco = "VentanaPrincipal"
    let habiaMarcoGuardado = self.setFrameUsingName(nombreDelMarco)
    self.setFrameAutosaveName(nombreDelMarco)

    if !habiaMarcoGuardado {
      self.setContentSize(MainFlutterWindow.tamanoInicial)
      self.center()
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
