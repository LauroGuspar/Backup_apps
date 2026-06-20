# 📦 Asistente de Respaldo y Restauración Portátil Multi-SO

Este conjunto de scripts interactivos en Bash y Python Curses permite realizar respaldos limpios y restaurar de forma selectiva software y configuraciones. Está diseñado para soportar múltiples familias de sistemas operativos:
* **Familia Arch Linux** (incluyendo CachyOS, EndeavourOS, Manjaro, etc.).
* **Familia Debian** (incluyendo Ubuntu, Linux Mint, Pop!_OS, Zorin OS, etc.).

Realiza respaldos ligeros y portátiles excluyendo de forma inteligente cachés y archivos temporales redundantes de la carpeta de configuración de usuario (`~/.config`).

El asistente de restauración cuenta con una interfaz visual unificada en terminal (TUI) con estética cyberpunk (Dark-Cyan), libre de emojis e interactiva en tiempo real.

---

## ✨ Características

* **Detección Automática de S.O.**: Detecta automáticamente si el sistema operativo de origen o de destino pertenece a la familia Arch o Debian mediante la presencia de `pacman` o `apt-get`.
* **Portabilidad Inteligente**: Al realizar un respaldo, los scripts se auto-copian al directorio de destino seleccionado, garantizando que tengas el instalador completo en tu unidad USB o almacenamiento en la nube.
* **Componentes de Respaldo según el Sistema**:
  * **En Arch Linux / CachyOS**:
    * Paquetes oficiales (`pacman`) excluyendo automáticamente kernels, base-devel y paquetes del sistema.
    * Paquetes comunitarios (`AUR`).
    * Aplicaciones `Flatpak`.
    * Configuraciones de usuario (`~/.config`).
  * **En Debian / Ubuntu / Linux Mint**:
    * Paquetes oficiales instalados manualmente (`APT`).
    * Repositorios de terceros (`PPAs`) y llaves GPG de confianza (`/etc/apt/sources.list.d/` y `trusted.gpg.d/`).
    * Paquetes de software autocontenidos (`Snaps`).
    * Configuraciones de entorno de escritorio e interfaz gráfica mediante base de datos de configuraciones (`dconf`).
    * Aplicaciones `Flatpak`.
    * Configuraciones de usuario (`~/.config`).
* **TUI Monopágina Interactiva**: Olvídate de menús engorrosos. El asistente de restauración (`restore_tui.py`) inicia una interfaz única:
  * **Filtro en tiempo real**: Escribe caracteres en cualquier momento para filtrar las listas de paquetes al instante.
  * **Atajos de teclado rápidos**: `Ctrl+A` para marcar todos los visibles, `Ctrl+X` para desmarcar visibles, `ENTER` para aceptar e iniciar, y `ESC` o `Ctrl+C` para cancelar.
* **Respaldo de Prevención**: Antes de sobreescribir tu carpeta `~/.config`, el asistente realiza una copia de seguridad local (`~/.config.bak_fecha_hora`) de tus dotfiles originales en el sistema nuevo para evitar pérdidas accidentales.
* **Registro de Errores Detallado**: Si algún paquete o compilación falla durante la reinstalación, los logs se guardan al final del proceso en `restore_error.log` para su posterior revisión.

---

## 📂 Estructura del Proyecto

```text
├── backup_apps.sh      # Script Bash interactivo para realizar el respaldo.
├── restore_apps.sh     # Script Bash de ejecución que inicia el proceso de restauración.
├── restore_tui.py      # Interfaz de usuario interactiva (Python Curses TUI) para restaurar.
├── README.md           # Guía de uso y descripción general unificada (este archivo).
├── .gitignore          # Archivo de exclusiones para Git (evita subir dotfiles privados).
└── LICENSE             # Licencia de MIT.
```

---

## 🛠️ Requisitos de Ejecución

* **Sistemas Operativos Soportados**: 
  * Arch Linux, CachyOS, EndeavourOS, Manjaro o derivados.
  * Debian, Ubuntu, Linux Mint, Pop!_OS, Zorin OS o derivados.
* **Intérprete y Dependencias**:
  * Python 3.x.
  * **Para sistemas Debian/Ubuntu minimalistas**: Puede requerirse instalar el soporte de curses para Python manualmente:
    ```bash
    sudo apt update && sudo apt install python3-curses
    ```
  * Utilidades del sistema comunes: `tar`, `gzip`, `dconf-cli` (para entornos de escritorio en Debian), `snapd` (opcional), `flatpak` (opcional).

---

## 🚀 Guía de Uso Paso a Paso

### Paso 1: Realizar el respaldo (En el sistema actual)

1. Abre tu terminal en la carpeta donde tienes los scripts y ejecuta:
   ```bash
   ./backup_apps.sh
   ```
2. **Selecciona el destino del respaldo**:
   * **Opción 1**: Carpeta predeterminada (`~/Backup`).
   * **Opción 2**: En la misma carpeta del script (útil si lo ejecutas directamente desde tu unidad USB).
   * **Opción 3**: Una ruta personalizada de tu preferencia.
3. El script detectará tu sistema y guardará la información en una carpeta llamada `respaldo_cachyos`.
4. **Copia de seguridad del instalador**: Al finalizar, los scripts de restauración (`restore_apps.sh` y `restore_tui.py`) se copiarán automáticamente junto a la carpeta de respaldos en el destino que elegiste. Así, solo tendrás que llevarte esa carpeta final a tu USB.

### Paso 2: Restaurar (En el sistema nuevo)

1. Copia la carpeta del respaldo a tu nuevo sistema operativo, o colócate directamente en tu unidad externa.
2. Abre la terminal en el directorio del respaldo y ejecuta:
   ```bash
   ./restore_apps.sh
   ```
3. El asistente TUI se abrirá de inmediato. Ajusta tus selecciones (APT/Pacman, Snaps/AUR, Flatpaks, y restauración de `.config`/dconf) y selecciona **ACEPTAR** o pulsa `ENTER` para iniciar el proceso de instalación y restauración.

---

## ⌨️ Atajos y Uso de la Interfaz TUI (Python Curses)

La interfaz TUI se ejecuta completamente en la terminal con una estética oscura (Dark-Cyan) sin emojis ni distracciones.

```text
================================================================================
  ASISTENTE DE RESTAURACIÓN MULTI-SO  (Debian -> Debian)
================================================================================
  [X] Paquetes Oficiales (APT) (125 seleccionados)
  [X] Aplicaciones Snap (12 seleccionadas)
  [ ] Aplicaciones Flatpak (0 seleccionadas)
  [X] Restaurar dotfiles de usuario (~/.config)
  [X] Restaurar configuraciones de escritorio (dconf)
  
  Escriba para buscar: ________________
================================================================================
  Atajos: Ctrl+A (Marcar Todo) | Ctrl+X (Deseleccionar Todo) | ESC (Cancelar)
  Use [Flechas] para navegar | [Espacio] para alternar | [ENTER] para Aceptar
================================================================================
```

### Controles de Navegación:
* **Flecha Arriba / Flecha Abajo**: Mueve el cursor de selección entre las diferentes categorías del menú.
* **Barra Espaciadora**: Activa/Desactiva (Check/Uncheck) la categoría bajo el cursor.
* **Escribir directamente**: Si presionas cualquier tecla alfanumérica, se filtrará automáticamente la lista de categorías visibles. Por ejemplo, al escribir "Flat" se mostrará únicamente la opción de Flatpaks.
* **Retroceso (Backspace)**: Borra caracteres de la barra de búsqueda en tiempo real.
* **Ctrl+A**: Marca/Selecciona todas las categorías que estén visibles en pantalla en ese momento.
* **Ctrl+X**: Desmarca/Deselecciona todas las categorías que estén visibles en pantalla en ese momento.
* **ENTER**: Confirma las selecciones actuales e inicia el proceso de instalación y restauración.
* **ESC** o **Ctrl+C**: Aborta la herramienta de restauración de forma segura sin realizar cambios.

---

## 🛠️ Detalle del Proceso de Instalación

Una vez confirmada la selección en la interfaz TUI, se ejecutará el script `restore_apps.sh`, el cual realizará lo siguiente de forma secuencial:

1. **Restaurar repositorios (Debian/Ubuntu)**: Descomprime PPAs y llaves GPG de confianza, y ejecuta `sudo apt-get update` para habilitar la descarga de tus aplicaciones no oficiales.
2. **Actualizar el sistema**: Actualiza el sistema para garantizar la compatibilidad de librerías.
3. **Instalación de paquetes del sistema**: Instala los paquetes oficiales (APT o Pacman) en bloque.
4. **Instalación de paquetes adicionales**: Instala las aplicaciones de AUR (vía `yay`/`paru`) o Snaps (con fallas controladas mediante parámetros clásicos/normales).
5. **Instalación de Flatpaks**: Descarga e instala los Flatpaks seleccionados.
6. **Restauración de dotfiles (`~/.config`)**:
   * **Prevención de pérdida**: Si ya existe una carpeta `~/.config` en el nuevo sistema, el script la respaldará automáticamente renombrándola como `~/.config.bak_AAAA-MM-DD_HHMMSS`.
   * Descomprime el archivo `dotfiles_config.tar.gz` en tu directorio `$HOME`.
7. **Cargar ajustes de entorno (Debian/dconf)**: Carga los ajustes de temas, accesos directos y configuraciones gráficas respaldadas a través de dconf.

---

## ⚠️ Consejos y Solución de Problemas

* **Errores de dependencias o compilación**: Si algún paquete falla al compilar en AUR o no existe en la base de datos de repositorios del nuevo sistema, el script no se detendrá; continuará con los demás y registrará el error. Al finalizar, revisa el archivo de registro `restore_error.log` creado en la misma carpeta para saber qué falló.
* **Entornos de escritorio híbridos**: Si respaldas la configuración de Cinnamon de Linux Mint e intentas restaurarla en un Ubuntu con GNOME puro, los archivos de configuración (`~/.config`) se restaurarán con éxito, pero los ajustes dconf podrían no surtir efecto completo si las extensiones o paneles correspondientes no están instalados.

---

## 🔒 Seguridad y Privacidad (.gitignore)

> [!WARNING]
> La carpeta de salida del respaldo (`respaldo_cachyos/`) contiene archivos sensibles como el archivo comprimido `dotfiles_config.tar.gz`. Este almacena configuraciones de tu carpeta `~/.config` que **pueden incluir claves de API, tokens de sesión de navegadores, configuraciones de mensajería y llaves de acceso SSH privadas**.
> 
> El archivo `.gitignore` incluido en este repositorio está configurado específicamente para **excluir e ignorar** la carpeta `respaldo_cachyos/` de cualquier seguimiento de Git. **No elimines esta regla para evitar publicar tus datos personales y credenciales de seguridad en repositorios públicos de GitHub.**

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo `LICENSE` para más detalles.