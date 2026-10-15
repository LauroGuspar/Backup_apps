# Feature: Backup Enhancements

## Objective
Implement enhancements to `backup_apps.sh`, `restore_apps.sh`, and `restore_tui.py`:
1. ESC key fix in `restore_tui.py` (instant response, clean discard, fix global search in-place mutation).
2. Option in `backup_apps.sh` to prompt whether to backup `~/.config` (default: Yes).
3. AppImage detection, optional backup (`appimages/` + `.desktop` integration), and restoration with `chmod +x` and FUSE check.
4. Backup history management: automatic timestamped folder names with optional custom alias, metadata summary (`backup_info.json`), and interactive backup selector in `restore_apps.sh`.
5. Package classification & 3-state cycling filter in `restore_tui.py` using `[TAB]`:
   - State 0 (Default): Solo Aplicaciones (preselected `[X]`).
   - State 1: Solo Dependencias (unselected `[ ]` by default).
   - State 2: Todo (Apps + Dependencies, dependencies tagged as `[Dependencia]`).
6. Update documentation in `README.md` and complete verification.

## Scope & Constraints
- Keep compatibility with both Arch (`pacman` / `aur`) and Debian/Ubuntu (`apt` / `snap`).
- Preserve existing modularity and CLI arguments where applicable.
- Prevent bloat: AppImage backup must be optional and non-destructive.
- No third-party heavy dependencies for TUI (keep Python 3 standard library `curses`).

## Implementation Route
- Small-to-medium multi-file implementation across `restore_tui.py`, `backup_apps.sh`, `restore_apps.sh`, and `README.md`.
- Route per task: direct inline / delegated direct where appropriate.
- TDD Mode: Disabled / Functional validation checks.

## Task Checklist
- [x] **TASK-1**: Corregir tecla ESC y mutación en `restore_tui.py` (ESCDELAY a 25ms, descarte limpio en selector y buscador global) - Commit `94a22bc` (RDD: unavailable / runtime antigravity).
- [x] **TASK-2**: Agregar paso interactivo para respaldar `~/.config` [S/n] en `backup_apps.sh` - Commit `1d9459c` (RDD: unavailable / runtime antigravity).


- [x] **TASK-3**: Detección, respaldo y restauración de AppImages (con accesos `.desktop`, permisos y soporte en TUI) - Commit `a708685` (RDD: unavailable / runtime antigravity).

- [x] **TASK-4**: Sistema de Historial de Respaldos (nombres automáticos/personalizados, metadatos y selector en `restore_apps.sh`) - Commit `73ca480` (RDD: unavailable / runtime antigravity).
- [x] **TASK-5**: Clasificación y filtrado cíclico con `[TAB]` en `restore_tui.py` (Apps vs Dependencias) - Commit `7a26527` (RDD: unavailable / runtime antigravity).
- [x] **TASK-6**: Actualizar `README.md` y realizar pruebas de integración y verificación final - Commit `1a4ed40` (RDD: unavailable / runtime antigravity).

