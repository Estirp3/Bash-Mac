#!/bin/bash

# -----------------------------------------------
# Script global para setear entorno JAVA_HOME, ANDROID_HOME, M2_HOME y PATHs en Mac (todos los usuarios)
# Descarga Maven si no existe, y prepara plantilla para automatizar Java.
# By Estirp3
# https://github.com/Estirp3
# -----------------------------------------------

PROFILE_D_FILE="/etc/profile.d/custom_env.sh"

# 1. Variables para Java y Android
JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-11.jdk/Contents/Home"
ANDROID_HOME='\$HOME/Library/Android/sdk'
PATH_ANDROID='export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"'

# 2. Maven: Detectar, descomprimir o descargar e instalar (globalmente en /opt)
MAVEN_VERSION="3.9.6"
MAVEN_DIR="/opt/apache-maven-$MAVEN_VERSION"
MAVEN_TGZ="/opt/apache-maven-$MAVEN_VERSION-bin.tar.gz"
MAVEN_URL="https://dlcdn.apache.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz"
PATH_MAVEN='export PATH="$PATH:$M2_HOME/bin"'

# Requiere sudo
if [ "$EUID" -ne 0 ]; then
  echo "❗ Este script debe ejecutarse con sudo:"
  echo "   sudo $0"
  exit 1
fi

# Detecta Maven
if command -v mvn >/dev/null 2>&1; then
  echo "✔️ Maven ya está instalado: $(mvn -v | head -n 1)"
  M2_HOME=$(dirname $(dirname $(command -v mvn)))
elif [ -d "$MAVEN_DIR" ]; then
  echo "✔️ Carpeta Maven ya existe en $MAVEN_DIR"
  M2_HOME="$MAVEN_DIR"
elif [ -f "$MAVEN_TGZ" ]; then
  echo "💾 Archivo $MAVEN_TGZ ya descargado, descomprimiendo..."
  tar -xzf "$MAVEN_TGZ" -C /opt
  M2_HOME="$MAVEN_DIR"
  echo "✅ Maven descomprimido en $MAVEN_DIR"
else
  echo "⬇️  Descargando Maven $MAVEN_VERSION a $MAVEN_TGZ ..."
  curl -L -o "$MAVEN_TGZ" "$MAVEN_URL"
  tar -xzf "$MAVEN_TGZ" -C /opt
  chown -R root:admin "$MAVEN_DIR"
  M2_HOME="$MAVEN_DIR"
  echo "✅ Maven descargado y descomprimido en $MAVEN_DIR"
fi

# 3. (Opcional) Automatizar instalación de Java aquí si quieres (por ahora, solo verifica)
if [ -x "$JAVA_HOME/bin/java" ]; then
  echo "✔️ Java encontrado en $JAVA_HOME"
else
  if command -v java >/dev/null 2>&1; then
    echo "✔️ Java ya está instalado: $(java -version 2>&1 | head -n 1)"
    JAVA_HOME="$(dirname $(dirname $(readlink $(command -v java))))"
  else
    echo "❗ No se encontró Java instalado ni en $JAVA_HOME"
    echo "   (Puedes automatizar la descarga si lo deseas, por ahora solo plantilla)"
  fi
fi

# 4. Crear archivo global si no existe
if [ ! -f "$PROFILE_D_FILE" ]; then
  touch "$PROFILE_D_FILE"
  chmod 644 "$PROFILE_D_FILE"
  echo "# Variables de entorno globales para todos los usuarios (Chapti)" > "$PROFILE_D_FILE"
fi

# 5. Función para agregar/actualizar variables globales
add_or_update_global_var() {
  local var="$1"
  local value="$2"
  local file="$3"
  if grep -q "export $var=" "$file" 2>/dev/null; then
    sed -i '' "s|export $var=.*|export $var=\"$value\"|" "$file"
    echo "🔄 Actualizado $var en $file"
  else
    echo "export $var=\"$value\"" >> "$file"
    echo "➕ Agregado $var a $file"
  fi
}

add_or_update_global_var "JAVA_HOME" "$JAVA_HOME" "$PROFILE_D_FILE"
add_or_update_global_var "ANDROID_HOME" "$ANDROID_HOME" "$PROFILE_D_FILE"
add_or_update_global_var "M2_HOME" "$M2_HOME" "$PROFILE_D_FILE"

if ! grep -Fq "$PATH_ANDROID" "$PROFILE_D_FILE"; then
  echo "$PATH_ANDROID" >> "$PROFILE_D_FILE"
  echo "➕ Agregado PATH extra para Android SDK"
else
  echo "✔ PATH extra para Android SDK ya estaba bien"
fi

if ! grep -Fq "$PATH_MAVEN" "$PROFILE_D_FILE"; then
  echo "$PATH_MAVEN" >> "$PROFILE_D_FILE"
  echo "➕ Agregado PATH para Maven"
else
  echo "✔ PATH para Maven ya estaba bien"
fi

# 6. Info amigable arquitectura (opcional)
CPU_BRAND=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
ARCH=$(uname -m)
APPLE_CHIP=""
if [[ "$ARCH" == "arm64" ]]; then
  if echo "$CPU_BRAND" | grep -q "M1"; then
    APPLE_CHIP="M1"
  elif echo "$CPU_BRAND" | grep -q "M2"; then
    APPLE_CHIP="M2"
  elif echo "$CPU_BRAND" | grep -q "M3"; then
    APPLE_CHIP="M3"
  elif echo "$CPU_BRAND" | grep -q "M4"; then
    APPLE_CHIP="M4"
  else
    APPLE_CHIP="Apple Silicon (arm64)"
  fi
  echo "🍏 Servidor configurado para Mac con chip $APPLE_CHIP"
else
  APPLE_CHIP="Intel"
  echo "💻 Servidor configurado para Mac Intel"
fi

# 7. Mostrar valores seteados
echo ""
echo "🔍 Variables globales configuradas:"
echo "JAVA_HOME: $JAVA_HOME"
echo "ANDROID_HOME: $ANDROID_HOME"
echo "M2_HOME: $M2_HOME"
echo "PATH extra Android: $PATH_ANDROID"
echo "PATH extra Maven: $PATH_MAVEN"
echo ""
echo "✅ ¡Listo! Variables de entorno GLOBALES listas para todos los usuarios."
echo "🔄 Cierra y abre terminal para que todos los usuarios tengan los cambios."
echo ""
echo "By Chapti 😎"
