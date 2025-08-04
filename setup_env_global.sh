#!/bin/bash

# Variables a configurar
JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-11.jdk/Contents/Home"
ANDROID_HOME="\$HOME/Library/Android/sdk"
PATH_LINE='export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"'
PROFILE_D_FILE="/etc/profile.d/custom_env.sh"

echo "👉 Configurando variables GLOBALES en $PROFILE_D_FILE"

# Función para agregar o actualizar variables
add_or_update_global_var() {
  local var="$1"
  local value="$2"
  local file="$3"
  if grep -q "export $var=" "$file" 2>/dev/null; then
    # Actualizar valor si es diferente
    sudo sed -i '' "s|export $var=.*|export $var=\"$value\"|" "$file"
    echo "🔄 Actualizado $var en $file"
  else
    echo "export $var=\"$value\"" | sudo tee -a "$file" > /dev/null
    echo "➕ Agregado $var a $file"
  fi
}

# Crea el archivo si no existe
if [ ! -f "$PROFILE_D_FILE" ]; then
  sudo touch "$PROFILE_D_FILE"
  sudo chmod 644 "$PROFILE_D_FILE"
fi

# Agregar o actualizar variables
add_or_update_global_var "JAVA_HOME" "$JAVA_HOME" "$PROFILE_D_FILE"
add_or_update_global_var "ANDROID_HOME" "$ANDROID_HOME" "$PROFILE_D_FILE"

# PATH extra (agrega solo si no existe la línea exacta)
if ! grep -Fq "$PATH_LINE" "$PROFILE_D_FILE"; then
  echo "$PATH_LINE" | sudo tee -a "$PROFILE_D_FILE" > /dev/null
  echo "➕ Agregado PATH extra a $PROFILE_D_FILE"
else
  echo "✔ PATH extra ya estaba bien"
fi

echo ""
echo "✅ Variables GLOBALES configuradas."
echo "🔄 Cierra y abre terminal para aplicar los cambios a todos los usuarios."
echo ""
echo "By Chapti 😎"
