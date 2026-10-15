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

# Preguntar si se desea respaldar la carpeta de configuraciones ~/.config
echo ""
echo "=== Configuración de Componentes Opcionales ==="
read -p "¿Desea respaldar la carpeta de configuraciones (~/.config)? [S/n] (Por defecto: Sí): " RESP_CONFIG
RESP_CONFIG="${RESP_CONFIG:-S}"
if [[ "$RESP_CONFIG" =~ ^[sSyY]$ ]]; then
    BACKUP_CONFIG=true
else
    BACKUP_CONFIG=false
fi

# Detección de archivos AppImage en ubicaciones comunes
APPIMAGE_PATHS=()
declare -A SEEN_APPIMAGES
for search_dir in "$HOME/Applications" "$HOME/.local/bin" "$HOME/bin" "$HOME/AppImages"; do
    if [ -d "$search_dir" ]; then
        while IFS= read -r -d '' f; do
            if [ -f "$f" ] && [ -z "${SEEN_APPIMAGES["$f"]}" ]; then
                SEEN_APPIMAGES["$f"]=1
                APPIMAGE_PATHS+=("$f")
            fi
        done < <(find "$search_dir" -maxdepth 2 \( -name "*.AppImage" -o -name "*.appimage" \) -type f -print0 2>/dev/null)
    fi
done
APPIMAGE_COUNT=${#APPIMAGE_PATHS[@]}
BACKUP_APPIMAGE=false

if [ "$APPIMAGE_COUNT" -gt 0 ]; then
    APPIMAGE_SIZE_TOTAL=$(du -ch "${APPIMAGE_PATHS[@]}" 2>/dev/null | tail -n1 | cut -f1)
    echo ""
    echo "Se detectaron $APPIMAGE_COUNT archivo(s) AppImage (~$APPIMAGE_SIZE_TOTAL)."
    read -p "¿Desea respaldar los archivos AppImage detectados? [s/N] (Por defecto: No): " RESP_APPIMAGE
    RESP_APPIMAGE="${RESP_APPIMAGE:-N}"
    if [[ "$RESP_APPIMAGE" =~ ^[sSyY]$ ]]; then
        BACKUP_APPIMAGE=true
    fi
fi

RESPALDO_DIR="$BASE_DIR/respaldo_sistema"


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

# Detectar gestor de paquetes de la familia del sistema operativo
if command -v pacman &> /dev/null; then
    OS_FAMILY="arch"
elif command -v apt-get &> /dev/null; then
    OS_FAMILY="debian"
else
    echo "Error: No se pudo detectar un gestor de paquetes compatible (pacman o apt)."
    exit 1
fi

echo "S.O. Detectado: Familia $OS_FAMILY"
echo "=== Iniciando Respaldo de Aplicaciones y Configuración ==="

if [ "$OS_FAMILY" = "arch" ]; then
    # Patrón de exclusión para omitir paquetes base del sistema y específicos de CachyOS
    EXCLUDE_PATTERN="^cachyos|^linux-cachyos|^linux$|^linux-headers|^linux-lts|^linux-zen|^grub|^efibootmgr|^intel-ucode|^amd-ucode|^linux-firmware|^mkinitcpio|^systemd|^pacman|^sudo|^networkmanager|^base|^base-devel"

    # 1. Guardar paquetes oficiales de pacman (filtrando base y específicos de CachyOS)
    echo "[1/5] Guardando lista de paquetes oficiales (pacman)..."
    comm -23 <(pacman -Qqen | sort) <(pacman -Qgq base base-devel 2>/dev/null | sort -u) > "$RESPALDO_DIR/temp_pacman.txt"
    grep -Ev "($EXCLUDE_PATTERN)" "$RESPALDO_DIR/temp_pacman.txt" > "$RESPALDO_DIR/pacman_packages.txt"
    rm -f "$RESPALDO_DIR/temp_pacman.txt"

    # 2. Guardar paquetes de AUR (yay/paru) (filtrando también los del sistema si los hay)
    echo "[2/5] Guardando lista de paquetes de AUR (Foreign)..."
    pacman -Qqem | grep -Ev "($EXCLUDE_PATTERN)" > "$RESPALDO_DIR/aur_packages.txt"

else
    # Familia Debian / Ubuntu
    # 1. Guardar lista de paquetes instalados manualmente con APT
    echo "[1/5] Guardando lista de paquetes oficiales (APT)..."
    apt-mark showmanual | sort > "$RESPALDO_DIR/apt_packages.txt"

    # 2. Guardar repositorios PPA y fuentes externas
    echo "[2/5] Respaldando fuentes de repositorios PPA (/etc/apt/sources.list.d/)..."
    if [ -d "/etc/apt/sources.list.d" ]; then
        tar -czf "$RESPALDO_DIR/apt_sources.tar.gz" -C /etc/apt sources.list.d/ trusted.gpg.d/ 2>/dev/null || true
    fi

    # Respaldar Snaps si existe snapd
    if command -v snap &> /dev/null; then
        echo "-> Guardando lista de aplicaciones Snap..."
        snap list | awk 'NR>1 {print $1}' > "$RESPALDO_DIR/snap_packages.txt" 2>/dev/null || true
    fi

    # Respaldar base de datos de configuraciones del entorno gráfico (dconf)
    if command -v dconf &> /dev/null; then
        echo "-> Respaldando base de datos dconf (configuración de escritorio)..."
        dconf dump / > "$RESPALDO_DIR/dconf_settings.ini" 2>/dev/null || true
    fi
fi

# 3. Guardar paquetes Flatpak (si existen)
if command -v flatpak &> /dev/null; then
    echo "[3/5] Guardando lista de aplicaciones Flatpak..."
    flatpak list --app --columns=application > "$RESPALDO_DIR/flatpak_packages.txt" 2>/dev/null || true
else
    echo "[3/5] Flatpak no está instalado. Omitiendo..."
fi

# 4. Guardar aplicaciones AppImage
if [ "$BACKUP_APPIMAGE" = true ]; then
    echo "[4/5] Respaldando aplicaciones AppImage y accesos directos..."
    mkdir -p "$RESPALDO_DIR/appimages/desktop_entries"
    > "$RESPALDO_DIR/appimages_list.txt"
    for app_path in "${APPIMAGE_PATHS[@]}"; do
        app_name="$(basename "$app_path")"
        echo "  -> Copiando $app_name..."
        cp "$app_path" "$RESPALDO_DIR/appimages/"
        echo "$app_name" >> "$RESPALDO_DIR/appimages_list.txt"

        # Buscar accesos directos correspondientes en ~/.local/share/applications/
        if [ -d "$HOME/.local/share/applications" ]; then
            app_stem="${app_name%.*}"
            while IFS= read -r -d '' dfile; do
                dfilename="$(basename "$dfile")"
                if [[ "${dfilename,,}" == *"${app_stem,,}"* ]] || grep -qs "$app_name" "$dfile"; then
                    cp "$dfile" "$RESPALDO_DIR/appimages/desktop_entries/" 2>/dev/null || true
                fi
            done < <(find "$HOME/.local/share/applications" -maxdepth 1 -name "*.desktop" -print0 2>/dev/null)
        fi
    done
elif [ "$APPIMAGE_COUNT" -gt 0 ]; then
    echo "[4/5] Omitiendo respaldo de AppImages por elección del usuario."
else
    echo "[4/5] No se detectaron aplicaciones AppImage. Omitiendo..."
fi

# 5. Guardar configuraciones (Dotfiles) - ¡Especialmente Niri!
if [ "$BACKUP_CONFIG" = true ]; then
    echo "[5/5] Creando respaldo de configuraciones (~/.config)..."
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
else
    echo "[5/5] Omitiendo respaldo de ~/.config por elección del usuario."
fi

echo "=========================================================="
echo "¡Respaldo completado con éxito!"
echo "Los archivos se guardaron en: $RESPALDO_DIR"
echo "----------------------------------------------------------"
echo "Resumen de lo respaldado (Familia: $OS_FAMILY):"
if [ -f "$RESPALDO_DIR/pacman_packages.txt" ]; then
    echo "  - Paquetes Oficiales (Pacman): $(wc -l < "$RESPALDO_DIR/pacman_packages.txt") paquetes"
fi
if [ -f "$RESPALDO_DIR/aur_packages.txt" ]; then
    echo "  - Paquetes AUR (Foreign):      $(wc -l < "$RESPALDO_DIR/aur_packages.txt") paquetes"
fi
if [ -f "$RESPALDO_DIR/apt_packages.txt" ]; then
    echo "  - Paquetes Oficiales (APT):    $(wc -l < "$RESPALDO_DIR/apt_packages.txt") paquetes"
fi
if [ -f "$RESPALDO_DIR/snap_packages.txt" ]; then
    echo "  - Aplicaciones Snap:           $(wc -l < "$RESPALDO_DIR/snap_packages.txt") snaps"
fi
if [ -f "$RESPALDO_DIR/flatpak_packages.txt" ]; then
    echo "  - Aplicaciones Flatpak:        $(wc -l < "$RESPALDO_DIR/flatpak_packages.txt") flatpaks"
fi
if [ -f "$RESPALDO_DIR/appimages_list.txt" ]; then
    echo "  - Aplicaciones AppImage:       $(wc -l < "$RESPALDO_DIR/appimages_list.txt") appimages ($(du -sh "$RESPALDO_DIR/appimages" 2>/dev/null | cut -f1))"
else
    echo "  - Aplicaciones AppImage:       Omitido"
fi
if [ -f "$RESPALDO_DIR/apt_sources.tar.gz" ]; then
    echo "  - Repositorios y Llaves APT:   Sí (comprimido)"
fi
if [ -f "$RESPALDO_DIR/dconf_settings.ini" ]; then
    echo "  - Conf. Escritorio (dconf):    Sí"
fi
if [ -f "$RESPALDO_DIR/dotfiles_config.tar.gz" ]; then
    echo "  - Configuraciones (~/.config):  $(du -sh "$RESPALDO_DIR/dotfiles_config.tar.gz" | cut -f1)"
else
    echo "  - Configuraciones (~/.config):  Omitido"
fi
echo "=========================================================="
