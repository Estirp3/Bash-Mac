# Changelog

Todas las modificaciones importantes de este proyecto se documentarán aquí.  
El formato sigue las recomendaciones de [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

## [Unreleased]

- Pendiente: soporte para Linux (Debian/Ubuntu) además de macOS y Windows.
- Pendiente: opción para desinstalar o limpiar configuraciones.

---

## [1.0.0] - 2025-09-24

### 🚀 Added
- Script **unificado** `setup_env.sh` para configuración de entorno en macOS (Intel/Apple Silicon) y guía para Windows (Git-Bash/MSYS).
- Flags de ejecución:
  - `--user` → configura entorno solo para el usuario actual (`~/.zprofile`).
  - `--global` → configura entorno global para todos los usuarios (`/etc/profile.d/custom_env.sh`).
  - `--java N` → permite elegir la versión de Java Temurin a instalar (ej. `--java 17`, `--java 21`).  
- Instalación automática de:
  - **Java Temurin** (vía Homebrew en macOS o Chocolatey en Windows).
  - **Maven 3.9.6** (vía Homebrew en macOS o Chocolatey en Windows).
- Configuración automática de variables de entorno:
  - `JAVA_HOME`
  - `M2_HOME`
  - `ANDROID_HOME`
  - `PATH` extendido con `M2_HOME/bin` y Android SDK.
- Detección automática de chip en macOS (Intel, M1, M2, M3, M4).
- Mensajes claros y amigables con emojis para seguimiento del proceso.
- Limpieza de definiciones previas de `JAVA_HOME` y `M2_HOME` duplicadas o vacías en archivos de perfil.

### 🔧 Changed
- Ya no existen dos scripts separados (`setup_env.sh` y `setup_env_global.sh`).  
  Ahora todo se gestiona desde **un único script** con flags.

### 🐛 Fixed
- Problema de `JAVA_HOME="/usr"` por definiciones duplicadas en `.zprofile` y `/etc/profile.d`.
- Error de Homebrew al correr como `sudo`. Ahora:
  - Homebrew siempre se ejecuta como usuario normal.
  - Solo las operaciones que requieren `/etc` piden `sudo`.

---

## [0.1.0] - 2025-09-20

### 🚀 Added
- Primeros prototipos de scripts:
  - `setup_env.sh` → configuración por usuario.
  - `setup_env_global.sh` → configuración global.
- Instalación de Maven 3.9.6 en `/opt` con descarga manual.
- Configuración básica de `JAVA_HOME`, `M2_HOME` y `ANDROID_HOME`.
