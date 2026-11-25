import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

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
    registrarExtractos(flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  /// Elegir el extracto en PDF que se importa en «Por revisar».
  private func registrarExtractos(_ mensajero: FlutterBinaryMessenger) {
    let canal = FlutterMethodChannel(
      name: "com.axchisan.calculadora_gastos/extractos", binaryMessenger: mensajero)
    canal.setMethodCallHandler { llamada, respuesta in
      guard llamada.method == "elegirPdf" || llamada.method == "elegirImagen" else {
        respuesta(FlutterMethodNotImplemented)
        return
      }
      let esPdf = llamada.method == "elegirPdf"
      let panel = NSOpenPanel()
      panel.allowedContentTypes = esPdf ? [UTType.pdf] : [UTType.image]
      panel.allowsMultipleSelection = false
      panel.canChooseDirectories = false
      panel.message = esPdf ? "Elige el extracto «Movimientos» del banco" : "Elige una foto"
      panel.begin { eleccion in
        guard eleccion == .OK, let url = panel.url, let datos = try? Data(contentsOf: url) else {
          respuesta(nil)
          return
        }
        respuesta(FlutterStandardTypedData(bytes: datos))
      }
    }
  }
}
