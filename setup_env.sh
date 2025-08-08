#!/bin/bash

# -----------------------------------------------
# Script ultra-pro para setear entorno local con detección/descarga automática de Maven y plantilla para Java.
# By Estirp3 
# https://github.com/Estirp3
# -----------------------------------------------

# Función para manejo de errores
handle_error() {
    local error_msg="$1"
    echo "❌ Error: $error_msg"
    exit 1
}

# Función para verificar espacio disponible
check_disk_space() {
    local required_space=500 # MB
    local available_space=$(df -m "$HOME/Downloads" | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        handle_error "Espacio insuficiente en $HOME/Downloads. Se requieren ${required_space}MB, hay ${available_space}MB disponibles."
    fi
}

# Función para hacer backup de configuración
backup_config() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup" || handle_error "No se pudo crear backup de $file"
        echo "✅ Backup creado: $backup"
    fi
}

# 1. Detecta shell usuario
if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "/bin/bash" ]; then
  if [ -f "$HOME/.bash_profile" ]; then
    SHELL_RC="$HOME/.bash_profile"
  else
    SHELL_RC="$HOME/.bashrc"
  fi
else
  echo "❌ No detecté bash ni zsh. Si usas otro shell, agrega las variables manualmente."
  exit 1
fi

echo "👉 Usando archivo de configuración: $SHELL_RC"

# Cargar configuración personalizada
config_file=".env"
if [ -f "$config_file" ]; then
    source "$config_file"
fi

# 2. MAVEN
MAVEN_VERSION="${MAVEN_VERSION:-3.9.6}"
MAVEN_DIR="$HOME/Downloads/apache-maven-$MAVEN_VERSION"
MAVEN_TGZ="$HOME/Downloads/apache-maven-$MAVEN_VERSION-bin.tar.gz"
MAVEN_URL="https://dlcdn.apache.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz"
MAVEN_CHECKSUM_URL="https://downloads.apache.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz.sha512"

if command -v mvn >/dev/null 2>&1; then
  echo "✔️ Maven ya está instalado: $(mvn -v | head -n 1)"
  M2_HOME=$(dirname $(dirname $(command -v mvn)))
elif [ -d "$MAVEN_DIR" ]; then
  echo "✔️ Carpeta Maven ya existe en $MAVEN_DIR"
  M2_HOME="$MAVEN_DIR"
elif [ -f "$MAVEN_TGZ" ]; then
  echo "💾 Archivo $MAVEN_TGZ ya descargado, descomprimiendo..."
  tar -xzf "$MAVEN_TGZ" -C "$HOME/Downloads"
  M2_HOME="$MAVEN_DIR"
  echo "✅ Maven descomprimido en $MAVEN_DIR"
else
  echo "⬇️  Descargando Maven $MAVEN_VERSION..."
  # Verificar espacio disponible
  check_disk_space
  
  # Descargar con verificación SSL
  curl -L --proto '=https' --tlsv1.2 -o "$MAVEN_TGZ" "$MAVEN_URL" || handle_error "Fallo en la descarga de Maven"
  
  # Verificar checksum
  expected_checksum=$(curl -L --proto '=https' --tlsv1.2 "$MAVEN_CHECKSUM_URL" | cut -d' ' -f1)
  actual_checksum=$(shasum -a 512 "$MAVEN_TGZ" | cut -d' ' -f1)
  
  if [ "$expected_checksum" != "$actual_checksum" ]; then
      rm -f "$MAVEN_TGZ"
      handle_error "Verificación de checksum fallida para Maven"
  fi
  
  tar -xzf "$MAVEN_TGZ" -C "$HOME/Downloads" || handle_error "Error al descomprimir Maven"
  chmod -R 755 "$MAVEN_DIR"
  M2_HOME="$MAVEN_DIR"
  echo "✅ Maven descargado y descomprimido en $MAVEN_DIR"
fi

PATH_MAVEN='export PATH="$PATH:$M2_HOME/bin"'

# 3. JAVA
# Puedes dejarlo así si ya tienes Java instalado, o adaptarlo para descarga automática.
JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-11.jdk/Contents/Home"
if [ -x "$JAVA_HOME/bin/java" ]; then
  echo "✔️ Java encontrado en $JAVA_HOME"
else
  if command -v java >/dev/null 2>&1; then
    echo "✔️ Java ya está instalado: $(java -version 2>&1 | head -n 1)"
    JAVA_HOME="$(dirname $(dirname $(readlink $(command -v java))))"
  else
    echo "❗ No se encontró Java instalado ni en $JAVA_HOME"
    echo "   Descarga manual de JDK requerida (por ahora, descarga automática no implementada)"
    # Aquí podrías automatizar la descarga con curl/wget según la versión y origen (Adoptium, Oracle, etc)
  fi
fi

# 4. ANDROID_HOME
ANDROID_HOME="$HOME/Library/Android/sdk"
PATH_ANDROID='export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"'

# 5. Función para setear o actualizar variables en el shell del usuario
set_or_update_env_var() {
  local var="$1"
  local value="$2"
  local rc="$3"
  
  # Validar parámetros
  if [ -z "$var" ] || [ -z "$value" ] || [ -z "$rc" ]; then
    handle_error "Parámetros incompletos en set_or_update_env_var"
  fi
  
  # Crear backup antes de modificar
  backup_config "$rc"
  
  if grep -q "^export $var=" "$rc"; then
    current_value=$(grep "^export $var=" "$rc" | sed -e "s/^export $var=//" -e 's/^"//' -e 's/"$//')
    if [ "$current_value" != "$value" ]; then
      echo "🔄 Corrigiendo $var (antes: $current_value, ahora: $value)"
      sed -i '' "s|^export $var=.*|export $var=\"$value\"|" "$rc" || handle_error "Error al actualizar $var en $rc"
    else
      echo "✔ $var ya estaba bien (no se modifica)"
    fi
  else
    echo "➕ Agregando $var con valor: $value"
    echo "export $var=\"$value\"" >> "$rc" || handle_error "Error al agregar $var a $rc"
  fi
}

set_or_update_env_var "JAVA_HOME" "$JAVA_HOME" "$SHELL_RC"
set_or_update_env_var "ANDROID_HOME" "$ANDROID_HOME" "$SHELL_RC"
set_or_update_env_var "M2_HOME" "$M2_HOME" "$SHELL_RC"

if ! grep -Fq "$PATH_ANDROID" "$SHELL_RC"; then
  echo "➕ Agregando PATH extra para Android SDK"
  echo "$PATH_ANDROID" >> "$SHELL_RC"
else
  echo "✔ PATH para Android SDK ya está bien"
fi

if ! grep -Fq "$PATH_MAVEN" "$SHELL_RC"; then
  echo "➕ Agregando PATH para Maven"
  echo "$PATH_MAVEN" >> "$SHELL_RC"
else
  echo "✔ PATH para Maven ya está bien"
fi

# 6. Mostrar todo al usuario
echo ""
echo "🔍 Valores seteados:"
echo "JAVA_HOME: $JAVA_HOME"
echo "ANDROID_HOME: $ANDROID_HOME"
echo "M2_HOME: $M2_HOME"
echo "PATH extra Android: $PATH_ANDROID"
echo "PATH extra Maven: $PATH_MAVEN"
echo ""
echo "✅ ¡Listo! Variables de entorno configuradas."
echo "ℹ️  Ejecuta: source $SHELL_RC"
echo "🔄 O abre una nueva terminal."
echo ""
echo "By Chapti 😎"
