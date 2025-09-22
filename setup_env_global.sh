#!/bin/bash

# -----------------------------------------------
# Script global para setear JAVA_HOME, ANDROID_HOME, M2_HOME y PATH en macOS
# Descarga Maven si no existe, valida checksum y configura /etc/profile.d
# By Estirp3 (Chapti)
# -----------------------------------------------

set -u

# -------- Utilidades / Errores --------
handle_error() {
  local msg="$1"
  echo "❌ Error: $msg"
  exit 1
}

check_disk_space() {
  local required_mb=500
  local available_mb
  available_mb=$(df -m /opt 2>/dev/null | awk 'NR==2{print $4}')
  [ -z "${available_mb:-}" ] && available_mb=0
  if [ "$available_mb" -lt "$required_mb" ]; then
    handle_error "Espacio insuficiente en /opt. Requiere ${required_mb}MB, hay ${available_mb}MB."
  fi
}

check_permissions() {
  local dir="$1"
  if [ ! -w "$dir" ]; then
    handle_error "Sin permisos de escritura en $dir"
  fi
}

# -------- Requiere sudo --------
if [ "$EUID" -ne 0 ]; then
  echo "❗ Este script debe ejecutarse con sudo:"
  echo "   sudo $0"
  exit 1
fi

# -------- Variables base --------
PROFILE_D_DIR="/etc/profile.d"
PROFILE_D_FILE="$PROFILE_D_DIR/custom_env.sh"
mkdir -p "$PROFILE_D_DIR" || handle_error "No se pudo crear $PROFILE_D_DIR"

# Java / Android por defecto (puedes ajustar JAVA_HOME si usas otra versión)
JAVA_HOME_DEFAULT="/Library/Java/JavaVirtualMachines/jdk-11.jdk/Contents/Home"
ANDROID_HOME_VALUE='\$HOME/Library/Android/sdk'
PATH_ANDROID_LINE='export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"'
PATH_MAVEN_LINE='export PATH="$PATH:$M2_HOME/bin"'

# -------- Carga opcional de .env del cwd --------
config_file=".env"
[ -f "$config_file" ] && source "$config_file"

# Defaults seguros (aunque .env exista)
: "${MAVEN_VERSION:=3.9.6}"

MAVEN_TGZ_NAME="apache-maven-$MAVEN_VERSION-bin.tar.gz"
MAVEN_DIR="/opt/apache-maven-$MAVEN_VERSION"
MAVEN_TGZ="/opt/$MAVEN_TGZ_NAME"

# Mirrors confiables
MIRRORS=(
  "https://dlcdn.apache.org/maven/maven-3/$MAVEN_VERSION/binaries"
  "https://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries"
)

download_with_retry() {
  local url="$1"
  local out="$2"
  curl -fL --proto '=https' --tlsv1.2 \
       --retry 5 --retry-delay 2 --retry-connrefused \
       -o "$out" "$url"
}

verify_min_size_mb() {
  local file="$1"
  local min_mb=5
  local size_mb
  size_mb=$(du -m "$file" 2>/dev/null | awk '{print $1}')
  [ -n "$size_mb" ] && [ "$size_mb" -ge "$min_mb" ]
}

fetch_and_verify_maven() {
  local ok=0
  local sha_tmp="/opt/$MAVEN_TGZ_NAME.sha512"

  for base in "${MIRRORS[@]}"; do
    echo "⬇️  Descargando desde: $base"
    if download_with_retry "$base/$MAVEN_TGZ_NAME" "$MAVEN_TGZ"; then
      if ! verify_min_size_mb "$MAVEN_TGZ"; then
        echo "⚠️  Descarga sospechosa (muy pequeña). Probando otro mirror…"
        rm -f "$MAVEN_TGZ"
        continue
      fi

      if download_with_retry "$base/$MAVEN_TGZ_NAME.sha512" "$sha_tmp"; then
        # El .sha512 puede venir en diferentes formatos
        local expected
        expected=$(grep -Eo '^[0-9a-fA-F]{128}' "$sha_tmp" | head -n1)
        [ -z "$expected" ] && expected=$(grep -Eo '[0-9a-fA-F]{128}' "$sha_tmp" | tail -n1)

        if [ -z "$expected" ]; then
          echo "⚠️  No pude parsear el SHA512. Contenido:"
          head -n2 "$sha_tmp"
          rm -f "$sha_tmp" "$MAVEN_TGZ"
          continue
        fi

        local actual
        actual=$(shasum -a 512 "$MAVEN_TGZ" | awk '{print $1}')
        if [ "$expected" = "$actual" ]; then
          echo "✅ Checksum OK"
          ok=1
          rm -f "$sha_tmp"
          break
        else
          echo "❌ Checksum NO coincide"
          rm -f "$sha_tmp" "$MAVEN_TGZ"
        fi
      else
        echo "⚠️  No pude bajar $MAVEN_TGZ_NAME.sha512 desde $base"
        rm -f "$MAVEN_TGZ"
      fi
    else
      echo "⚠️  Falló la descarga desde $base"
    fi
  done

  [ "$ok" -eq 1 ] || handle_error "No se pudo descargar/verificar Maven desde ningún mirror"
}

# -------- Maven: detectar / descargar / instalar --------
if command -v mvn >/dev/null 2>&1; then
  echo "✔️ Maven ya está instalado: $(mvn -v | head -n 1)"
  M2_HOME="$(dirname "$(dirname "$(command -v mvn)")")"
elif [ -d "$MAVEN_DIR" ]; then
  echo "✔️ Carpeta Maven ya existe en $MAVEN_DIR"
  M2_HOME="$MAVEN_DIR"
elif [ -f "$MAVEN_TGZ" ]; then
  echo "💾 TGZ ya existe. Verificando tamaño y checksum…"
  if verify_min_size_mb "$MAVEN_TGZ"; then
    fetch_and_verify_maven  # descarga .sha512 y valida
  else
    rm -f "$MAVEN_TGZ"
    check_disk_space
    check_permissions "/opt"
    fetch_and_verify_maven
  fi
  tar -xzf "$MAVEN_TGZ" -C /opt || handle_error "Error al descomprimir Maven"
  chown -R root:admin "$MAVEN_DIR" && chmod -R 755 "$MAVEN_DIR"
  M2_HOME="$MAVEN_DIR"
  echo "✅ Maven descomprimido en $MAVEN_DIR"
else
  echo "⬇️  Descargando Maven $MAVEN_VERSION a $MAVEN_TGZ ..."
  check_disk_space
  check_permissions "/opt"
  fetch_and_verify_maven
  tar -xzf "$MAVEN_TGZ" -C /opt || handle_error "Error al descomprimir Maven"
  chown -R root:admin "$MAVEN_DIR" && chmod -R 755 "$MAVEN_DIR"
  M2_HOME="$MAVEN_DIR"
  echo "✅ Maven descargado y descomprimido en $MAVEN_DIR"
fi

# -------- Java: detectar --------
JAVA_HOME_VAL="$JAVA_HOME_DEFAULT"
if [ -x "$JAVA_HOME_VAL/bin/java" ]; then
  echo "✔️ Java encontrado en $JAVA_HOME_VAL"
else
  if command -v java >/dev/null 2>&1; then
    echo "✔️ Java ya está instalado: $(java -version 2>&1 | head -n 1)"
    # Resolver JAVA_HOME a partir del binario
    JAVA_HOME_VAL="$(/usr/libexec/java_home 2>/dev/null || true)"
    [ -z "${JAVA_HOME_VAL:-}" ] && JAVA_HOME_VAL="$(dirname "$(dirname "$(readlink "$(command -v java)" 2>/dev/null || echo "$(command -v java)")")")"
  else
    echo "❗ No se encontró Java instalado ni en $JAVA_HOME_DEFAULT"
    echo "   (Plantilla: puedes automatizar su instalación si lo deseas)"
    JAVA_HOME_VAL="$JAVA_HOME_DEFAULT"
  fi
fi

# -------- Crear/actualizar archivo global --------
if [ ! -f "$PROFILE_D_FILE" ]; then
  touch "$PROFILE_D_FILE" || handle_error "No se pudo crear $PROFILE_D_FILE"
  chmod 644 "$PROFILE_D_FILE"
  echo "# Variables de entorno globales (Chapti)" > "$PROFILE_D_FILE"
fi

# Función para setear/actualizar export en profile.d (compatible con sed BSD)
add_or_update_global_var() {
  local var="$1"
  local value="$2"
  local file="$3"

  if grep -qE "^[[:space:]]*export[[:space:]]+$var=" "$file" 2>/dev/null; then
    # Reemplazo BSD sed
    sed -i '' "s|^[[:space:]]*export[[:space:]]\+$var=.*|export $var=\"$value\"|" "$file" \
      || handle_error "No se pudo actualizar $var en $file"
    echo "🔄 Actualizado $var en $file"
  else
    echo "export $var=\"$value\"" >> "$file" \
      || handle_error "No se pudo escribir $var en $file"
    echo "➕ Agregado $var a $file"
  fi
}

add_or_update_global_var "JAVA_HOME" "$JAVA_HOME_VAL" "$PROFILE_D_FILE"
add_or_update_global_var "ANDROID_HOME" "$ANDROID_HOME_VALUE" "$PROFILE_D_FILE"
add_or_update_global_var "M2_HOME" "$M2_HOME" "$PROFILE_D_FILE"

# Añadir PATH Android si falta
if ! grep -Fq "$PATH_ANDROID_LINE" "$PROFILE_D_FILE"; then
  echo "$PATH_ANDROID_LINE" >> "$PROFILE_D_FILE"
  echo "➕ Agregado PATH extra para Android SDK"
else
  echo "✔ PATH extra para Android SDK ya estaba bien"
fi

# Añadir PATH Maven si falta
if ! grep -Fq "$PATH_MAVEN_LINE" "$PROFILE_D_FILE"; then
  echo "$PATH_MAVEN_LINE" >> "$PROFILE_D_FILE"
  echo "➕ Agregado PATH para Maven"
else
  echo "✔ PATH para Maven ya estaba bien"
fi

# -------- Info de arquitectura --------
CPU_BRAND=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "")
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  if echo "$CPU_BRAND" | grep -q "M1"; then CHIP="M1"
  elif echo "$CPU_BRAND" | grep -q "M2"; then CHIP="M2"
  elif echo "$CPU_BRAND" | grep -q "M3"; then CHIP="M3"
  elif echo "$CPU_BRAND" | grep -q "M4"; then CHIP="M4"
  else CHIP="Apple Silicon (arm64)"
  fi
  echo "🍏 Servidor configurado para Mac con chip $CHIP"
else
  echo "💻 Servidor configurado para Mac Intel"
fi

# -------- Resumen --------
echo ""
echo "🔍 Variables globales configuradas:"
echo "JAVA_HOME: $JAVA_HOME_VAL"
echo "ANDROID_HOME: $ANDROID_HOME_VALUE"
echo "M2_HOME: $M2_HOME"
echo "PATH extra Android: $PATH_ANDROID_LINE"
echo "PATH extra Maven: $PATH_MAVEN_LINE"
echo ""
echo "✅ ¡Listo! Variables GLOBALES listas para todos los usuarios."
echo "🔄 Cierra y abre terminal (o ejecuta: source $PROFILE_D_FILE) para aplicar."
echo ""
echo "By Estirp3 😎"
