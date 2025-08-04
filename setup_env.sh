#!/bin/bash

# -----------------------------------------------
# Script para setear variables de entorno en Mac
# Detecta si usas bash o zsh, y si tu Mac es Intel o Apple Silicon (M1, M2, M3, M4)
# Actualiza solo si hace falta y te avisa con mensajes claros
# By Chapti 🤖
# -----------------------------------------------

# Se debe dar peromisos cn el cmando chmod +x setup_env.sh

# 1. Detecta tu shell (zsh o bash) y el archivo de configuración a usar
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

# 2. Averigua si tu Mac es Intel o Apple Silicon (y qué versión de chip tienes)
CPU_BRAND=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
ARCH=$(uname -m)
APPLE_CHIP=""

if [[ "$ARCH" == "arm64" ]]; then
  # Para Macs Apple Silicon
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
  echo "🍏 Tienes un Mac con chip $APPLE_CHIP"
else
  APPLE_CHIP="Intel"
  echo "💻 Tienes un Mac Intel"
fi

# 3. Variables que vamos a setear
JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-11.jdk/Contents/Home"
ANDROID_HOME="$HOME/Library/Android/sdk"
PATH_LINE='export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"'

# 4. Función para agregar o actualizar variables de entorno en el archivo de configuración
set_or_update_env_var() {
  local var="$1"
  local value="$2"
  local rc="$3"

  # ¿La variable ya existe en el archivo?
  if grep -q "^export $var=" "$rc"; then
    # Compara el valor actual con el deseado
    current_value=$(grep "^export $var=" "$rc" | sed -e "s/^export $var=//" -e 's/^"//' -e 's/"$//')
    if [ "$current_value" != "$value" ]; then
      echo "🔄 Corrigiendo $var (antes: $current_value, ahora: $value)"
      # Actualiza la línea
      sed -i '' "s|^export $var=.*|export $var=\"$value\"|" "$rc"
    else
      echo "✔ $var ya estaba bien (no se modifica)"
    fi
  else
    echo "➕ Agregando $var con valor: $value"
    echo "export $var=\"$value\"" >> "$rc"
  fi
}

# 5. Setea JAVA_HOME y ANDROID_HOME de forma idempotente
set_or_update_env_var "JAVA_HOME" "$JAVA_HOME" "$SHELL_RC"
set_or_update_env_var "ANDROID_HOME" "$ANDROID_HOME" "$SHELL_RC"

# 6. Agrega la línea de PATH si no existe exactamente igual
if ! grep -Fq "$PATH_LINE" "$SHELL_RC"; then
  echo "➕ Agregando PATH extra para Android SDK"
  echo "$PATH_LINE" >> "$SHELL_RC"
else
  echo "✔ PATH para Android SDK ya está bien"
fi

echo ""
echo "✅ ¡Listo! Variables de entorno configuradas para tu Mac $APPLE_CHIP."
echo "ℹ️  Recuerda: Para aplicar los cambios ejecuta 👉 source $SHELL_RC"
echo "🔄 O simplemente abre una nueva terminal."
echo ""
echo "By Chapti 😎"
