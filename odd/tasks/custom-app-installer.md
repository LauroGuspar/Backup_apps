# Feature: Custom App Installer (create_installer.sh & install_apps.sh)

## Objective
Implement a feature to create a clean, standalone, portable application installer ("All-in-one / Shareable profile"):
1. `create_installer.sh`: CLI utility allowing users to build a custom bundle from either the live system or an existing backup in history.
2. Selection of specific apps/flatpaks/appimages via TUI.
3. Creation of an autonomous folder containing only selected items, `install_apps.sh`, `restore_apps.sh`, `restore_tui.py`, and `installer_info.json`.
4. Option to compress into `.tar.gz` ready to send.
5. Branded welcome and seamless installation for the recipient using `./install_apps.sh`.
6. Integration into `backup_apps.sh` and documentation in `README.md`.

## Scope & Constraints
- Privacy-first: Do NOT include sensitive `~/.config` files by default in shared bundles.
- Portability: Standalone execution without requiring the recipient to clone the original repo.
- Compatibility: Support Arch and Debian families, plus universal Flatpak and AppImage packages.

## Implementation Route
- Multi-file implementation across `create_installer.sh`, `install_apps.sh`, `restore_apps.sh`, `restore_tui.py`, `backup_apps.sh`, and `README.md`.
- Route per task: direct inline / delegated direct where appropriate.
- TDD Mode: Disabled / Functional validation checks.

## Task Checklist
- [x] **TASK-1**: Crear lanzador `install_apps.sh` y soporte para metadatos/banner de instalador (`installer_info.json`) en `restore_apps.sh` - Commit `0ad2d66` (RDD: unavailable / runtime antigravity).
- [ ] **TASK-2**: Adaptar `restore_tui.py` para admitir títulos personalizados y modo de empaquetado/selección limpia.

- [ ] **TASK-3**: Implementar script principal `create_installer.sh` (origen desde sistema en vivo o backup previo, empaquetado limpio y compresión `.tar.gz`).
- [ ] **TASK-4**: Integrar opción de acceso a `create_installer.sh` dentro de `backup_apps.sh`.
- [ ] **TASK-5**: Actualizar `README.md` con la guía de creación y distribución de instaladores personalizados, y realizar pruebas de integración de punta a punta.
