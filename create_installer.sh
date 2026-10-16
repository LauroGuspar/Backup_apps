#!/bin/bash
# create_installer.sh - Creador de instaladores de aplicaciones personalizados ("Todo en 1")
# Permite seleccionar aplicaciones específicas y generar un paquete autónomo y compartible.

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CURRENT_USER="${USER:-$(whoami)}"

echo "=========================================================="
echo "    CREADOR DE INSTALADOR PERSONALIZADO DE APLICACIONES   "
echo "=========================================================="
echo "Este asistente te permite crear un paquete limpio con una "
echo "selección específica de aplicaciones para compartir o instalar."
echo ""

# Paso 1: Elegir el origen de las aplicaciones
echo "Seleccione el origen de las aplicaciones a empaquetar:"
echo "1) Sistema actual en vivo (Capturar paquetes instalados ahora)"
echo "2) A partir de un respaldo existente en el historial"
read -p "Opción [1-2] (Por defecto: 1): " SOURCE_OPTION
SOURCE_OPTION="${SOURCE_OPTION:-1}"

TEMP_STAGING_DIR=""
cleanup() {
    [ -n "$TEMP_STAGING_DIR" ] && rm -rf "$TEMP_STAGING_DIR"
    [ -n "$TEMP_SEL_PACMAN" ] && rm -f "$TEMP_SEL_PACMAN"
    [ -n "$TEMP_SEL_AUR" ] && rm -f "$TEMP_SEL_AUR"
    [ -n "$TEMP_SEL_FLATPAK" ] && rm -f "$TEMP_SEL_FLATPAK"
    [ -n "$TEMP_SEL_APPIMAGE" ] && rm -f "$TEMP_SEL_APPIMAGE"
}
trap cleanup EXIT

if [ "$SOURCE_OPTION" = "2" ]; then
    # Buscar respaldos existentes
    declare -A SEEN_PATHS
    CANDIDATE_DIRS=()
    add_candidate() {
        local target="$1"
        [ -d "$target" ] || return 0
        local canon
        canon="$(readlink -f "$target" 2>/dev/null)" || return 0
        [ -d "$canon" ] || return 0
        if [ -f "$canon/pacman_packages.txt" ] || [ -f "$canon/apt_packages.txt" ] || [ -f "$canon/backup_info.json" ] || [ -f "$canon/installer_info.json" ]; then
            if [ -z "${SEEN_PATHS["$canon"]}" ]; then
                SEEN_PATHS["$canon"]=1
                CANDIDATE_DIRS+=("$canon")
            fi
        fi
    }

    shopt -s nullglob
    for d in "$SCRIPT_DIR"/* "$SCRIPT_DIR/.."/* "$HOME/Backup"/*; do
        [ -d "$d" ] && add_candidate "$d"
    done
    shopt -u nullglob

    if [ ${#CANDIDATE_DIRS[@]} -eq 0 ]; then
        echo "No se encontraron respaldos previos. Utilizando el sistema actual en vivo..."
        SOURCE_OPTION="1"
    else
        echo ""
        echo "=== Seleccione el Respaldo Base ==="
        for i in "${!CANDIDATE_DIRS[@]}"; do
            echo "$((i+1))) ${CANDIDATE_DIRS[$i]}"
        done
        read -p "Seleccione una opción [1-${#CANDIDATE_DIRS[@]}] (Por defecto: 1): " CHOSEN_IDX
        CHOSEN_IDX="${CHOSEN_IDX:-1}"
        if [ "$CHOSEN_IDX" -ge 1 ] && [ "$CHOSEN_IDX" -le "${#CANDIDATE_DIRS[@]}" ] 2>/dev/null; then
            SOURCE_DIR="${CANDIDATE_DIRS[$((CHOSEN_IDX-1))]}"
        else
            SOURCE_DIR="${CANDIDATE_DIRS[0]}"
        fi
        echo "Origen seleccionado: $SOURCE_DIR"
    fi
fi

if [ "$SOURCE_OPTION" = "1" ]; then
    TEMP_STAGING_DIR=$(mktemp -d)
    SOURCE_DIR="$TEMP_STAGING_DIR"
    
    echo ""
    echo "Capturando aplicaciones instaladas en el sistema..."
    
    # Detectar familia de SO
    if command -v pacman &> /dev/null; then
        OS_FAMILY="arch"
        EXCLUDE_PATTERN="^cachyos|^linux-cachyos|^linux$|^linux-headers|^linux-lts|^linux-zen|^grub|^efibootmgr|^intel-ucode|^amd-ucode|^linux-firmware|^mkinitcpio|^systemd|^pacman|^sudo|^networkmanager|^base|^base-devel"
        comm -23 <(pacman -Qqen 2>/dev/null | sort) <(pacman -Qgq base base-devel 2>/dev/null | sort -u) > "$TEMP_STAGING_DIR/temp_pac.txt" || true
        grep -Ev "($EXCLUDE_PATTERN)" "$TEMP_STAGING_DIR/temp_pac.txt" > "$TEMP_STAGING_DIR/pacman_packages.txt" 2>/dev/null || true
        rm -f "$TEMP_STAGING_DIR/temp_pac.txt"
        
        pacman -Qqem 2>/dev/null | grep -Ev "($EXCLUDE_PATTERN)" > "$TEMP_STAGING_DIR/aur_packages.txt" || true
        
        # Clasificar aplicaciones
        python3 -c '
import os, glob
apps = set()
for f in glob.glob("/var/lib/pacman/local/*/files"):
    pkg_dir = os.path.dirname(f)
    pkg = os.path.basename(pkg_dir).rsplit("-", 2)[0]
    with open(f, "r", errors="ignore") as fh:
        if "usr/share/applications/" in fh.read():
            apps.add(pkg)
apps.update({"neovim", "fastfetch", "ghostty", "lazygit", "htop", "btop", "nvtop", "ranger", "ripgrep", "git", "github-cli", "docker", "docker-compose", "tmux", "zsh", "fish", "micro", "wget", "curl", "tree"})
with open("'"$TEMP_STAGING_DIR"'/classified_apps.txt", "w") as out:
    for a in sorted(apps):
        out.write(f"{a}\n")
' 2>/dev/null || true

    elif command -v apt-get &> /dev/null; then
        OS_FAMILY="debian"
        apt-mark showmanual 2>/dev/null | sort > "$TEMP_STAGING_DIR/apt_packages.txt" || true
        if command -v snap &> /dev/null; then
            snap list 2>/dev/null | awk 'NR>1 {print $1}' > "$TEMP_STAGING_DIR/snap_packages.txt" || true
        fi
    else
        echo "Error: No se detectó un gestor de paquetes soportado (pacman o apt)."
        exit 1
    fi
    
    # Flatpaks
    if command -v flatpak &> /dev/null; then
        flatpak list --app --columns=application > "$TEMP_STAGING_DIR/flatpak_packages.txt" 2>/dev/null || true
    fi
    
    # AppImages
    APPIMAGE_DIRS=("$HOME/Applications" "$HOME/.local/bin" "$HOME/bin" "$HOME/AppImages")
    FOUND_APPIMAGES=()
    shopt -s nullglob
    for dir in "${APPIMAGE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            for f in "$dir"/*.AppImage "$dir"/*.appimage; do
                [ -f "$f" ] && FOUND_APPIMAGES+=("$f")
            done
        fi
    done
    shopt -u nullglob
    
    if [ ${#FOUND_APPIMAGES[@]} -gt 0 ]; then
        mkdir -p "$TEMP_STAGING_DIR/appimages/desktop_entries"
        for app in "${FOUND_APPIMAGES[@]}"; do
            bname="$(basename "$app")"
            echo "$bname" >> "$TEMP_STAGING_DIR/appimages_list.txt"
            cp "$app" "$TEMP_STAGING_DIR/appimages/" 2>/dev/null || true
            for d in "$HOME/.local/share/applications"/*.desktop; do
                if grep -Fq "$bname" "$d" 2>/dev/null; then
                    cp "$d" "$TEMP_STAGING_DIR/appimages/desktop_entries/" 2>/dev/null || true
                fi
            done
        done
    fi
fi

# Detectar OS Family desde origen si viene de respaldo
if [ -z "$OS_FAMILY" ]; then
    if [ -f "$SOURCE_DIR/pacman_packages.txt" ]; then
        OS_FAMILY="arch"
    elif [ -f "$SOURCE_DIR/apt_packages.txt" ]; then
        OS_FAMILY="debian"
    else
        OS_FAMILY="linux"
    fi
fi

echo ""
echo "=== Configuración del Paquete a Armar ==="
read -p "Nombre del directorio del instalador [Por defecto: my_custom_apps]: " BUNDLE_NAME
BUNDLE_NAME="${BUNDLE_NAME:-my_custom_apps}"
BUNDLE_NAME=$(echo "$BUNDLE_NAME" | sed 's/[^a-zA-Z0-9._-]/_/g')

read -p "Título para mostrar al destinatario [Por defecto: Paquete de Aplicaciones Recomendadas]: " BUNDLE_TITLE
BUNDLE_TITLE="${BUNDLE_TITLE:-Paquete de Aplicaciones Recomendadas}"

read -p "Creador / Autor [Por defecto: $CURRENT_USER]: " BUNDLE_AUTHOR
BUNDLE_AUTHOR="${BUNDLE_AUTHOR:-$CURRENT_USER}"

read -p "Descripción breve [Opcional]: " BUNDLE_DESC
BUNDLE_DESC="${BUNDLE_DESC:-Selección de aplicaciones listas para instalar}"

# Preparar temporales para la TUI
TEMP_SEL_PACMAN=$(mktemp)
TEMP_SEL_AUR=$(mktemp)
TEMP_SEL_FLATPAK=$(mktemp)
TEMP_SEL_APPIMAGE=$(mktemp)

# Por defecto, preseleccionar únicamente las aplicaciones (no dependencias)
if [ -f "$SOURCE_DIR/classified_apps.txt" ]; then
    if [ -f "$SOURCE_DIR/pacman_packages.txt" ]; then
        grep -Fxf "$SOURCE_DIR/classified_apps.txt" "$SOURCE_DIR/pacman_packages.txt" > "$TEMP_SEL_PACMAN" 2>/dev/null || true
    fi
    if [ -f "$SOURCE_DIR/apt_packages.txt" ]; then
        grep -Fxf "$SOURCE_DIR/classified_apps.txt" "$SOURCE_DIR/apt_packages.txt" > "$TEMP_SEL_PACMAN" 2>/dev/null || true
    fi
else
    [ -f "$SOURCE_DIR/pacman_packages.txt" ] && cp "$SOURCE_DIR/pacman_packages.txt" "$TEMP_SEL_PACMAN"
    [ -f "$SOURCE_DIR/apt_packages.txt" ] && cp "$SOURCE_DIR/apt_packages.txt" "$TEMP_SEL_PACMAN"
fi

[ -f "$SOURCE_DIR/aur_packages.txt" ] && cp "$SOURCE_DIR/aur_packages.txt" "$TEMP_SEL_AUR"
[ -f "$SOURCE_DIR/snap_packages.txt" ] && cp "$SOURCE_DIR/snap_packages.txt" "$TEMP_SEL_AUR"
[ -f "$SOURCE_DIR/flatpak_packages.txt" ] && cp "$SOURCE_DIR/flatpak_packages.txt" "$TEMP_SEL_FLATPAK"
[ -f "$SOURCE_DIR/appimages_list.txt" ] && cp "$SOURCE_DIR/appimages_list.txt" "$TEMP_SEL_APPIMAGE"

echo ""
echo "Abriendo Asistente de Selección..."
set +e
TUI_TITLE="CREAR INSTALADOR: $BUNDLE_TITLE" \
TUI_SUBTITLE="Marca las aplicaciones y paquetes que deseas incluir en este paquete:" \
TUI_ACTION_LABEL="GUARDAR Y FINALIZAR EMPAQUETADO" \
TUI_EXIT_LABEL="Cancelar y salir sin crear" \
TUI_HIDE_DOTFILES="1" \
python3 "$SCRIPT_DIR/restore_tui.py" \
    "$SOURCE_DIR" \
    "$TEMP_SEL_PACMAN" \
    "$TEMP_SEL_AUR" \
    "$TEMP_SEL_FLATPAK" \
    "/dev/null" \
    "/dev/null" \
    "$TEMP_SEL_APPIMAGE"
TUI_RES=$?
set -e

if [ $TUI_RES -ne 0 ]; then
    echo ""
    echo "Operación cancelada por el usuario. No se creó ningún instalador."
    exit 0
fi

# Directorio de destino
echo ""
echo "=== Destino del Instalador ==="
echo "1) Directorio actual ($PWD)"
echo "2) Carpeta predeterminada de respaldos ($HOME/Backup)"
echo "3) Ruta personalizada"
read -p "Opción [1-3] (Por defecto: 1): " DEST_OPT
DEST_OPT="${DEST_OPT:-1}"

case "$DEST_OPT" in
    2) DEST_BASE="$HOME/Backup" ;;
    3)
        read -p "Ingrese la ruta de la carpeta contenedora: " CUSTOM_DEST
        CUSTOM_DEST="${CUSTOM_DEST/#\~/$HOME}"
        DEST_BASE="${CUSTOM_DEST:-$PWD}"
        ;;
    *) DEST_BASE="$PWD" ;;
esac

mkdir -p "$DEST_BASE"
BUNDLE_DIR="$DEST_BASE/$BUNDLE_NAME"
mkdir -p "$BUNDLE_DIR"

echo "Ensamblando paquete en: $BUNDLE_DIR..."

# Copiar paquetes seleccionados
HAS_PACMAN=0
HAS_AUR=0
HAS_APT=0
HAS_SNAP=0
HAS_FLATPAK=0
HAS_APPIMAGE=0

if [ -s "$TEMP_SEL_PACMAN" ]; then
    if [ "$OS_FAMILY" = "debian" ]; then
        cp "$TEMP_SEL_PACMAN" "$BUNDLE_DIR/apt_packages.txt"
        HAS_APT=$(wc -l < "$BUNDLE_DIR/apt_packages.txt")
    else
        cp "$TEMP_SEL_PACMAN" "$BUNDLE_DIR/pacman_packages.txt"
        HAS_PACMAN=$(wc -l < "$BUNDLE_DIR/pacman_packages.txt")
    fi
fi

if [ -s "$TEMP_SEL_AUR" ]; then
    if [ "$OS_FAMILY" = "debian" ]; then
        cp "$TEMP_SEL_AUR" "$BUNDLE_DIR/snap_packages.txt"
        HAS_SNAP=$(wc -l < "$BUNDLE_DIR/snap_packages.txt")
    else
        cp "$TEMP_SEL_AUR" "$BUNDLE_DIR/aur_packages.txt"
        HAS_AUR=$(wc -l < "$BUNDLE_DIR/aur_packages.txt")
    fi
fi

if [ -s "$TEMP_SEL_FLATPAK" ]; then
    cp "$TEMP_SEL_FLATPAK" "$BUNDLE_DIR/flatpak_packages.txt"
    HAS_FLATPAK=$(wc -l < "$BUNDLE_DIR/flatpak_packages.txt")
fi

if [ -s "$TEMP_SEL_APPIMAGE" ] && [ -d "$SOURCE_DIR/appimages" ]; then
    mkdir -p "$BUNDLE_DIR/appimages/desktop_entries"
    cp "$TEMP_SEL_APPIMAGE" "$BUNDLE_DIR/appimages_list.txt"
    while read -r app_name; do
        [ -n "$app_name" ] || continue
        if [ -f "$SOURCE_DIR/appimages/$app_name" ]; then
            cp "$SOURCE_DIR/appimages/$app_name" "$BUNDLE_DIR/appimages/"
            chmod +x "$BUNDLE_DIR/appimages/$app_name"
        fi
        if [ -d "$SOURCE_DIR/appimages/desktop_entries" ]; then
            for df in "$SOURCE_DIR/appimages/desktop_entries"/*.desktop; do
                if grep -Fq "$app_name" "$df" 2>/dev/null; then
                    cp "$df" "$BUNDLE_DIR/appimages/desktop_entries/" 2>/dev/null || true
                fi
            done
        fi
    done < "$TEMP_SEL_APPIMAGE"
    HAS_APPIMAGE=$(wc -l < "$BUNDLE_DIR/appimages_list.txt")
fi

# Copiar clasificación si existe
[ -f "$SOURCE_DIR/classified_apps.txt" ] && cp "$SOURCE_DIR/classified_apps.txt" "$BUNDLE_DIR/"

# Copiar scripts ejecutables necesarios
cp "$SCRIPT_DIR/install_apps.sh" "$BUNDLE_DIR/"
cp "$SCRIPT_DIR/restore_apps.sh" "$BUNDLE_DIR/"
cp "$SCRIPT_DIR/restore_tui.py" "$BUNDLE_DIR/"
chmod +x "$BUNDLE_DIR/install_apps.sh" "$BUNDLE_DIR/restore_apps.sh" "$BUNDLE_DIR/restore_tui.py"

# Generar metadata del instalador
cat <<EOF > "$BUNDLE_DIR/installer_info.json"
{
  "type": "custom_installer",
  "name": "$BUNDLE_NAME",
  "title": "$BUNDLE_TITLE",
  "author": "$BUNDLE_AUTHOR",
  "description": "$BUNDLE_DESC",
  "created_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "timestamp": $(date +%s),
  "os_family": "$OS_FAMILY",
  "has_dotfiles": false,
  "has_appimages": $(if [ "$HAS_APPIMAGE" -gt 0 ]; then echo true; else echo false; fi),
  "counts": {
    "pacman": $HAS_PACMAN,
    "aur": $HAS_AUR,
    "apt": $HAS_APT,
    "snap": $HAS_SNAP,
    "flatpak": $HAS_FLATPAK,
    "appimage": $HAS_APPIMAGE
  }
}
EOF

# También guardar backup_info.json para máxima compatibilidad con el selector existente
cp "$BUNDLE_DIR/installer_info.json" "$BUNDLE_DIR/backup_info.json"

echo "Paquete estructurado con éxito."

# Preguntar por compresión tar.gz
echo ""
read -p "¿Desea comprimir el instalador en un archivo .tar.gz para compartirlo fácilmente? [S/n] (Por defecto: Sí): " DO_TAR
DO_TAR="${DO_TAR:-S}"

TAR_PATH=""
if [[ "$DO_TAR" =~ ^[sSyY]$ ]]; then
    TAR_NAME="${BUNDLE_NAME}.tar.gz"
    echo "Comprimiendo $BUNDLE_NAME en $TAR_NAME..."
    (cd "$DEST_BASE" && tar -czf "$TAR_NAME" "$BUNDLE_NAME")
    TAR_PATH="$DEST_BASE/$TAR_NAME"
    echo "-> Creado: $TAR_PATH ($(du -sh "$TAR_PATH" | cut -f1))"
fi

echo ""
echo "=========================================================="
echo "          ¡INSTALADOR PERSONALIZADO LISTO!                "
echo "=========================================================="
echo "  Directorio : $BUNDLE_DIR"
[ -n "$TAR_PATH" ] && echo "  Comprimido : $TAR_PATH"
echo "  Contenido  : Pacman: $HAS_PACMAN | AUR: $HAS_AUR | APT: $HAS_APT | Flatpaks: $HAS_FLATPAK | AppImages: $HAS_APPIMAGE"
echo "----------------------------------------------------------"
echo "Instrucciones para compartir con otra persona o máquina:"
if [ -n "$TAR_PATH" ]; then
    echo "1. Envía el archivo '$TAR_NAME'."
    echo "2. En la máquina destino, extraer y ejecutar:"
    echo "   tar -xzf $TAR_NAME"
    echo "   cd $BUNDLE_NAME"
    echo "   ./install_apps.sh"
else
    echo "1. Envía la carpeta '$BUNDLE_NAME'."
    echo "2. En la máquina destino, ejecutar:"
    echo "   cd $BUNDLE_NAME && ./install_apps.sh"
fi
echo "=========================================================="
