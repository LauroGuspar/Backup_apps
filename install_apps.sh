#!/bin/bash
# install_apps.sh - Lanzador de Instalación y Restauración de Aplicaciones
# Este script inicia el proceso de instalación en el sistema destino.

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

if [ -f "$SCRIPT_DIR/restore_apps.sh" ]; then
    exec bash "$SCRIPT_DIR/restore_apps.sh" "$@"
else
    echo "Error: No se encontró el script de restauración 'restore_apps.sh' en $SCRIPT_DIR"
    exit 1
fi
