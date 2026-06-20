# 📦 Asistente de Respaldo y Restauración Portátil (Arch Linux / CachyOS)

Este conjunto de scripts interactivos en Bash y Python Curses permite realizar respaldos limpios y restaurar de forma selectiva paquetes oficiales (`pacman`), comunitarios (`AUR`), `Flatpaks` y configuraciones de usuario (`~/.config`), excluyendo de forma inteligente archivos de caché y datos temporales pesados para asegurar portabilidad y ligereza.

El asistente de restauración cuenta con una interfaz visual unificada en terminal (TUI) con estética oscura (Cyberpunk Dark-Cyan), libre de emojis e interactiva en tiempo real.

---

## ✨ Características

* **Portabilidad Inteligente**: Al realizar un respaldo, los scripts se auto-copian al directorio de destino seleccionado, garantizando que tengas el instalador completo en tu unidad USB o la nube.
* **TUI Monopágina Interactiva**: Olvídate de menús engorrosos. El asistente de restauración (`restore_tui.py`) inicia una interfaz única:
  * **Filtro en tiempo real**: Escribe para filtrar las listas de paquetes al instante.
  * **Panel de Acciones Lateral**: Con soporte de atajos de teclado rápidos (`Ctrl+A` para marcar todos los visibles, `Ctrl+X` para desmarcar visibles, `ENTER` para guardar y `ESC` para volver).
* **Filtros Automatizados**: Excluye automáticamente kernels, bootloaders, utilidades de sistema base y configuraciones específicas de hardware o del sistema de origen para que las listas de paquetes sean 100% compatibles con cualquier otra distribución basada en Arch Linux.
* **Respaldo de Prevención**: Antes de sobreescribir tu carpeta `~/.config`, el asistente realiza una copia de seguridad local (`~/.config.bak_fecha_hora`) de tus dotfiles originales en el sistema nuevo para evitar pérdidas accidentales.
* **Registro de Errores detallado**: Si algún paquete del AUR o compilación falla durante la reinstalación, los logs se guardan al final del proceso en `restore_error.log` para su revisión.

---

## 📂 Estructura del Proyecto

```text
├── backup_apps.sh      # Script Bash interactivo para realizar el respaldo.
├── restore_apps.sh     # Script Bash de ejecución que inicia el proceso de restauración.
├── restore_tui.py      # Interfaz de usuario interactiva (Python Curses TUI) para restaurar.
├── Uso.md              # Documentación de uso detallada en español.
├── README.md           # Descripción general del repositorio (este archivo).
├── .gitignore          # Archivo de exclusiones para Git (evita subir dotfiles privados).
└── LICENSE             # Licencia de código abierto (MIT).
```

---

## 🛠️ Requisitos de Ejecución

* **Sistema Operativo**: Arch Linux, CachyOS, EndeavourOS, Manjaro o derivados.
* **Intérprete**: Python 3.x (instalado por defecto en la base de distribuciones Arch).

---

## 🚀 Guía de Uso Rápido

### Paso 1: Realizar el respaldo (En el sistema actual)

1. Abre tu terminal en la carpeta donde tienes los scripts y ejecuta:
   ```bash
   ./backup_apps.sh
   ```
2. El script te preguntará interactivamente dónde guardar el respaldo:
   * **Opción 1**: Carpeta predeterminada (`~/Backup`).
   * **Opción 2**: En la misma carpeta del script (útil si lo ejecutas directamente desde tu unidad USB).
   * **Opción 3**: Una ruta personalizada de tu preferencia.
3. Copia la carpeta de destino seleccionada (que contiene la carpeta `respaldo_cachyos` y los scripts copiados) a tu USB externa o súbela a la nube.

### Paso 2: Restaurar (En el sistema nuevo)

1. Inserta tu USB y copia la carpeta a tu nuevo sistema operativo, o ejecútalo directamente desde la unidad externa.
2. Abre la terminal en el directorio del respaldo y ejecuta:
   ```bash
   ./restore_apps.sh
   ```
3. El asistente TUI se abrirá de inmediato. Ajusta tus selecciones (Pacman, AUR, Flatpak y restauración de `.config`) y haz clic en `INICIAR INSTALACION Y RESTAURACION`.

---

## 🔒 Seguridad y Privacidad (.gitignore)

> [!WARNING]
> La carpeta de salida del respaldo (`respaldo_cachyos/`) contiene archivos sensibles como el archivo comprimido `dotfiles_config.tar.gz`. Este archivo almacena configuraciones de tu carpeta `~/.config` que **pueden incluir claves de API, tokens de sesión de navegadores, configuraciones de mensajería y llaves de acceso SSH privadas**.
> 
> El archivo `.gitignore` incluido en este repositorio está configurado específicamente para **excluir e ignorar** la carpeta `respaldo_cachyos/` de cualquier seguimiento de Git. **No elimines esta regla para evitar publicar tus datos personales y credenciales de seguridad en repositorios públicos de GitHub.**

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo `LICENSE` para más detalles.