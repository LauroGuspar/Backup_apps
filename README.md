# 📦 Asistente de Respaldo y Restauración Portátil Multi-SO

Este conjunto de scripts interactivos en Bash y Python Curses permite realizar respaldos limpios y restaurar de forma selectiva software y configuraciones. Está diseñado para soportar múltiples familias de sistemas operativos:
* **Familia Arch Linux** (incluyendo CachyOS, EndeavourOS, Manjaro, etc.).
* **Familia Debian** (incluyendo Ubuntu, Linux Mint, Pop!_OS, Zorin OS, etc.).

Realiza respaldos ligeros y portátiles excluyendo de forma inteligente cachés y archivos temporales redundantes de la carpeta de configuración de usuario (`~/.config`).

El asistente de restauración cuenta con una interfaz visual unificada en terminal (TUI) con estética cyberpunk (Dark-Cyan), libre de emojis e interactiva en tiempo real.

---

## ✨ Características

* **Detección Automática de S.O.**: Detecta automáticamente si el sistema operativo de origen o de destino pertenece a la familia Arch o Debian mediante la presencia de `pacman` o `apt-get`.
* **Historial de Respaldos y Versionado Automático**: Maneja múltiples respaldos sin sobrescribir el anterior. Nombra las carpetas automáticamente con marca de tiempo (`respaldo_YYYY-MM-DD_HHMMSS`) o permite asignar una etiqueta personalizada. Genera metadatos estructurados en `backup_info.json` y mantiene un enlace simbólico relativo `respaldo_latest`.
* **Selector Interactivo de Respaldos**: Al ejecutar la restauración, si existen varios respaldos disponibles, muestra un menú interactivo con detalles (fecha, paquetes, dotfiles, appimages) para elegir exactamente cuál restaurar.
* **Clasificación y Filtrado Cíclico con [TAB] (Apps vs. Dependencias)**:
  * Separa automáticamente los programas principales de usuario de las librerías, fuentes y componentes del sistema.
  * **Por defecto**: Solo se muestran las aplicaciones principales (preseleccionadas con `[X]`).
  * **Al presionar [TAB]**: Muestra únicamente las dependencias del sistema (desmarcadas por defecto `[ ]`).
  * **Al presionar [TAB] de nuevo**: Muestra el catálogo completo, distinguiendo dependencias con la etiqueta `[Dependencia]`.
* **Detección y Respaldo Inteligente de AppImages**: Detecta ejecutables AppImage en el sistema (`~/Applications`, `~/.local/bin`, etc.) y pregunta de forma interactiva si se desean incluir en el respaldo junto con sus accesos `.desktop`. Al restaurar, verifica dependencias FUSE (`fuse2`), restaura permisos de ejecución (`chmod +x`) y actualiza el menú del sistema.
* **Respaldo Modular de Configuraciones (`~/.config`)**: Pregunta si se desea incluir la carpeta `~/.config` [S/n] para permitir respaldos más ligeros y rápidos cuando solo se requieran paquetes.
* **Portabilidad Total**: Al respaldar, los scripts se auto-copian al directorio base y dentro de la carpeta del propio respaldo para que cada copia sea autónoma y compartible.
* **TUI Monopágina Optimizada (Python Curses)**:
  * **Respuesta instantánea de [ESC]**: Descarte y retorno inmediato sin retardos de terminal.
  * **Filtro en tiempo real**: Escribe caracteres en cualquier momento para filtrar las listas al instante.
  * **Atajos de teclado**: `[TAB]` para alternar vista, `Ctrl+A` para marcar todos los visibles, `Ctrl+X` para desmarcar visibles, `[Espacio]` para alternar, `[ENTER]` para guardar y `[ESC]` para descartar y regresar.
* **Respaldo de Prevención**: Antes de sobreescribir `~/.config`, realiza una copia local de seguridad (`~/.config.bak_fecha_hora`).
* **Registro de Errores Detallado**: Los incidentes se guardan en `restore_error.log`.


---

## 📂 Estructura del Proyecto

```text
├── backup_apps.sh      # Script Bash interactivo para realizar el respaldo o lanzar el creador.
├── create_installer.sh # Creador de instaladores personalizados "Todo en 1" para compartir.
├── install_apps.sh     # Lanzador amigable de instalación para el destinatario.
├── restore_apps.sh     # Script Bash de ejecución que realiza el proceso de restauración.
├── restore_tui.py      # Interfaz de usuario interactiva (Python Curses TUI).
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
3. **Nombre y etiqueta del respaldo**:
   * El script propone un nombre automático con fecha (`respaldo_YYYY-MM-DD_HHMMSS`), o puedes escribir tu propio alias o etiqueta.
   * Se crea también un enlace simbólico relativo `respaldo_latest` que siempre apunta al respaldo más reciente.
4. **Preguntas interactivas opcionales**:
   * **Configuraciones (`~/.config`)**: Pregunta si deseas respaldar `.config` [S/n] (Predeterminado: Sí).
   * **Aplicaciones AppImage**: Si se detectan ejecutables AppImage en tu usuario, pregunta si deseas respaldarlos [s/N] (Predeterminado: No, para evitar backups pesados si no lo deseas).
5. **Copia de seguridad del instalador y metadatos**:
   * Al finalizar, se genera `backup_info.json` con los metadatos completos y se copian `restore_apps.sh` y `restore_tui.py` tanto en el directorio base como dentro de la carpeta del propio respaldo para total autonomía.

### Paso 2: Restaurar (En el sistema nuevo)

1. Lleva tu carpeta de respaldo o unidad externa a tu nueva instalación.
2. Ejecuta:
   ```bash
   ./restore_apps.sh
   ```
3. **Historial de Respaldos**:
   * Si detecta varios respaldos disponibles, `restore_apps.sh` te mostrará un menú interactivo con la fecha, cantidad de paquetes, dotfiles y AppImages de cada uno para que elijas cuál restaurar (o ingresar una ruta personalizada).
4. **Asistente Visual TUI**:
   * Se abrirá la interfaz gráfica en terminal. Por defecto, solo las **Aplicaciones principales** están seleccionadas.
   * Pulsa `[TAB]` para ver dependencias o ver la lista completa.
   * Pulsa `ENTER` para confirmar o `ESC` para descartar cambios.

### Paso 3: Armar un Instalador Personalizado para Compartir (`create_installer.sh`)

Si deseas compartir una selección específica de software con otra persona o crear un instalador limpio y modular sin tus datos personales:

1. Ejecuta el creador directamente o desde la opción 2 de `backup_apps.sh`:
   ```bash
   ./create_installer.sh
   ```
2. **Elige el origen**:
   * **Opción 1**: Capturar aplicaciones desde tu sistema actual en vivo.
   * **Opción 2**: Extraerlas a partir de un respaldo previo de tu historial.
3. **Personaliza los metadatos**:
   * Asigna un nombre al paquete (ej. `dev_tools_pack`), un título para el destinatario, autor y descripción breve.
4. **Selecciona visualmente**:
   * La TUI se abrirá en modo empaquetado para que marques exactamente qué aplicaciones, Flatpaks o AppImages incluir.
   * Por seguridad y privacidad, las configuraciones personales de `~/.config` están excluidas para no filtrar credenciales ni sesiones.
5. **Comprime y Comparte**:
   * El script creará la carpeta autónoma y te ofrecerá comprimirla en `.tar.gz`.
   * El destinatario solo debe descomprimir el archivo y ejecutar:
     ```bash
     cd mi_paquete && ./install_apps.sh
     ```
   * Verá la pantalla de bienvenida con tu título y descripción, y podrá instalar todo automáticamente.

---

## ⌨️ Atajos y Uso de la Interfaz TUI (Python Curses)

La interfaz TUI se ejecuta completamente en la terminal con una estética oscura (Dark-Cyan) sin emojis ni distracciones.

```text
================================================================================
  ASISTENTE DE RESTAURACION MULTI-SO  (CachyOS -> Arch)
================================================================================
  > [ ] Paquetes Oficiales Pacman    (45/205)
    [ ] Paquetes de AUR (Foreign)    (7/7)
    [ ] Aplicaciones Flatpak         (1/1)
    [ ] Aplicaciones AppImage        (7/7)
    [ ] Restaurar Configs ~/.config  (SI)
    [ ] Restaurar Conf. Escritorio   (SI)
    [ ] INICIAR INSTALACION Y RESTAURACION
    [ ] Salir sin instalar
================================================================================
  Atajos: [TAB] Alternar Vista (Apps/Deps/Todo) | [Espacio] Marcar/Desmarcar
  [Ctrl+A] Marcar Todo Visible | [Ctrl+X] Desmarcar Todo | [ESC] Descartar | [ENTER] Guardar
================================================================================
```

### Controles de Navegación:
* **Flecha Arriba / Flecha Abajo**: Mueve el cursor de selección entre los elementos del menú o de la lista.
* **Barra Espaciadora**: Activa/Desactiva (Check/Uncheck `[X]`) el elemento seleccionado.
* **Tecla [TAB]**: Alterna cíclicamente el modo de visualización en las listas de paquetes:
  1. *Solo Aplicaciones* (preseleccionadas por defecto).
  2. *Solo Dependencias* (desmarcadas por defecto).
  3. *Todo (Aplicaciones y Dependencias)* (con etiqueta `[Dependencia]`).
* **Escribir directamente**: Filtra en tiempo real la lista visible.
* **Retroceso (Backspace)**: Borra caracteres de la barra de búsqueda.
* **Ctrl+A**: Marca/Selecciona todos los elementos visibles en pantalla.
* **Ctrl+X**: Desmarca/Deselecciona todos los elementos visibles en pantalla.
* **ENTER**: Guarda las selecciones y regresa al menú principal (o inicia la instalación).
* **ESC**: Descarta inmediatamente cualquier cambio realizado y regresa a la pantalla anterior sin modificar tu selección (respuesta instantánea sin retardos).

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
> La carpeta de salida del respaldo (`respaldo_sistema/` o `respaldo_cachyos/`) contiene archivos sensibles como el archivo comprimido `dotfiles_config.tar.gz`. Este almacena configuraciones de tu carpeta `~/.config` que **pueden incluir claves de API, tokens de sesión de navegadores, configuraciones de mensajería y llaves de acceso SSH privadas**.
> 
> El archivo `.gitignore` incluido en este repositorio está configurado específicamente para **excluir e ignorar** estas carpetas de cualquier seguimiento de Git. **No elimines esta regla para evitar publicar tus datos personales y credenciales de seguridad en repositorios públicos de GitHub.**

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo `LICENSE` para más detalles.