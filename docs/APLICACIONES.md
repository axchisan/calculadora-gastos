# Aplicaciones para cada plataforma

Un único código en `app/` se compila a tres objetivos. Todos hablan con la misma API y
comparten los mismos datos.

| Plataforma | Cómo se usa | Tamaño |
|---|---|---|
| **Web** | [gastos.axchisan.com](https://gastos.axchisan.com) | — |
| **Android** | APK instalable | 20 MB (arm64) |
| **macOS** | Aplicación de escritorio | 48 MB |

La web se despliega sola en cada cambio; las otras dos se compilan a mano cuando se quieren
actualizar.

## Identidad de la aplicación

| Dato | Valor |
|---|---|
| Nombre completo | Calculadora de gastos |
| Nombre en el lanzador | Mis gastos |
| Identificador (Android) | `com.axchisan.calculadora_gastos` |
| Identificador (macOS) | `com.axchisan.calculadoraGastos` |
| Versión | `pubspec.yaml`, campo `version` |

El nombre del lanzador va abreviado porque tanto Android como la barra de menús de macOS
recortan las etiquetas largas. macOS no admite guiones bajos en el identificador del paquete, de
ahí que no coincida con el de Android.

**Al publicar una versión nueva hay que subir el número tras el `+` en `version`.** Es el
`versionCode` de Android, y el sistema rechaza instalar un APK cuyo código no sea mayor que el
instalado.

### Iconos

Se generan, no se editan a mano:

```bash
cd app
python3 tools/generar_icono.py     # dibuja assets/icono/ con Pillow
dart run flutter_launcher_icons     # los reparte a Android, macOS y web
```

`tools/generar_icono.py` dibuja el icono por código; ajustando las constantes del principio se
cambia el color o la composición.

Android no recibe la imagen tal cual, sino separada en fondo y primer plano, porque los
lanzadores la recortan con la forma que elija el usuario y solo dejan ver el 66% central. Para
que el icono del teléfono salga igual que el del Mac, el generador hace dos cosas con ese dato:

- **reduce el dibujo justo a ese 66%**, de modo que dentro del recorte ocupe la misma proporción
  que ocupa en el icono completo. Escalarlo para llenar el círculo lo dejaba ampliado y las dos
  barras atenuadas quedaban fuera de plano;
- **estira el degradado del fondo** para que recorra sus dos colores dentro de esa banda visible,
  en vez de perder los extremos en el recorte.

La comprobación es directa: componer `icono_fondo.png` con `icono_adaptativo.png`, recortar el
66% central y comparar contra `icono.png`; deben salir el mismo dibujo.

## Requisitos del entorno

| Herramienta | Para qué | Instalación |
|---|---|---|
| Flutter 3.x | Todas | `brew install --cask flutter` |
| Android SDK | APK | `brew install --cask android-commandlinetools` |
| Xcode | macOS | App Store |
| CocoaPods | macOS | `brew install cocoapods` |

Tras instalar el SDK de Android hay que apuntarlo y aceptar las licencias:

```bash
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
flutter config --android-sdk "$ANDROID_HOME"
yes | flutter doctor --android-licenses
```

## Compilar

```bash
cd app

# Web
flutter build web --release --dart-define=API_URL=https://api.axchisan.com

# Android: un APK por arquitectura, en vez de uno con las tres dentro
flutter build apk --release --split-per-abi --dart-define=API_URL=https://api.axchisan.com

# macOS
flutter build macos --release --dart-define=API_URL=https://api.axchisan.com
```

> **`--dart-define=API_URL` no es opcional.** Sin él, la aplicación apunta a
> `http://localhost:8080`, que es el valor por defecto para desarrollo. Una compilación de
> release sin ese parámetro se instala sin problemas y falla al intentar conectarse.

Resultados:

- `build/web/`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` — el de cualquier teléfono actual
- `build/macos/Build/Products/Release/Mis gastos.app`

Sin `--split-per-abi` sale un solo `app-release.apk` de 57 MB con el código nativo de las tres
arquitecturas dentro; separados, el de arm64 son 20 MB. Para instalar a mano siempre conviene
separarlos: solo se copia al teléfono el que va a usar.

## Instalar en Android

El APK no viene de Play Store, así que el teléfono pedirá permiso para instalarlo:

1. Copiar el APK al teléfono (cable, correo o cualquier servicio de archivos).
2. Abrirlo desde el gestor de archivos.
3. Android pedirá activar **«Permitir apps de esta fuente»** para la aplicación desde la que se
   abrió. Es un permiso por origen, no general.

### Sobre la firma

Si no hay `app/android/key.properties`, el APK se firma con la **clave de depuración** que
genera Flutter. Para uso personal es suficiente: se instala y funciona igual. Lo que implica:

- **No sirve para publicar en Play Store**, que exige una clave propia.
- La clave de depuración es distinta en cada máquina, así que al cambiar de ordenador Android
  trata la aplicación como si fuera otra: hay que desinstalar la anterior para instalar la
  nueva, y se pierde la sesión guardada.

Para tener una clave propia y que las actualizaciones se instalen encima sin desinstalar nada:

```bash
keytool -genkey -v -keystore ~/gastos-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias gastos
```

Y crear `app/android/key.properties`, que ya está excluido en `.gitignore`:

```properties
storeFile=/Users/mac/gastos-release.jks
storePassword=...
keyAlias=gastos
keyPassword=...
```

`build.gradle.kts` lo detecta solo: si el archivo existe firma con esa clave, y si no, con la de
depuración. Así el repositorio se puede clonar y compilar sin configurar nada.

> **Guardar copia del `.jks` y de sus contraseñas.** Si se pierde la clave no hay forma de
> publicar una actualización que Android acepte instalar sobre la versión anterior.

## Instalar en macOS

Arrastrar `Mis gastos.app` a la carpeta de Aplicaciones.

La aplicación **no está firmada con un certificado de desarrollador de Apple**, así que la
primera vez macOS la bloqueará. Para abrirla: clic derecho sobre ella → **Abrir** → **Abrir** en
el aviso. Solo hace falta la primera vez.

### Acceso al Keychain

El almacén de la sesión se configura con `useDataProtectionKeyChain: false`. El modo por
defecto del paquete exige el entitlement `keychain-access-groups`, que a su vez requiere firmar
la aplicación con un equipo de desarrollador de Apple. Sin eso, cada lectura o escritura falla
con el código **-34018** («A required entitlement isn't present»).

El síntoma es engañoso: la aplicación abre con normalidad y el botón de entrar deja de
responder, sin error ni indicador. Está cubierto por
`integration_test/almacen_sesion_test.dart`, que se ejecuta contra el Keychain real:

```bash
flutter test integration_test -d macos
```

### Permiso de red

Los *entitlements* declaran `com.apple.security.network.client`. Sin ese permiso, el sandbox de
macOS bloquea las conexiones salientes: la aplicación abriría con normalidad y se quedaría
esperando indefinidamente al hablar con la API, sin ningún mensaje que explicara por qué.

El equivalente en Android es `android.permission.INTERNET`. Solo estaba declarado en los
manifiestos de depuración y de perfil, que es donde lo pone `flutter create`, así que hasta
ahora un APK de publicación se instalaba y no podía hablar con la API. Ahora está en el
manifiesto principal.

### Tamaño de la ventana

`MainFlutterWindow.swift` fija 460 × 900 puntos al abrir por primera vez y un mínimo de
380 × 560. La proporción es vertical porque la interfaz es una sucesión de tarjetas y listas.
A partir del segundo arranque manda el tamaño que macOS haya guardado, para no deshacer lo que
se haya ajustado a mano.

## Dónde se guarda la sesión

| Plataforma | Almacén |
|---|---|
| macOS | Keychain |
| Android | Keystore |
| Web | `localStorage` |

En web no existe un almacén cifrado equivalente, y es la razón de que el token de acceso dure
solo quince minutos: limita la ventana de uso si alguien llegara a leerlo.

## Modo sin conexión

El último mes consultado se guarda en local. Sirve para dos cosas:

1. **Abrir la aplicación sin esperar.** La primera petición del día coincide con el arranque en
   frío de Lambda y con el despertar de la base de datos suspendida en Neon; el caché evita ese
   segundo y medio en blanco.
2. **Consultar sin conexión.** Aparece un aviso de que las cifras no están al día.

Solo se guardan datos de lectura: registrar un pago o un abono sigue exigiendo conexión. Una
cola de cambios pendientes traería conflictos de sincronización que no compensan en una
aplicación de un solo usuario.

El caché se borra al cerrar sesión.
