#!/usr/bin/env bash
#
# Instala la aplicación en el teléfono por cable.
#
# Instalar el APK abriéndolo desde el gestor de archivos funciona, pero deja dos problemas:
#
#   · Play Protect avisa de que la aplicación es desconocida y hay que insistir para seguir.
#   · Android 13 marca el acceso a notificaciones como «ajuste restringido»: el interruptor
#     aparece apagado y no se deja tocar, sin explicar que el paso que falta está escondido en
#     el menú de tres puntos de la ficha de la aplicación.
#
# Ambos vienen de lo mismo: Android anota quién instaló cada aplicación, y un APK abierto a mano
# no tiene instalador anotado. Con «-i com.android.vending» la instalación queda registrada como
# venida de Play Store y ninguna de las dos restricciones se aplica.
#
# Uso:
#   1. En el teléfono: Ajustes → Acerca del teléfono → tocar «Número de compilación» siete veces
#      para habilitar las opciones de desarrollo, y allí activar «Depuración por USB».
#   2. Conectar el teléfono por cable y aceptar el aviso de confianza que aparece en pantalla.
#   3. scripts/instalar-en-el-telefono.sh

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
APK="$RAIZ/app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"

if [[ ! -x "$ADB" ]]; then
  echo "No se encontró adb en $ADB" >&2
  echo "Instálalo con: brew install --cask android-platform-tools" >&2
  exit 1
fi

if [[ ! -f "$APK" ]]; then
  echo "No hay APK compilado. Genéralo primero con:" >&2
  echo "  cd app && flutter build apk --release --split-per-abi \\" >&2
  echo "      --dart-define=API_URL=https://api.axchisan.com" >&2
  exit 1
fi

dispositivos=$("$ADB" devices | tail -n +2 | grep -c "device$" || true)
if [[ "$dispositivos" -eq 0 ]]; then
  echo "No hay ningún teléfono conectado con la depuración por USB activada." >&2
  echo "Revisa el cable y acepta el aviso de confianza que sale en la pantalla." >&2
  exit 1
fi

echo "Instalando $(basename "$APK")…"

# -r reinstala conservando los datos; -i anota Play Store como instalador, que es lo que evita
# el aviso de Play Protect y el bloqueo de los ajustes restringidos.
"$ADB" install -r -i com.android.vending "$APK"

echo
echo "Listo. El acceso a notificaciones ya se puede activar sin rodeos:"
echo "  Ajustes → Notificaciones → Acceso a notificaciones → Mis gastos"
