#!/bin/bash
# ------------------------------------------------------
# Instala Java Temurin (versión elegida) + Maven (Homebrew)
# Configura JAVA_HOME / M2_HOME / PATH
# Flags: --user | --global  (+ opcional --java N; default 17)
# IMPORTANTE: ejecutar SIN sudo (brew no corre como root).
# By Estirp3 (Chapti)
# ------------------------------------------------------
set -euo pipefail

# --------- Args ---------
TARGET="user"          # user|global
JAVA_REQ_VERSION="17"  # default
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)   TARGET="user"; shift ;;
    --global) TARGET="global"; shift ;;
    --java)   JAVA_REQ_VERSION="${2:-}"; [[ -n "$JAVA_REQ_VERSION" ]] || { echo "Falta valor para --java"; exit 1; }; shift 2 ;;
    [0-9]|1[0-9]|2[0-9]) JAVA_REQ_VERSION="$1"; shift ;;  # soporte posicional "21"
    *) echo "Uso: $0 [--user|--global] [--java N]"; exit 1 ;;
  esac
done

# --------- Const ---------
PROFILE_D_DIR="/etc/profile.d"
PROFILE_D_FILE="$PROFILE_D_DIR/custom_env.sh"
USER_ZPROFILE="$HOME/.zprofile"
PATH_MAVEN_EXPORT='export PATH="$PATH:$M2_HOME/bin"'
BREW_USER="${SUDO_USER:-$USER}"

# --------- Utils ---------
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_mingw() { uname -s | grep -qiE 'mingw|msys|cygwin'; }
arch()     { uname -m; }
info()     { echo "➡️  $*"; }
warn()     { echo "⚠️  $*" >&2; }
die()      { echo "❌ $*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

as_brew_user() {
  # Ejecuta comandos como usuario normal (nunca root)
  if [[ "$USER" == "$BREW_USER" ]]; then
    /bin/bash -lc "$*"
  else
    sudo -u "$BREW_USER" /bin/bash -lc "$*"
  fi
}

require_sudo() {
  # Pide credenciales sudo si no están cacheadas (solo cuando hace falta)
  if ! sudo -n true 2>/dev/null; then
    info "Se requieren privilegios para escribir en /etc…"
    sudo -v
  fi
}

ensure_zsh_loads_profiled() {
  require_sudo
  local line='[[ -f /etc/profile.d/custom_env.sh ]] && source /etc/profile.d/custom_env.sh'
  for f in /etc/zprofile /etc/zshrc; do
    if sudo test -f "$f"; then
      sudo grep -Fq "$line" "$f" 2>/dev/null || echo "$line" | sudo tee -a "$f" >/dev/null
    else
      echo "$line" | sudo tee -a "$f" >/dev/null
    fi
  done
}

cleanup_env_lines() {
  # Limpia definiciones previas de JAVA_HOME/M2_HOME/PATH mvn (global y usuario)
  local files=("$PROFILE_D_FILE" /etc/zprofile /etc/zshrc "$HOME/.zprofile" "$HOME/.zshrc")
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    if [[ "$f" == "$PROFILE_D_FILE" || "$f" == /etc/* ]]; then
      require_sudo
      sudo sed -i '' '/export[[:space:]]\+JAVA_HOME=/d' "$f" 2>/dev/null || true
      sudo sed -i '' '/export[[:space:]]\+M2_HOME=/d'   "$f" 2>/dev/null || true
      sudo sed -i '' '\|export PATH="$PATH:$M2_HOME/bin"|d' "$f" 2>/dev/null || true
    else
      sed -i '' '/export[[:space:]]\+JAVA_HOME=/d' "$f" 2>/dev/null || true
      sed -i '' '/export[[:space:]]\+M2_HOME=/d'   "$f" 2>/dev/null || true
      sed -i '' '\|export PATH="$PATH:$M2_HOME/bin"|d' "$f" 2>/dev/null || true
    fi
  done
}

append_or_replace_export_line_global() {
  require_sudo
  local var="$1" val="$2" file="$3"
  sudo mkdir -p "$(dirname "$file")"
  if ! sudo test -f "$file"; then
    echo "# Global env (Chapti)" | sudo tee "$file" >/dev/null
    sudo chmod 644 "$file"
  fi
  if sudo grep -qE "^[[:space:]]*export[[:space:]]+$var=" "$file" 2>/dev/null; then
    sudo sed -i '' "s|^[[:space:]]*export[[:space:]]\+$var=.*|export $var=\"$val\"|" "$file"
  else
    echo "export $var=\"$val\"" | sudo tee -a "$file" >/dev/null
  fi
}

append_or_replace_export_line_user() {
  local var="$1" val="$2" file="$3"
  touch "$file"
  if grep -qE "^[[:space:]]*export[[:space:]]+$var=" "$file" 2>/dev/null; then
    sed -i '' "s|^[[:space:]]*export[[:space:]]\+$var=.*|export $var=\"$val\"|" "$file"
  else
    echo "export $var=\"$val\"" >> "$file"
  fi
}

write_env_global() {
  local java_home="$1" m2_home="$2"
  append_or_replace_export_line_global "JAVA_HOME" "$java_home" "$PROFILE_D_FILE"
  append_or_replace_export_line_global "M2_HOME"   "$m2_home"  "$PROFILE_D_FILE"
  if ! sudo grep -Fq "$PATH_MAVEN_EXPORT" "$PROFILE_D_FILE"; then
    echo "$PATH_MAVEN_EXPORT" | sudo tee -a "$PROFILE_D_FILE" >/dev/null
  fi
  ensure_zsh_loads_profiled
  # Añadir mvn al PATH del sistema (best-effort)
  echo "$m2_home/bin" | sudo tee /etc/paths.d/maven >/dev/null || true
}

write_env_user() {
  local java_home="$1" m2_home="$2"
  local zpf="$USER_ZPROFILE"
  local zrc="$HOME/.zshrc"
  touch "$zpf" "$zrc"
  append_or_replace_export_line_user "JAVA_HOME" "$java_home" "$zpf"
  append_or_replace_export_line_user "M2_HOME"   "$m2_home"  "$zpf"
  grep -Fq "$PATH_MAVEN_EXPORT" "$zpf" 2>/dev/null || echo "$PATH_MAVEN_EXPORT" >> "$zpf"
  grep -Fq 'source ~/.zprofile' "$zrc" 2>/dev/null || echo '[[ -f ~/.zprofile ]] && source ~/.zprofile' >> "$zrc"
}

resolve_java_home_macos() {
  /usr/libexec/java_home -v "$JAVA_REQ_VERSION" 2>/dev/null || /usr/libexec/java_home 2>/dev/null || true
}

# --------- macOS flow ---------
macos_install_all() {
  # Homebrew (si no está, instalar como usuario normal)
  if ! as_brew_user "command -v brew >/dev/null 2>&1"; then
    info "Instalando Homebrew (como $BREW_USER)…"
    as_brew_user 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
    if [[ -x /usr/local/bin/brew ]];  then eval "$(/usr/local/bin/brew shellenv)";  fi
  else
    as_brew_user "brew update" || true
  fi

  # Java Temurin (cask name fix: temurin@N o temurin fallback)
  local cask="temurin@${JAVA_REQ_VERSION}"
  if ! as_brew_user "brew info --cask $cask >/dev/null 2>&1"; then
    cask="temurin"
  fi
  info "Instalando Java ($cask)…"
  as_brew_user "brew list --cask $cask >/dev/null 2>&1 || brew install --cask $cask"

  # Resolver JAVA_HOME
  local JAVA_HOME_VAL
  JAVA_HOME_VAL="$(resolve_java_home_macos)"
  [[ -n "${JAVA_HOME_VAL:-}" && -x "$JAVA_HOME_VAL/bin/java" ]] || die "No pude resolver JAVA_HOME tras instalar $cask."

  # Maven
  info "Instalando Maven…"
  as_brew_user "brew list maven >/dev/null 2>&1 || brew install maven"

  # M2_HOME (brew libexec)
  local M2_HOME M_PREFIX MVN_PATH
  M_PREFIX="$(as_brew_user "brew --prefix maven" | tr -d '\r')"
  if [[ -n "$M_PREFIX" && -d "$M_PREFIX/libexec" ]]; then
    M2_HOME="$M_PREFIX/libexec"
  else
    MVN_PATH="$(as_brew_user "command -v mvn" || true)"
    [[ -n "$MVN_PATH" ]] || die "No pude encontrar mvn."
    M2_HOME="$(as_brew_user "cd \"\$(dirname \"$MVN_PATH\")\" && cd .. && pwd")/libexec"
  fi

  echo
  echo "🔍 Detectado:"
  echo "JAVA_HOME = $JAVA_HOME_VAL"
  echo "M2_HOME   = $M2_HOME"
  echo

  # Limpiar y escribir según target
  cleanup_env_lines
  if [[ "$TARGET" == "global" ]]; then
    write_env_global "$JAVA_HOME_VAL" "$M2_HOME"
    echo "✅ Global listo. Recarga: source /etc/profile.d/custom_env.sh"
  else
    write_env_user "$JAVA_HOME_VAL" "$M2_HOME"
    echo "✅ Usuario listo. Recarga: source ~/.zprofile"
  fi

  echo
  echo "Verificación (puede requerir nueva sesión):"
  echo "  echo \$JAVA_HOME"
  echo "  java -version"
  echo "  mvn -v"
}

# --------- Windows guía ---------
windows_guide() {
  echo "🪟 Windows (Git-Bash/MSYS/Cygwin). Ejecuta en PowerShell (Admin):"
  echo "  choco install temurin@${JAVA_REQ_VERSION} maven -y   (o 'temurin' si no hay @N)"
  echo '  setx JAVA_HOME "C:\Program Files\Eclipse Adoptium\jdk-<ver>\\" /M'
  echo '  setx M2_HOME "C:\ProgramData\chocolatey\lib\maven\tools\apache-maven-<ver>\\" /M'
  echo '  setx PATH "%PATH%;%M2_HOME%\bin" /M'
}

# --------- Entrypoint ---------
main() {
  if is_macos; then
    # Info chip
    local CHIP="Intel"
    if [[ "$(arch)" == "arm64" ]]; then
      local brand; brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "")
      if   echo "$brand" | grep -q "M1"; then CHIP="Apple M1"
      elif echo "$brand" | grep -q "M2"; then CHIP="Apple M2"
      elif echo "$brand" | grep -q "M3"; then CHIP="Apple M3"
      elif echo "$brand" | grep -q "M4"; then CHIP="Apple M4"
      else CHIP="Apple Silicon (arm64)"
      fi
    fi
    echo "🍎 macOS detectado - Chip: $CHIP"
    echo "🔧 Java solicitado: Temurin $JAVA_REQ_VERSION"
    macos_install_all
  elif is_mingw; then
    windows_guide
  else
    die "SO no soportado. Solo macOS y Windows (Git-Bash/MSYS/Cygwin)."
  fi
  echo
  echo "By Estirp3 😎"
}

main "$@"
