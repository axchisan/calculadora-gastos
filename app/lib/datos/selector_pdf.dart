/// Elige un PDF o una imagen del dispositivo y devuelve su contenido, o null si se cancela.
///
/// Hecho a mano y no con file_picker: su plugin de Android no compila con Flutter 3.44. En
/// Android usa el selector de documentos del sistema, en el Mac el panel de abrir y en la web
/// un `<input type="file">`.
library;

export 'selector_pdf_nativo.dart'
    if (dart.library.js_interop) 'selector_pdf_web.dart';
