#!/bin/bash

# Determinar la carpeta base para el respaldo
echo "=== Configuración del Destino del Respaldo ==="
while true; do
    echo "Seleccione dónde desea guardar el respaldo:"
    echo "1) Carpeta predeterminada (~/Backup)"
    echo "2) En la misma carpeta de este script ($(dirname "$(readlink -f "$0")"))"
    echo "3) Ruta personalizada"
    read -p "Opción [1-3] (Por defecto: 1): " OPTION
    OPTION=${OPTION:-1}

    case "$OPTION" in
        1)
            BASE_DIR="$HOME/Backup"
            break
            ;;
        2)
            BASE_DIR="$(dirname "$(readlink -f "$0")")"
            break
            ;;
        3)
            read -p "Ingrese la ruta del directorio de destino: " CUSTOM_PATH
            # Reemplazar ~ con el directorio home del usuario
            CUSTOM_PATH="${CUSTOM_PATH/#\~/$HOME}"
            if [ -z "$CUSTOM_PATH" ]; then
                echo "Error: La ruta no puede estar vacía. Intente de nuevo."
                echo ""
                continue
            fi
            BASE_DIR="$CUSTOM_PATH"
            break
            ;;
        *)
            echo "Opción no válida. Intente de nuevo."
            echo ""
            ;;
    esac
done

RESPALDO_DIR="$BASE_DIR/respaldo_cachyos"

# Crear la carpeta de respaldo
if ! mkdir -p "$RESPALDO_DIR" 2>/dev/null; then
    echo "Error: No se pudo crear o acceder al directorio: $RESPALDO_DIR"
    echo "Por favor verifique los permisos e intente de nuevo."
    exit 1
fi

# Copiar los scripts de restauración y TUI al directorio base del respaldo para asegurar portabilidad
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
if [ "$BASE_DIR" != "$SCRIPT_DIR" ]; then
    if [ -f "$SCRIPT_DIR/restore_apps.sh" ]; then
        echo "Copiando script de restauración 'restore_apps.sh' a $BASE_DIR..."
        cp "$SCRIPT_DIR/restore_apps.sh" "$BASE_DIR/"
    fi
    if [ -f "$SCRIPT_DIR/restore_tui.py" ]; then
        echo "Copiando ayudante de TUI 'restore_tui.py' a $BASE_DIR..."
        cp "$SCRIPT_DIR/restore_tui.py" "$BASE_DIR/"
    fi
fi

echo "=== Iniciando Respaldo de Aplicaciones y Configuración ==="

# Patrón de exclusión para omitir paquetes base del sistema y específicos de CachyOS
# Esto permite que la lista de software sea portátil a cualquier otra distribución basada en Arch Linux
EXCLUDE_PATTERN="^cachyos|^linux-cachyos|^linux$|^linux-headers|^linux-lts|^linux-zen|^grub|^efibootmgr|^intel-ucode|^amd-ucode|^linux-firmware|^mkinitcpio|^systemd|^pacman|^sudo|^networkmanager|^base|^base-devel"

# 1. Guardar paquetes oficiales de pacman (filtrando base y específicos de CachyOS)
echo "[1/4] Guardando lista de paquetes oficiales (pacman)..."
# Filtramos los grupos esenciales de Arch (base y base-devel)
comm -23 <(pacman -Qqen | sort) <(pacman -Qgq base base-devel 2>/dev/null | sort -u) > "$RESPALDO_DIR/temp_pacman.txt"

# Aplicamos el filtro de exclusión de sistema
grep -Ev "($EXCLUDE_PATTERN)" "$RESPALDO_DIR/temp_pacman.txt" > "$RESPALDO_DIR/pacman_packages.txt"
rm -f "$RESPALDO_DIR/temp_pacman.txt"

# 2. Guardar paquetes de AUR (yay/paru) (filtrando también los del sistema si los hay)
echo "[2/4] Guardando lista de paquetes de AUR (Foreign)..."
pacman -Qqem | grep -Ev "($EXCLUDE_PATTERN)" > "$RESPALDO_DIR/aur_packages.txt"

# 3. Guardar paquetes Flatpak (si existen)
if command -v flatpak &> /dev/null; then
    echo "[3/4] Guardando lista de aplicaciones Flatpak..."
    flatpak list --app --columns=application > "$RESPALDO_DIR/flatpak_packages.txt" 2>/dev/null || true
else
    echo "[3/4] Flatpak no está instalado. Omitiendo..."
fi

# 4. Guardar configuraciones (Dotfiles) - ¡Especialmente Niri!
echo "[4/4] Creando respaldo de configuraciones (~/.config)..."
if [ -d "$HOME/.config" ]; then
    # Excluimos directorios pesados, binarios y cachés para no inflar el archivo
    tar --exclude="*cache*" \
        --exclude="*Cache*" \
        --exclude="*discord/app-*" \
        --exclude="*google-chrome*" \
        --exclude="*microsoft-edge*" \
        --exclude="*Brave-Browser*" \
        --exclude="*BraveSoftware*" \
        --exclude="*chromium*" \
        --exclude="*Chromium*" \
        --exclude="*Code/CachedData*" \
        --exclude="*Code/User/History*" \
        -czf "$RESPALDO_DIR/dotfiles_config.tar.gz" -C "$HOME" .config
    echo "-> Respaldado ~/.config en dotfiles_config.tar.gz (excluyendo cachés y binarios autodescargados)"
else
    echo "-> No se encontró la carpeta ~/.config"
fi

echo "=========================================================="
echo "¡Respaldo completado con éxito!"
echo "Los archivos se guardaron en: $RESPALDO_DIR"
echo "----------------------------------------------------------"
echo "Resumen de lo respaldado:"
if [ -f "$RESPALDO_DIR/pacman_packages.txt" ]; then
    echo "  - Paquetes Oficiales (Pacman): $(wc -l < "$RESPALDO_DIR/pacman_packages.txt") paquetes"
fi
if [ -f "$RESPALDO_DIR/aur_packages.txt" ]; then
    echo "  - Paquetes AUR (Foreign):      $(wc -l < "$RESPALDO_DIR/aur_packages.txt") paquetes"
fi
if [ -f "$RESPALDO_DIR/flatpak_packages.txt" ]; then
    echo "  - Aplicaciones Flatpak:        $(wc -l < "$RESPALDO_DIR/flatpak_packages.txt") flatpaks"
fi
if [ -f "$RESPALDO_DIR/dotfiles_config.tar.gz" ]; then
    echo "  - Configuraciones (~/.config):  $(du -sh "$RESPALDO_DIR/dotfiles_config.tar.gz" | cut -f1)"
fi
echo "=========================================================="
