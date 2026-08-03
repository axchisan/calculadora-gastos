# Aplicaciones para cada plataforma

Un único código en `app/` se compila a tres objetivos. Todos hablan con la misma API y
comparten los mismos datos.

| Plataforma | Cómo se usa | Tamaño |
|---|---|---|
| **Web** | [gastos.axchisan.com](https://gastos.axchisan.com) | — |
| **Android** | APK instalable | 54 MB |
| **macOS** | Aplicación de escritorio | 46 MB |

La web se despliega sola en cada cambio; las otras dos se compilan a mano cuando se quieren
actualizar.

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

# Android
flutter build apk --release --dart-define=API_URL=https://api.axchisan.com

# macOS
flutter build macos --release --dart-define=API_URL=https://api.axchisan.com
```

> **`--dart-define=API_URL` no es opcional.** Sin él, la aplicación apunta a
> `http://localhost:8080`, que es el valor por defecto para desarrollo. Una compilación de
> release sin ese parámetro se instala sin problemas y falla al intentar conectarse.

Resultados:

- `build/web/`
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/macos/Build/Products/Release/calculadora_gastos.app`

## Instalar en Android

El APK no viene de Play Store, así que el teléfono pedirá permiso para instalarlo:

1. Copiar el APK al teléfono (cable, correo o cualquier servicio de archivos).
2. Abrirlo desde el gestor de archivos.
3. Android pedirá activar **«Permitir apps de esta fuente»** para la aplicación desde la que se
   abrió. Es un permiso por origen, no general.

### Sobre la firma

El APK está firmado con la **clave de depuración** que genera Flutter, no con una propia. Para
uso personal es suficiente: se instala y funciona igual.

Lo que implica:

- **No sirve para publicar en Play Store**, que exige una clave propia.
- Al cambiar de máquina de compilación, la clave de depuración cambia y Android trata la
  aplicación como distinta: hay que desinstalar la anterior para poder instalar la nueva.

Si algún día se quisiera publicar o mantener actualizaciones estables entre máquinas, habría
que generar una clave propia y guardarla fuera del repositorio:

```bash
keytool -genkey -v -keystore ~/gastos-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias gastos
```

Y referenciarla desde `android/key.properties`, que ya está excluido en `.gitignore`.

## Instalar en macOS

Arrastrar `calculadora_gastos.app` a la carpeta de Aplicaciones.

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
