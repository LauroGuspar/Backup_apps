#!/bin/bash

# Directorio de respaldos (por defecto respaldo_sistema, fallback a respaldo_cachyos)
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

if [ -d "$SCRIPT_DIR/respaldo_sistema" ]; then
    RESPALDO_DIR="$SCRIPT_DIR/respaldo_sistema"
elif [ -d "$SCRIPT_DIR/respaldo_cachyos" ]; then
    RESPALDO_DIR="$SCRIPT_DIR/respaldo_cachyos"
elif [ -d "$HOME/Backup/respaldo_sistema" ]; then
    RESPALDO_DIR="$HOME/Backup/respaldo_sistema"
elif [ -d "$HOME/Backup/respaldo_cachyos" ]; then
    RESPALDO_DIR="$HOME/Backup/respaldo_cachyos"
else
    # Si no se encuentra en las ubicaciones estándar, preguntar al usuario
    echo "No se encontró la carpeta de respaldo ('respaldo_sistema' o 'respaldo_cachyos') al lado de este script ni en ~/Backup."
    read -p "Por favor, ingrese la ruta del directorio de respaldo (o la carpeta contenedora): " CUSTOM_PATH
    CUSTOM_PATH="${CUSTOM_PATH/#\~/$HOME}"
    if [[ "$CUSTOM_PATH" == */respaldo_sistema || "$CUSTOM_PATH" == */respaldo_cachyos ]]; then
        RESPALDO_DIR="$CUSTOM_PATH"
    elif [ -d "$CUSTOM_PATH/respaldo_sistema" ]; then
        RESPALDO_DIR="$CUSTOM_PATH/respaldo_sistema"
    elif [ -d "$CUSTOM_PATH/respaldo_cachyos" ]; then
        RESPALDO_DIR="$CUSTOM_PATH/respaldo_cachyos"
    else
        RESPALDO_DIR="$CUSTOM_PATH"
    fi
fi

if [ ! -d "$RESPALDO_DIR" ]; then
    echo "Error: No se encontró la carpeta de respaldo '$RESPALDO_DIR'."
    exit 1
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

# Inicializar archivos temporales para almacenar la selección
TEMP_PACMAN=$(mktemp)
TEMP_AUR=$(mktemp)
TEMP_FLATPAK=$(mktemp)
DOTFILES_STATE_FILE="/tmp/cachy_restore_dotfiles_state"
DCONF_STATE_FILE="/tmp/cachy_restore_dconf_state"

echo "SI" > "$DOTFILES_STATE_FILE"
echo "SI" > "$DCONF_STATE_FILE"

# Copiar todas por defecto a los temporales (todo seleccionado inicialmente)
if [ "$OS_FAMILY" = "arch" ]; then
    [ -f "$RESPALDO_DIR/pacman_packages.txt" ] && cp "$RESPALDO_DIR/pacman_packages.txt" "$TEMP_PACMAN"
    [ -f "$RESPALDO_DIR/aur_packages.txt" ] && cp "$RESPALDO_DIR/aur_packages.txt" "$TEMP_AUR"
else
    [ -f "$RESPALDO_DIR/apt_packages.txt" ] && cp "$RESPALDO_DIR/apt_packages.txt" "$TEMP_PACMAN"
    [ -f "$RESPALDO_DIR/snap_packages.txt" ] && cp "$RESPALDO_DIR/snap_packages.txt" "$TEMP_AUR"
fi
[ -f "$RESPALDO_DIR/flatpak_packages.txt" ] && cp "$RESPALDO_DIR/flatpak_packages.txt" "$TEMP_FLATPAK"

# Ejecutar el Asistente de Selección TUI en Python Curses
python3 "$(dirname "$(readlink -f "$0")")/restore_tui.py" \
        "$RESPALDO_DIR" \
        "$TEMP_PACMAN" \
        "$TEMP_AUR" \
        "$TEMP_FLATPAK" \
        "$DOTFILES_STATE_FILE" \
        "$DCONF_STATE_FILE"

TUI_EXIT=$?

if [ $TUI_EXIT -ne 0 ]; then
    echo "Instalación cancelada."
    rm -f "$TEMP_PACMAN" "$TEMP_AUR" "$TEMP_FLATPAK" "$DOTFILES_STATE_FILE" "$DCONF_STATE_FILE"
    clear
    exit 0
fi

# Leer los estados de restauración
RESTORE_DOTFILES=$(cat "$DOTFILES_STATE_FILE" 2>/dev/null || echo "SI")
RESTORE_DCONF=$(cat "$DCONF_STATE_FILE" 2>/dev/null || echo "SI")
rm -f "$DOTFILES_STATE_FILE" "$DCONF_STATE_FILE"

if [ "$RESTORE_DOTFILES" = "SI" ]; then
    RESTORE_DOTFILES="SÍ"
else
    RESTORE_DOTFILES="NO"
fi

LOG_FILE="$(dirname "$(readlink -f "$0")")/restore_error.log"
clear

echo "=========================================================="
echo "      INICIANDO RESTAURACIÓN DE SOFTWARE SELECCIONADO     "
echo "=========================================================="
echo "Puedes ver el progreso aquí. Los errores se guardarán en: $LOG_FILE"
echo "" > "$LOG_FILE"

if [ "$OS_FAMILY" = "arch" ]; then
    # Actualizar base de datos del sistema Arch
    echo ""
    echo "[1/5] Actualizando bases de datos del sistema..."
    sudo pacman -Syu --noconfirm 2>> "$LOG_FILE"

    # 1. Instalar paquetes oficiales de pacman
    if [ -s "$TEMP_PACMAN" ]; then
        echo ""
        echo "[2/5] Instalando paquetes oficiales de Pacman..."
        sudo pacman -S --needed --noconfirm - < "$TEMP_PACMAN" 2>> "$LOG_FILE"
    fi

    # 2. Instalar paquetes de AUR (yay/paru)
    if [ -s "$TEMP_AUR" ]; then
        echo ""
        echo "[3/5] Instalando paquetes de AUR (Foreign)..."
        if command -v yay &> /dev/null; then
            yay -S --needed --noconfirm $(cat "$TEMP_AUR") 2>> "$LOG_FILE"
        elif command -v paru &> /dev/null; then
            paru -S --needed --noconfirm $(cat "$TEMP_AUR") 2>> "$LOG_FILE"
        else
            echo "   yay/paru no detectados. Instalando yay primero..."
            sudo pacman -S --needed --noconfirm yay 2>> "$LOG_FILE"
            yay -S --needed --noconfirm $(cat "$TEMP_AUR") 2>> "$LOG_FILE"
        fi
    fi

else
    # Restauración en Debian / Ubuntu
    # Restaurar repositorios PPA
    if [ -f "$RESPALDO_DIR/apt_sources.tar.gz" ]; then
        echo ""
        echo "[1/5] Restaurando repositorios PPA y llaves GPG..."
        sudo tar -xzf "$RESPALDO_DIR/apt_sources.tar.gz" -C /etc/apt/ 2>> "$LOG_FILE"
    fi

    # Actualizar base de datos de APT
    echo "Actualizando listas de paquetes (apt-get update)..."
    sudo apt-get update 2>> "$LOG_FILE"

    # 1. Instalar paquetes oficiales APT
    if [ -s "$TEMP_PACMAN" ]; then
        echo ""
        echo "[2/5] Instalando paquetes oficiales de APT..."
        sudo apt-get install -y --ignore-missing $(cat "$TEMP_PACMAN") 2>> "$LOG_FILE"
    fi

    # 2. Instalar aplicaciones Snap
    if [ -s "$TEMP_AUR" ]; then
        echo ""
        echo "[3/5] Instalando aplicaciones Snap..."
        if ! command -v snap &> /dev/null; then
            sudo apt-get install -y snapd 2>> "$LOG_FILE"
        fi
        while read -r snap_pkg; do
            [ -z "$snap_pkg" ] && continue
            echo "   Instalando snap: $snap_pkg..."
            sudo snap install --classic "$snap_pkg" 2>> "$LOG_FILE" || sudo snap install "$snap_pkg" 2>> "$LOG_FILE"
        done < "$TEMP_AUR"
    fi
fi

# 3. Instalar aplicaciones Flatpak
if [ -s "$TEMP_FLATPAK" ]; then
    echo ""
    echo "[4/5] Instalando aplicaciones Flatpak..."
    if ! command -v flatpak &> /dev/null; then
        if [ "$OS_FAMILY" = "arch" ]; then
            sudo pacman -S --needed --noconfirm flatpak 2>> "$LOG_FILE"
        else
            sudo apt-get install -y flatpak 2>> "$LOG_FILE"
        fi
    fi
    xargs -a "$TEMP_FLATPAK" flatpak install -y --or-update 2>> "$LOG_FILE"
fi

# 4. Restaurar archivos de configuración (~/.config)
if [ "$RESTORE_DOTFILES" = "SÍ" ] && [ -f "$RESPALDO_DIR/dotfiles_config.tar.gz" ]; then
    echo ""
    echo "[5/5] Restaurando archivos de configuración (~/.config)..."
    if [ -d "$HOME/.config" ]; then
        BACKUP_SUF="bak_$(date +%F_%H%M%S)"
        echo "   Respaldando carpeta ~/.config original limpia como ~/.config.$BACKUP_SUF"
        mv "$HOME/.config" "$HOME/.config.$BACKUP_SUF"
    fi
    tar -xzf "$RESPALDO_DIR/dotfiles_config.tar.gz" -C "$HOME" 2>> "$LOG_FILE"
    echo "   ¡Configuraciones y archivos de Niri/entorno restaurados con éxito!"
fi

# 5. Restaurar configuraciones de dconf (Debian/Ubuntu)
if [ "$OS_FAMILY" = "debian" ] && [ "$RESTORE_DCONF" = "SI" ]; then
    if [ -f "$RESPALDO_DIR/dconf_settings.ini" ] && command -v dconf &> /dev/null; then
        echo ""
        echo "Restaurando base de datos dconf (configuración de escritorio)..."
        dconf load / < "$RESPALDO_DIR/dconf_settings.ini" 2>> "$LOG_FILE"
    fi
fi

# Limpieza de archivos temporales
rm -f "$TEMP_PACMAN" "$TEMP_AUR" "$TEMP_FLATPAK"

# Mostrar estado final
echo ""
echo "=========================================================="
echo "                 RESTAURACIÓN COMPLETADA                  "
echo "=========================================================="
if [ -s "$LOG_FILE" ]; then
    echo "Nota: Se detectaron algunos errores o advertencias durante la instalación."
    echo "Puedes revisar el reporte detallado ejecutando: cat $LOG_FILE"
else
    rm -f "$LOG_FILE"
    echo "¡Felicidades! Todo se instaló sin errores aparentes."
fi
echo "Se recomienda reiniciar tu sesión o la computadora para aplicar los cambios."
echo "=========================================================="
