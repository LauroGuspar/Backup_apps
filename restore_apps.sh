#!/bin/bash

# Directorio de respaldos
RESPALDO_DIR="$(dirname "$(readlink -f "$0")")/respaldo_cachyos"

if [ ! -d "$RESPALDO_DIR" ]; then
    # Alternativa si no está al lado del script
    RESPALDO_DIR="$HOME/Backup/respaldo_cachyos"
fi

if [ ! -d "$RESPALDO_DIR" ]; then
    echo "No se encontró la carpeta 'respaldo_cachyos' al lado de este script ni en ~/Backup."
    read -p "Por favor, ingrese la ruta del directorio que contiene 'respaldo_cachyos' (o la ruta completa al mismo): " CUSTOM_PATH
    CUSTOM_PATH="${CUSTOM_PATH/#\~/$HOME}"
    if [[ "$CUSTOM_PATH" == */respaldo_cachyos ]]; then
        RESPALDO_DIR="$CUSTOM_PATH"
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

# Inicializar archivos temporales para almacenar la selección
TEMP_PACMAN=$(mktemp)
TEMP_AUR=$(mktemp)
TEMP_FLATPAK=$(mktemp)
DOTFILES_STATE_FILE="/tmp/cachy_restore_dotfiles_state"
echo "SI" > "$DOTFILES_STATE_FILE"

# Copiar todas por defecto a los temporales (todo seleccionado inicialmente)
[ -f "$RESPALDO_DIR/pacman_packages.txt" ] && cp "$RESPALDO_DIR/pacman_packages.txt" "$TEMP_PACMAN"
[ -f "$RESPALDO_DIR/aur_packages.txt" ] && cp "$RESPALDO_DIR/aur_packages.txt" "$TEMP_AUR"
[ -f "$RESPALDO_DIR/flatpak_packages.txt" ] && cp "$RESPALDO_DIR/flatpak_packages.txt" "$TEMP_FLATPAK"

# Ejecutar el Asistente de Selección TUI en Python Curses
python3 "$(dirname "$(readlink -f "$0")")/restore_tui.py" \
        "$RESPALDO_DIR" \
        "$TEMP_PACMAN" \
        "$TEMP_AUR" \
        "$TEMP_FLATPAK" \
        "$DOTFILES_STATE_FILE"

TUI_EXIT=$?

if [ $TUI_EXIT -ne 0 ]; then
    echo "Instalación cancelada."
    rm -f "$TEMP_PACMAN" "$TEMP_AUR" "$TEMP_FLATPAK" "$DOTFILES_STATE_FILE"
    clear
    exit 0
fi

# Leer el estado de restauración de dotfiles
RESTORE_DOTFILES=$(cat "$DOTFILES_STATE_FILE" 2>/dev/null || echo "SI")
rm -f "$DOTFILES_STATE_FILE"

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

# Actualizar base de datos del sistema
echo ""
echo "[1/5] Actualizando bases de datos del sistema..."
sudo pacman -Syu --noconfirm 2>> "$LOG_FILE"

# 1. Instalar paquetes oficiales de pacman
if [ -s "$TEMP_PACMAN" ]; then
    echo ""
    echo "[2/5] Instalando paquetes oficiales de Pacman..."
    sudo pacman -S --needed --noconfirm - < "$TEMP_PACMAN" 2>> "$LOG_FILE"
else
    echo ""
    echo "[2/5] No se seleccionaron paquetes de Pacman para instalar."
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
else
    echo ""
    echo "[3/5] No se seleccionaron paquetes de AUR para instalar."
fi

# 3. Instalar aplicaciones Flatpak
if [ -s "$TEMP_FLATPAK" ]; then
    echo ""
    echo "[4/5] Instalando aplicaciones Flatpak..."
    if ! command -v flatpak &> /dev/null; then
        sudo pacman -S --needed --noconfirm flatpak 2>> "$LOG_FILE"
    fi
    xargs -a "$TEMP_FLATPAK" flatpak install -y --or-update 2>> "$LOG_FILE"
else
    echo ""
    echo "[4/5] No se seleccionaron aplicaciones Flatpak para instalar."
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
    echo "   ¡Configuraciones y archivos de Niri restaurados con éxito!"
else
    echo ""
    echo "[5/5] Restauración de configuraciones (~/.config) omitida."
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
echo "Se recomienda reiniciar tu sesión o la laptop para aplicar los cambios."
echo "=========================================================="
