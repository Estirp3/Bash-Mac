[![Maven Central](https://img.shields.io/maven-central/v/io.github.bonigarcia/webdrivermanager.svg)](http://search.maven.org/#search%7Cga%7C1%7Cg%3Aio.github.bonigarcia%20a%3Awebdrivermanager)
👨‍💻 Autor
Estirp3 
[![github](https://img.shields.io/badge/Git__estirp3-GitHub-blue)](https://github.com/Estirp3)

# Scripts de Configuración de Entorno para Mac

Este repositorio contiene un script de shell que configura automáticamente 
variables de entorno en sistemas macOS (Intel y Apple Silicon), 
especialmente útil para desarrollo con **Java**, **Android SDK** y **Maven**.

---

## 🚀 Script Disponible

### `setup_env.sh`

Script unificado que permite configuración **local (usuario)** o **global (todos los usuarios)**, además de elegir la versión de Java.

### Funcionalidades principales

- **Instalación de Java (Temurin vía Homebrew)**:
  - Detecta si ya existe
  - Instala la versión indicada (por defecto Java 17)
  - Configura correctamente `JAVA_HOME`

- **Instalación de Maven**:
  - Verifica si ya está instalado
  - Instala vía Homebrew si falta
  - Configura `M2_HOME` apuntando a `brew libexec`

- **Configuración de Android SDK**:
  - Ajusta `ANDROID_HOME`
  - Agrega binarios de emulator, tools y platform-tools al PATH

- **Configuración de entorno**:
  - `--user` → modifica `~/.zprofile` y asegura carga desde `~/.zshrc`
  - `--global` → crea `/etc/profile.d/custom_env.sh` y ajusta `/etc/zprofile` para que cargue automáticamente
  - En ambos casos añade `PATH` para Maven y Android SDK
  - Limpia variables previas duplicadas o vacías

- **Detección de arquitectura**:
  - Detecta Intel o Apple Silicon (M1, M2, M3, M4)

- **Mensajes claros con emojis** para seguimiento.

---

## ⚡ Uso

### Dar permisos
```bash
chmod +x setup_env.sh
```
### Configuración por usuario (recomendado si solo lo usas tú)
```bash
./setup_env.sh --user
```

### Configuración por usuario (recomendado si solo lo usas tú)
```bash
./setup_env.sh --global
```
### Especificar versión de Java (ejemplo: instalar Java 21)
```bash
./setup_env.sh --user --java 21
```

### ✅ Ejemplos de salida
```bash
./setup_env.sh --global --java 17

🍎 macOS detectado - Chip: Apple M3
🔧 Java solicitado: Temurin 17
➡️  Instalando Java (temurin@17)…
➡️  Instalando Maven…
🔍 Detectado:
JAVA_HOME = /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
M2_HOME   = /opt/homebrew/Cellar/maven/3.9.6/libexec

✅ Global listo. Recarga: source /etc/profile.d/custom_env.sh

Verificación (puede requerir nueva sesión):
  echo $JAVA_HOME
  java -version
  mvn -v

```
### 📋 Requisitos
```bash
macOS (Intel o Apple Silicon)

Homebrew
 (se instala automáticamente si no existe)

Conexión a Internet

Para --global, permisos de administrador (el script pedirá sudo solo al escribir en /etc)
```
