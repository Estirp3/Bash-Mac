# Scripts de Configuración de Entorno para Mac

Este repositorio contiene scripts de shell para configurar automáticamente variables de entorno en sistemas macOS, especialmente útiles para desarrollo con Java, Android y Maven.

## Scripts Disponibles

### 1. setup_env.sh

Script para configuración local (por usuario) que:

- Detecta automáticamente el shell del usuario (bash/zsh)
- Configura Maven 3.9.6:
  - Detecta si está instalado
  - Descarga y descomprime si no existe
  - Configura M2_HOME y PATH
- Verifica la instalación de Java
- Configura ANDROID_HOME y sus PATHs
- Actualiza el archivo de configuración del shell (.zshrc/.bashrc/.bash_profile)

### 2. setup_env_global.sh

Script para configuración global (todos los usuarios) que:

- Requiere permisos sudo
- Instala Maven 3.9.6 globalmente en /opt
- Configura variables de entorno globales en /etc/profile.d/
- Gestiona:
  - JAVA_HOME
  - ANDROID_HOME
  - M2_HOME
  - PATHs para Android SDK y Maven

## Uso

### Permisos y Ejecución
```bash
chmod +x setup_env.sh 
./setup_env.sh
sudo ./setup_env_global.sh
```

### Verificación de Variables
```bash
echo $JAVA_HOME
echo $ANDROID_HOME
```

## Requisitos

- Sistema operativo macOS
- Conexión a Internet (para descarga de Maven si es necesario)
- Permisos de administrador (para configuración global)

## Notas

- Los scripts detectan instalaciones existentes para evitar duplicados
- Incluyen mensajes informativos con emojis para mejor seguimiento
- Mantienen respaldo de configuraciones existentes
- Preparados para futura automatización de instalación de Java

## Autor

[Estirp3](https://github.com/Estirp3)
