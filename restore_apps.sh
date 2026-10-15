#!/bin/bash

# Ubicación del script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

prompt_custom_path() {
    local custom_input=""
    while true; do
        read -p "Por favor, ingrese la ruta del directorio de respaldo: " custom_input
        custom_input="${custom_input/#\~/$HOME}"
        if [ -z "$custom_input" ]; then
            echo "Error: La ruta no puede estar vacía. Intente de nuevo."
            continue
        fi
        if [ ! -d "$custom_input" ]; then
            echo "Error: El directorio '$custom_input' no existe. Intente de nuevo."
            continue
        fi
        # Verificar si la ruta ingresada contiene un respaldo o es un contenedor con respaldos conocidos
        if [ -f "$custom_input/pacman_packages.txt" ] || [ -f "$custom_input/apt_packages.txt" ] || [ -f "$custom_input/backup_info.json" ]; then
            RESPALDO_DIR="$(readlink -f "$custom_input")"
            break
        elif [ -d "$custom_input/respaldo_latest" ]; then
            local resolved
            resolved="$(readlink -f "$custom_input/respaldo_latest" 2>/dev/null)"
            if [ -d "$resolved" ]; then
                RESPALDO_DIR="$resolved"
                break
            fi
        elif [ -d "$custom_input/respaldo_sistema" ]; then
            RESPALDO_DIR="$(readlink -f "$custom_input/respaldo_sistema")"
            break
        elif [ -d "$custom_input/respaldo_cachyos" ]; then
            RESPALDO_DIR="$(readlink -f "$custom_input/respaldo_cachyos")"
            break
        else
            RESPALDO_DIR="$(readlink -f "$custom_input")"
            break
        fi
    done
}

# Escaneo y detección de respaldos disponibles
declare -A SEEN_PATHS
CANDIDATE_DIRS=()

add_candidate() {
    local target="$1"
    [ -d "$target" ] || return 0
    local canon
    canon="$(readlink -f "$target" 2>/dev/null)" || return 0
    [ -d "$canon" ] || return 0
    if [ -f "$canon/pacman_packages.txt" ] || [ -f "$canon/apt_packages.txt" ] || [ -f "$canon/backup_info.json" ]; then
        if [ -z "${SEEN_PATHS["$canon"]}" ]; then
            SEEN_PATHS["$canon"]=1
            CANDIDATE_DIRS+=("$canon")
        fi
    fi
}

# 1. Verificar si SCRIPT_DIR es en sí mismo una carpeta de respaldo
add_candidate "$SCRIPT_DIR"

# 2. Buscar subdirectorios en SCRIPT_DIR
shopt -s nullglob
for d in "$SCRIPT_DIR"/*; do
    [ -d "$d" ] && add_candidate "$d"
done

# 3. Buscar subdirectorios en el directorio padre de SCRIPT_DIR
for d in "$SCRIPT_DIR/.."/*; do
    [ -d "$d" ] && add_candidate "$d"
done

# 4. Buscar en ~/Backup y sus subdirectorios
if [ -d "$HOME/Backup" ]; then
    add_candidate "$HOME/Backup"
    for d in "$HOME/Backup"/*; do
        [ -d "$d" ] && add_candidate "$d"
    done
fi
shopt -u nullglob

# Ordenar candidatos y extraer resúmenes informativos
SORTED_CANDIDATES=()
CANDIDATE_SUMMARIES=()

if [ ${#CANDIDATE_DIRS[@]} -gt 0 ]; then
    if command -v python3 &>/dev/null; then
        while IFS=$'\t' read -r c_path c_summary; do
            [ -n "$c_path" ] || continue
            SORTED_CANDIDATES+=("$c_path")
            CANDIDATE_SUMMARIES+=("$c_summary")
        done < <(python3 -c '
import os, sys, json
from datetime import datetime

candidates = sys.argv[1:]
items = []

def get_candidate_data(d):
    info_path = os.path.join(d, "backup_info.json")
    if os.path.isfile(info_path):
        try:
            with open(info_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            name = data.get("name") or os.path.basename(d)
            ts = data.get("timestamp", 0)
            created_at = data.get("created_at", "")
            date_str = created_at[:16] if len(created_at) >= 16 else created_at
            if not date_str:
                date_str = datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M") if ts else "Desconocida"
            if not ts:
                ts = int(os.path.getmtime(info_path))

            os_fam = data.get("os_family", "")
            counts = data.get("counts", {})
            parts = []
            if os_fam == "arch" or counts.get("pacman", 0) > 0 or counts.get("aur", 0) > 0:
                parts.append("Pacman: %d" % counts.get("pacman", 0))
                parts.append("AUR: %d" % counts.get("aur", 0))
            if os_fam == "debian" or counts.get("apt", 0) > 0 or counts.get("snap", 0) > 0:
                parts.append("APT: %d" % counts.get("apt", 0))
                parts.append("Snap: %d" % counts.get("snap", 0))
            if counts.get("flatpak", 0) > 0:
                parts.append("Flatpak: %d" % counts.get("flatpak", 0))
            has_df = "Sí" if data.get("has_dotfiles") else "No"
            parts.append("Dotfiles: %s" % has_df)
            has_app = "Sí" if data.get("has_appimages") else "No"
            parts.append("AppImages: %s" % has_app)
            summary = "[%s] %s (%s)" % (date_str, name, ", ".join(parts))
            return ts, summary
        except Exception:
            pass

    # Fallback: inspección directa de archivos en el directorio
    name = os.path.basename(d)
    mtime = os.path.getmtime(d)
    for fn in ["pacman_packages.txt", "apt_packages.txt", "backup_info.json"]:
        p = os.path.join(d, fn)
        if os.path.exists(p):
            mtime = os.path.getmtime(p)
            break
    date_str = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M")

    parts = []
    p_pacman = os.path.join(d, "pacman_packages.txt")
    p_aur = os.path.join(d, "aur_packages.txt")
    p_apt = os.path.join(d, "apt_packages.txt")
    p_snap = os.path.join(d, "snap_packages.txt")
    p_flatpak = os.path.join(d, "flatpak_packages.txt")
    p_dotfiles = os.path.join(d, "dotfiles_config.tar.gz")
    p_appimages = os.path.join(d, "appimages_list.txt")

    def count_lines(filepath):
        try:
            with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                return sum(1 for line in f if line.strip())
        except Exception:
            return 0

    if os.path.exists(p_pacman) or os.path.exists(p_aur):
        parts.append("Pacman: %d" % count_lines(p_pacman))
        parts.append("AUR: %d" % count_lines(p_aur))
    if os.path.exists(p_apt) or os.path.exists(p_snap):
        parts.append("APT: %d" % count_lines(p_apt))
        parts.append("Snap: %d" % count_lines(p_snap))
    if os.path.exists(p_flatpak):
        parts.append("Flatpak: %d" % count_lines(p_flatpak))

    has_df = "Sí" if os.path.exists(p_dotfiles) else "No"
    parts.append("Dotfiles: %s" % has_df)
    has_app = "Sí" if (os.path.exists(p_appimages) or os.path.isdir(os.path.join(d, "appimages"))) else "No"
    parts.append("AppImages: %s" % has_app)

    summary = "[%s] %s (%s)" % (date_str, name, ", ".join(parts))
    return int(mtime), summary

for d in candidates:
    if os.path.isdir(d):
        ts, summary = get_candidate_data(d)
        items.append((ts, d, summary))

items.sort(key=lambda x: x[0], reverse=True)
for ts, d, summary in items:
    print("%s\t%s" % (d, summary))
' "${CANDIDATE_DIRS[@]}")
    else
        for cdir in "${CANDIDATE_DIRS[@]}"; do
            SORTED_CANDIDATES+=("$cdir")
            CANDIDATE_SUMMARIES+=("$(basename "$cdir")")
        done
    fi
fi

# Selección interactiva del respaldo
NUM_BACKUPS=${#SORTED_CANDIDATES[@]}

if [ "$NUM_BACKUPS" -gt 1 ]; then
    CUSTOM_OPTION=$((NUM_BACKUPS + 1))
    while true; do
        echo "=== Historial de Respaldos Disponibles ==="
        echo "Se encontraron varios respaldos. Seleccione cuál desea restaurar:"
        for i in "${!SORTED_CANDIDATES[@]}"; do
            idx=$((i + 1))
            echo "$idx) ${CANDIDATE_SUMMARIES[$i]}"
        done
        echo "$CUSTOM_OPTION) Ingresar ruta personalizada..."
        read -p "Opción [1-$CUSTOM_OPTION] (Por defecto: 1): " OPTION
        OPTION="${OPTION:-1}"

        if [[ "$OPTION" =~ ^[0-9]+$ ]] && [ "$OPTION" -ge 1 ] && [ "$OPTION" -le "$NUM_BACKUPS" ]; then
            SELECTED_INDEX=$((OPTION - 1))
            RESPALDO_DIR="${SORTED_CANDIDATES[$SELECTED_INDEX]}"
            break
        elif [ "$OPTION" -eq "$CUSTOM_OPTION" ] 2>/dev/null; then
            prompt_custom_path
            break
        else
            echo "Opción no válida. Intente de nuevo."
            echo ""
        fi
    done
elif [ "$NUM_BACKUPS" -eq 1 ]; then
    echo "=== Respaldo Detectado ==="
    echo "Se encontró un respaldo: ${CANDIDATE_SUMMARIES[0]}"
    read -p "¿Desea utilizar este respaldo? [S/n] (Por defecto: Sí): " CONFIRM
    CONFIRM="${CONFIRM:-S}"
    if [[ "$CONFIRM" =~ ^[sSyY]$ ]]; then
        RESPALDO_DIR="${SORTED_CANDIDATES[0]}"
    else
        prompt_custom_path
    fi
else
    echo "No se encontraron respaldos en las ubicaciones estándar."
    prompt_custom_path
fi

if [ ! -d "$RESPALDO_DIR" ]; then
    echo "Error: No se encontró la carpeta de respaldo '$RESPALDO_DIR'."
    exit 1
fi

echo ""
echo "Directorio de respaldo seleccionado: $RESPALDO_DIR"

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
TEMP_APPIMAGE=$(mktemp)
DOTFILES_STATE_FILE="/tmp/cachy_restore_dotfiles_state"
DCONF_STATE_FILE="/tmp/cachy_restore_dconf_state"

echo "SI" > "$DOTFILES_STATE_FILE"
echo "SI" > "$DCONF_STATE_FILE"

# Copiar paquetes a los temporales (por defecto solo aplicaciones seleccionadas si existe classified_apps.txt)
if [ "$OS_FAMILY" = "arch" ]; then
    if [ -f "$RESPALDO_DIR/classified_apps.txt" ] && [ -f "$RESPALDO_DIR/pacman_packages.txt" ]; then
        grep -Fxf "$RESPALDO_DIR/classified_apps.txt" "$RESPALDO_DIR/pacman_packages.txt" > "$TEMP_PACMAN" 2>/dev/null || cp "$RESPALDO_DIR/pacman_packages.txt" "$TEMP_PACMAN"
    else
        [ -f "$RESPALDO_DIR/pacman_packages.txt" ] && cp "$RESPALDO_DIR/pacman_packages.txt" "$TEMP_PACMAN"
    fi
    [ -f "$RESPALDO_DIR/aur_packages.txt" ] && cp "$RESPALDO_DIR/aur_packages.txt" "$TEMP_AUR"
else
    if [ -f "$RESPALDO_DIR/classified_apps.txt" ] && [ -f "$RESPALDO_DIR/apt_packages.txt" ]; then
        grep -Fxf "$RESPALDO_DIR/classified_apps.txt" "$RESPALDO_DIR/apt_packages.txt" > "$TEMP_PACMAN" 2>/dev/null || cp "$RESPALDO_DIR/apt_packages.txt" "$TEMP_PACMAN"
    else
        [ -f "$RESPALDO_DIR/apt_packages.txt" ] && cp "$RESPALDO_DIR/apt_packages.txt" "$TEMP_PACMAN"
    fi
    [ -f "$RESPALDO_DIR/snap_packages.txt" ] && cp "$RESPALDO_DIR/snap_packages.txt" "$TEMP_AUR"
fi
[ -f "$RESPALDO_DIR/flatpak_packages.txt" ] && cp "$RESPALDO_DIR/flatpak_packages.txt" "$TEMP_FLATPAK"
[ -f "$RESPALDO_DIR/appimages_list.txt" ] && cp "$RESPALDO_DIR/appimages_list.txt" "$TEMP_APPIMAGE"

# Ejecutar el Asistente de Selección TUI en Python Curses
TUI_SCRIPT="$(dirname "$(readlink -f "$0")")/restore_tui.py"
if [ ! -f "$TUI_SCRIPT" ] && [ -f "$RESPALDO_DIR/restore_tui.py" ]; then
    TUI_SCRIPT="$RESPALDO_DIR/restore_tui.py"
fi

python3 "$TUI_SCRIPT" \
        "$RESPALDO_DIR" \
        "$TEMP_PACMAN" \
        "$TEMP_AUR" \
        "$TEMP_FLATPAK" \
        "$DOTFILES_STATE_FILE" \
        "$DCONF_STATE_FILE" \
        "$TEMP_APPIMAGE"

TUI_EXIT=$?

if [ $TUI_EXIT -ne 0 ]; then
    echo "Instalación cancelada."
    rm -f "$TEMP_PACMAN" "$TEMP_AUR" "$TEMP_FLATPAK" "$TEMP_APPIMAGE" "$DOTFILES_STATE_FILE" "$DCONF_STATE_FILE"
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
    echo "[1/6] Actualizando bases de datos del sistema..."
    sudo pacman -Syu --noconfirm 2>> "$LOG_FILE"

    # 1. Instalar paquetes oficiales de pacman
    if [ -s "$TEMP_PACMAN" ]; then
        echo ""
        echo "[2/6] Instalando paquetes oficiales de Pacman..."
        sudo pacman -S --needed --noconfirm - < "$TEMP_PACMAN" 2>> "$LOG_FILE"
    fi

    # 2. Instalar paquetes de AUR (yay/paru)
    if [ -s "$TEMP_AUR" ]; then
        echo ""
        echo "[3/6] Instalando paquetes de AUR (Foreign)..."
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
        echo "[1/6] Restaurando repositorios PPA y llaves GPG..."
        sudo tar -xzf "$RESPALDO_DIR/apt_sources.tar.gz" -C /etc/apt/ 2>> "$LOG_FILE"
    fi

    # Actualizar base de datos de APT
    echo "Actualizando listas de paquetes (apt-get update)..."
    sudo apt-get update 2>> "$LOG_FILE"

    # 1. Instalar paquetes oficiales APT
    if [ -s "$TEMP_PACMAN" ]; then
        echo ""
        echo "[2/6] Instalando paquetes oficiales de APT..."
        sudo apt-get install -y --ignore-missing $(cat "$TEMP_PACMAN") 2>> "$LOG_FILE"
    fi

    # 2. Instalar aplicaciones Snap
    if [ -s "$TEMP_AUR" ]; then
        echo ""
        echo "[3/6] Instalando aplicaciones Snap..."
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
    echo "[4/6] Instalando aplicaciones Flatpak..."
    if ! command -v flatpak &> /dev/null; then
        if [ "$OS_FAMILY" = "arch" ]; then
            sudo pacman -S --needed --noconfirm flatpak 2>> "$LOG_FILE"
        else
            sudo apt-get install -y flatpak 2>> "$LOG_FILE"
        fi
    fi
    xargs -a "$TEMP_FLATPAK" flatpak install -y --or-update 2>> "$LOG_FILE"
fi

# 4. Restaurar aplicaciones AppImage
if [ -s "$TEMP_APPIMAGE" ] && [ -d "$RESPALDO_DIR/appimages" ]; then
    echo ""
    echo "[5/6] Restaurando aplicaciones AppImage..."
    mkdir -p "$HOME/Applications"

    # Verificar e instalar soporte FUSE 2 para AppImages si es necesario
    if [ "$OS_FAMILY" = "arch" ]; then
        if ! pacman -Q fuse2 &>/dev/null; then
            echo "   Instalando soporte FUSE 2 para AppImages (fuse2)..."
            sudo pacman -S --needed --noconfirm fuse2 2>> "$LOG_FILE" || true
        fi
    else
        if ! dpkg -s libfuse2 &>/dev/null && ! dpkg -s libfuse2t64 &>/dev/null; then
            echo "   Instalando soporte FUSE 2 para AppImages (libfuse2)..."
            sudo apt-get install -y libfuse2 2>> "$LOG_FILE" || true
        fi
    fi

    while IFS= read -r app_name || [ -n "$app_name" ]; do
        [ -z "$app_name" ] && continue
        if [ -f "$RESPALDO_DIR/appimages/$app_name" ]; then
            echo "   Restaurando AppImage: $app_name..."
            cp "$RESPALDO_DIR/appimages/$app_name" "$HOME/Applications/$app_name"
            chmod +x "$HOME/Applications/$app_name"
        fi
    done < "$TEMP_APPIMAGE"

    if [ -d "$RESPALDO_DIR/appimages/desktop_entries" ]; then
        shopt -s nullglob
        desktop_files=("$RESPALDO_DIR/appimages/desktop_entries/"*.desktop)
        shopt -u nullglob
        if [ ${#desktop_files[@]} -gt 0 ]; then
            echo "   Restaurando accesos directos de escritorio (.desktop)..."
            mkdir -p "$HOME/.local/share/applications"
            cp "$RESPALDO_DIR/appimages/desktop_entries/"*.desktop "$HOME/.local/share/applications/"
            update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
        fi
    fi
fi

# 5. Restaurar archivos de configuración (~/.config)
if [ "$RESTORE_DOTFILES" = "SÍ" ] && [ -f "$RESPALDO_DIR/dotfiles_config.tar.gz" ]; then
    echo ""
    echo "[6/6] Restaurando archivos de configuración (~/.config)..."
    if [ -d "$HOME/.config" ]; then
        BACKUP_SUF="bak_$(date +%F_%H%M%S)"
        echo "   Respaldando carpeta ~/.config original limpia como ~/.config.$BACKUP_SUF"
        mv "$HOME/.config" "$HOME/.config.$BACKUP_SUF"
    fi
    tar -xzf "$RESPALDO_DIR/dotfiles_config.tar.gz" -C "$HOME" 2>> "$LOG_FILE"
    echo "   ¡Configuraciones y archivos de Niri/entorno restaurados con éxito!"
fi

# 6. Restaurar configuraciones de dconf (Debian/Ubuntu)
if [ "$OS_FAMILY" = "debian" ] && [ "$RESTORE_DCONF" = "SI" ]; then
    if [ -f "$RESPALDO_DIR/dconf_settings.ini" ] && command -v dconf &> /dev/null; then
        echo ""
        echo "Restaurando base de datos dconf (configuración de escritorio)..."
        dconf load / < "$RESPALDO_DIR/dconf_settings.ini" 2>> "$LOG_FILE"
    fi
fi

# Limpieza de archivos temporales
rm -f "$TEMP_PACMAN" "$TEMP_AUR" "$TEMP_FLATPAK" "$TEMP_APPIMAGE"

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
