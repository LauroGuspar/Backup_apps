#!/usr/bin/env python3
import sys
import os
import curses

def load_pkgs(filepath):
    if not os.path.exists(filepath):
        return []
    with open(filepath, "r") as f:
        return [line.strip() for line in f if line.strip()]

def save_pkgs(filepath, all_pkgs, selected_set):
    with open(filepath, "w") as f:
        for p in all_pkgs:
            if p in selected_set:
                f.write(f"{p}\n")

def run_select_screen(stdscr, all_pkgs, selected_set, title):
    query = ""
    list_index = 0
    scroll_offset = 0
    
    while True:
        stdscr.clear()
        height, width = stdscr.getmaxyx()
        
        if height < 15 or width < 60:
            stdscr.addstr(0, 0, "Ventana demasiado pequena. Por favor, agranda la terminal.")
            stdscr.refresh()
            stdscr.getch()
            continue
            
        filtered_pkgs = [p for p in all_pkgs if query.lower() in p.lower()]
        
        if not filtered_pkgs:
            list_index = 0
        elif list_index >= len(filtered_pkgs):
            list_index = len(filtered_pkgs) - 1
            
        # Draw border
        stdscr.attron(curses.color_pair(2) | curses.A_BOLD)
        stdscr.border()
        stdscr.attroff(curses.color_pair(2) | curses.A_BOLD)
        
        # Title (no emojis/stickers)
        stdscr.addstr(1, 2, f" {title} ", curses.color_pair(2) | curses.A_BOLD | curses.A_REVERSE)
        
        # Search Box
        stdscr.addstr(3, 2, "Buscar: ", curses.A_BOLD)
        stdscr.addstr(3, 10, f"[{query}]", curses.color_pair(2))
        
        list_width = int(width * 0.55)
        sidebar_start = list_width + 4
        list_height = height - 7
        
        # Vertical divider line
        for y in range(5, height - 2):
            stdscr.addch(y, sidebar_start - 2, curses.ACS_VLINE, curses.color_pair(2))
            
        # Draw List
        for i in range(list_height):
            idx = i + scroll_offset
            if idx >= len(filtered_pkgs):
                break
            pkg = filtered_pkgs[idx]
            is_selected = pkg in selected_set
            is_highlighted = idx == list_index
            
            y_pos = 5 + i
            if is_highlighted:
                # Highlight the whole row
                checkbox = "[X]" if is_selected else "[ ]"
                display_str = f" {checkbox} {pkg}"
                display_str = display_str[:list_width - 4].ljust(list_width - 4)
                stdscr.attron(curses.color_pair(1) | curses.A_BOLD)
                stdscr.addstr(y_pos, 2, display_str)
                stdscr.attroff(curses.color_pair(1) | curses.A_BOLD)
            else:
                # Normal print with green inner X if selected
                stdscr.addstr(y_pos, 2, " [")
                if is_selected:
                    stdscr.addstr(y_pos, 4, "X", curses.color_pair(3) | curses.A_BOLD)
                else:
                    stdscr.addstr(y_pos, 4, " ")
                stdscr.addstr(y_pos, 5, f"] {pkg[:list_width-7]}")
                
        # Scroll adjustment
        if list_index < scroll_offset:
            scroll_offset = list_index
        elif list_index >= scroll_offset + list_height:
            scroll_offset = list_index - list_height + 1
            
        # Draw Sidebar
        sb_y = 5
        stdscr.addstr(sb_y, sidebar_start, "ACCIONES:", curses.A_BOLD | curses.A_UNDERLINE)
        stdscr.addstr(sb_y + 2, sidebar_start, "[Ctrl+A] ", curses.color_pair(3) | curses.A_BOLD)
        stdscr.addstr(sb_y + 2, sidebar_start + 9, "Marcar Todo Visible")
        stdscr.addstr(sb_y + 3, sidebar_start, "[Ctrl+X] ", curses.color_pair(4) | curses.A_BOLD)
        stdscr.addstr(sb_y + 3, sidebar_start + 9, "Desmarcar Todo Visible")
        stdscr.addstr(sb_y + 5, sidebar_start, "[ENTER]  ", curses.color_pair(2) | curses.A_BOLD)
        stdscr.addstr(sb_y + 5, sidebar_start + 9, "Guardar y Regresar")
        stdscr.addstr(sb_y + 6, sidebar_start, "[ESC]    ", curses.color_pair(4) | curses.A_BOLD)
        stdscr.addstr(sb_y + 6, sidebar_start + 9, "Descartar y Regresar")
        
        stdscr.addstr(sb_y + 9, sidebar_start, "Teclas de control:", curses.A_BOLD)
        stdscr.addstr(sb_y + 10, sidebar_start, "• Flechas Up/Down: Navegar")
        stdscr.addstr(sb_y + 11, sidebar_start, "• Espacio: Marcar/Desmarcar")
        stdscr.addstr(sb_y + 12, sidebar_start, "• Escribe para filtrar")
        stdscr.addstr(sb_y + 13, sidebar_start, "• Retroceso para borrar")
        
        sel_count = len([p for p in all_pkgs if p in selected_set])
        status_bar = f" Seleccionados: {sel_count}/{len(all_pkgs)} | Filtrados: {len(filtered_pkgs)} "
        stdscr.addstr(height - 2, 2, status_bar.ljust(width - 5), curses.A_REVERSE)
        
        stdscr.refresh()
        
        ch = stdscr.getch()
        if ch == 27:
            stdscr.nodelay(True)
            next_ch = stdscr.getch()
            stdscr.nodelay(False)
            if next_ch == -1:
                return False  # Exit and discard
        elif ch in (8, 127, 263, curses.KEY_BACKSPACE):
            if len(query) > 0:
                query = query[:-1]
                list_index = 0
                scroll_offset = 0
        elif ch in (10, 13, curses.KEY_ENTER):
            return True  # Exit and save
        elif ch == ord(' '):
            if filtered_pkgs:
                pkg = filtered_pkgs[list_index]
                if pkg in selected_set:
                    selected_set.remove(pkg)
                else:
                    selected_set.add(pkg)
        elif ch == 1:  # Ctrl+A
            for p in filtered_pkgs:
                selected_set.add(p)
        elif ch == 24:  # Ctrl+X
            for p in filtered_pkgs:
                if p in selected_set:
                    selected_set.remove(p)
        elif ch == curses.KEY_UP:
            if list_index > 0:
                list_index -= 1
        elif ch == curses.KEY_DOWN:
            if list_index < len(filtered_pkgs) - 1:
                list_index += 1
        elif 32 <= ch <= 126:
            query += chr(ch)
            list_index = 0
            scroll_offset = 0

def run_global_search(stdscr, pacman_pkgs, selected_pacman, aur_pkgs, selected_aur):
    query = ""
    list_index = 0
    scroll_offset = 0
    
    while True:
        stdscr.clear()
        height, width = stdscr.getmaxyx()
        
        if height < 15 or width < 60:
            stdscr.addstr(0, 0, "Ventana demasiado pequena. Por favor, agranda la terminal.")
            stdscr.refresh()
            stdscr.getch()
            continue
            
        matches = []
        for p in pacman_pkgs:
            if query.lower() in p.lower():
                matches.append((p, "pacman"))
        for p in aur_pkgs:
            if query.lower() in p.lower():
                matches.append((p, "aur"))
                
        if not matches:
            list_index = 0
        elif list_index >= len(matches):
            list_index = len(matches) - 1
            
        # Draw border
        stdscr.attron(curses.color_pair(2) | curses.A_BOLD)
        stdscr.border()
        stdscr.attroff(curses.color_pair(2) | curses.A_BOLD)
        
        # Title (no emojis/stickers)
        stdscr.addstr(1, 2, " BUSCADOR GLOBAL (Pacman + AUR) ", curses.color_pair(2) | curses.A_BOLD | curses.A_REVERSE)
        
        # Search Box
        stdscr.addstr(3, 2, "Buscar: ", curses.A_BOLD)
        stdscr.addstr(3, 10, f"[{query}]", curses.color_pair(2))
        
        list_width = int(width * 0.55)
        sidebar_start = list_width + 4
        list_height = height - 7
        
        # Vertical divider line
        for y in range(5, height - 2):
            stdscr.addch(y, sidebar_start - 2, curses.ACS_VLINE, curses.color_pair(2))
            
        # Draw List
        for i in range(list_height):
            idx = i + scroll_offset
            if idx >= len(matches):
                break
            pkg, repo = matches[idx]
            is_selected = pkg in (selected_pacman if repo == "pacman" else selected_aur)
            is_highlighted = idx == list_index
            
            repo_label = "[Pacman]" if repo == "pacman" else "[AUR]"
            y_pos = 5 + i
            if is_highlighted:
                checkbox = "[X]" if is_selected else "[ ]"
                display_str = f" {checkbox} {pkg}  {repo_label}"
                display_str = display_str[:list_width - 4].ljust(list_width - 4)
                stdscr.attron(curses.color_pair(1) | curses.A_BOLD)
                stdscr.addstr(y_pos, 2, display_str)
                stdscr.attroff(curses.color_pair(1) | curses.A_BOLD)
            else:
                stdscr.addstr(y_pos, 2, " [")
                if is_selected:
                    stdscr.addstr(y_pos, 4, "X", curses.color_pair(3) | curses.A_BOLD)
                else:
                    stdscr.addstr(y_pos, 4, " ")
                stdscr.addstr(y_pos, 5, f"] {pkg[:list_width-17]}  {repo_label}")
                
        if list_index < scroll_offset:
            scroll_offset = list_index
        elif list_index >= scroll_offset + list_height:
            scroll_offset = list_index - list_height + 1
            
        # Draw Sidebar
        sb_y = 5
        stdscr.addstr(sb_y, sidebar_start, "ACCIONES:", curses.A_BOLD | curses.A_UNDERLINE)
        stdscr.addstr(sb_y + 2, sidebar_start, "[Ctrl+A] ", curses.color_pair(3) | curses.A_BOLD)
        stdscr.addstr(sb_y + 2, sidebar_start + 9, "Marcar Todo Visible")
        stdscr.addstr(sb_y + 3, sidebar_start, "[Ctrl+X] ", curses.color_pair(4) | curses.A_BOLD)
        stdscr.addstr(sb_y + 3, sidebar_start + 9, "Desmarcar Todo Visible")
        stdscr.addstr(sb_y + 5, sidebar_start, "[ENTER]  ", curses.color_pair(2) | curses.A_BOLD)
        stdscr.addstr(sb_y + 5, sidebar_start + 9, "Guardar y Regresar")
        stdscr.addstr(sb_y + 6, sidebar_start, "[ESC]    ", curses.color_pair(4) | curses.A_BOLD)
        stdscr.addstr(sb_y + 6, sidebar_start + 9, "Descartar y Regresar")
        
        stdscr.addstr(sb_y + 9, sidebar_start, "Teclas de control:", curses.A_BOLD)
        stdscr.addstr(sb_y + 10, sidebar_start, "• Flechas Up/Down: Navegar")
        stdscr.addstr(sb_y + 11, sidebar_start, "• Espacio: Marcar/Desmarcar")
        stdscr.addstr(sb_y + 12, sidebar_start, "• Escribe para filtrar")
        stdscr.addstr(sb_y + 13, sidebar_start, "• Retroceso para borrar")
        
        status_bar = f" Coincidencias encontradas: {len(matches)} "
        stdscr.addstr(height - 2, 2, status_bar.ljust(width - 5), curses.A_REVERSE)
        
        stdscr.refresh()
        
        ch = stdscr.getch()
        if ch == 27:
            stdscr.nodelay(True)
            next_ch = stdscr.getch()
            stdscr.nodelay(False)
            if next_ch == -1:
                return False
        elif ch in (8, 127, 263, curses.KEY_BACKSPACE):
            if len(query) > 0:
                query = query[:-1]
                list_index = 0
                scroll_offset = 0
        elif ch in (10, 13, curses.KEY_ENTER):
            return True
        elif ch == ord(' '):
            if matches:
                pkg, repo = matches[list_index]
                sel_set = selected_pacman if repo == "pacman" else selected_aur
                if pkg in sel_set:
                    sel_set.remove(pkg)
                else:
                    sel_set.add(pkg)
        elif ch == 1:  # Ctrl+A
            for p, repo in matches:
                sel_set = selected_pacman if repo == "pacman" else selected_aur
                sel_set.add(p)
        elif ch == 24:  # Ctrl+X
            for p, repo in matches:
                sel_set = selected_pacman if repo == "pacman" else selected_aur
                if p in sel_set:
                    sel_set.remove(p)
        elif ch == curses.KEY_UP:
            if list_index > 0:
                list_index -= 1
        elif ch == curses.KEY_DOWN:
            if list_index < len(matches) - 1:
                list_index += 1
        elif 32 <= ch <= 126:
            query += chr(ch)
            list_index = 0
            scroll_offset = 0

def main_menu(stdscr, respaldo_dir, temp_pacman, temp_aur, temp_flatpak, dotfiles_state_file):
    curses.start_color()
    curses.use_default_colors()
    curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_CYAN)
    curses.init_pair(2, curses.COLOR_CYAN, -1)
    curses.init_pair(3, curses.COLOR_GREEN, -1)
    curses.init_pair(4, curses.COLOR_RED, -1)
    curses.curs_set(0)
    
    pacman_all = load_pkgs(os.path.join(respaldo_dir, "pacman_packages.txt"))
    aur_all = load_pkgs(os.path.join(respaldo_dir, "aur_packages.txt"))
    flatpak_all = load_pkgs(os.path.join(respaldo_dir, "flatpak_packages.txt"))
    has_dotfiles = os.path.exists(os.path.join(respaldo_dir, "dotfiles_config.tar.gz"))
    
    selected_pacman = set(load_pkgs(temp_pacman)) if os.path.exists(temp_pacman) and os.path.getsize(temp_pacman) > 0 else set(pacman_all)
    selected_aur = set(load_pkgs(temp_aur)) if os.path.exists(temp_aur) and os.path.getsize(temp_aur) > 0 else set(aur_all)
    selected_flatpak = set(load_pkgs(temp_flatpak)) if os.path.exists(temp_flatpak) and os.path.getsize(temp_flatpak) > 0 else set(flatpak_all)
    
    restore_dotfiles = "SI"
    if os.path.exists(dotfiles_state_file):
        with open(dotfiles_state_file, "r") as f:
            restore_dotfiles = f.read().strip()
            
    menu_index = 0
    
    while True:
        menu_items = [
            ("pacman", f"Paquetes Oficiales Pacman    ({len(selected_pacman & set(pacman_all))}/{len(pacman_all)})"),
            ("aur",    f"Paquetes de AUR (Foreign)    ({len(selected_aur & set(aur_all))}/{len(aur_all)})")
        ]
        
        if flatpak_all:
            menu_items.append(("flatpak", f"Aplicaciones Flatpak         ({len(selected_flatpak & set(flatpak_all))}/{len(flatpak_all)})"))
            
        if has_dotfiles:
            menu_items.append(("dotfiles", f"Restaurar Configs ~/.config  ({restore_dotfiles})"))
            
        menu_items.append(("search", "Buscar en todos los paquetes (Pacman/AUR)"))
        menu_items.append(("install", "INICIAR INSTALACION Y RESTAURACION"))
        menu_items.append(("exit", "Salir sin instalar"))
        
        if menu_index >= len(menu_items):
            menu_index = len(menu_items) - 1
            
        stdscr.clear()
        height, width = stdscr.getmaxyx()
        
        if height < 15 or width < 60:
            stdscr.addstr(0, 0, "Ventana demasiado pequena. Por favor, agranda la terminal.")
            stdscr.refresh()
            stdscr.getch()
            continue
            
        # Draw border
        stdscr.attron(curses.color_pair(2) | curses.A_BOLD)
        stdscr.border()
        stdscr.attroff(curses.color_pair(2) | curses.A_BOLD)
        
        # Title (no emojis/stickers)
        stdscr.addstr(1, 2, " ASISTENTE DE RESTAURACION ", curses.color_pair(2) | curses.A_BOLD | curses.A_REVERSE)
        
        stdscr.addstr(3, 2, "Configura que programas y configuraciones quieres restaurar:", curses.A_BOLD)
        
        # Draw menu items
        for i, (key, label) in enumerate(menu_items):
            y_pos = 5 + i
            is_highlighted = i == menu_index
            
            prefix = " > " if is_highlighted else "   "
            display_str = f"{prefix}{label}"
            
            if is_highlighted:
                stdscr.attron(curses.color_pair(1) | curses.A_BOLD)
                stdscr.addstr(y_pos, 2, display_str.ljust(width - 4)[:width - 4])
                stdscr.attroff(curses.color_pair(1) | curses.A_BOLD)
            else:
                stdscr.addstr(y_pos, 2, display_str[:width - 4])
                
        stdscr.addstr(height - 3, 2, "• Navega con Flechas Arriba/Abajo y presiona [ENTER] para seleccionar.", curses.A_DIM)
        stdscr.addstr(height - 2, 2, "• Puedes usar [ESC] para salir del asistente en cualquier momento.", curses.A_DIM)
        
        stdscr.refresh()
        
        ch = stdscr.getch()
        if ch == 27:
            stdscr.nodelay(True)
            next_ch = stdscr.getch()
            stdscr.nodelay(False)
            if next_ch == -1:
                return 1
        elif ch == curses.KEY_UP:
            if menu_index > 0:
                menu_index -= 1
        elif ch == curses.KEY_DOWN:
            if menu_index < len(menu_items) - 1:
                menu_index += 1
        elif ch in (10, 13, curses.KEY_ENTER):
            key, label = menu_items[menu_index]
            
            if key == "pacman":
                temp_set = set(selected_pacman)
                if run_select_screen(stdscr, pacman_all, temp_set, "Seleccionar Paquetes Pacman"):
                    selected_pacman = temp_set
            elif key == "aur":
                temp_set = set(selected_aur)
                if run_select_screen(stdscr, aur_all, temp_set, "Seleccionar Paquetes AUR"):
                    selected_aur = temp_set
            elif key == "flatpak":
                temp_set = set(selected_flatpak)
                if run_select_screen(stdscr, flatpak_all, temp_set, "Seleccionar Aplicaciones Flatpak"):
                    selected_flatpak = temp_set
            elif key == "dotfiles":
                restore_dotfiles = "NO" if restore_dotfiles == "SI" else "SI"
            elif key == "search":
                run_global_search(stdscr, pacman_all, selected_pacman, aur_all, selected_aur)
            elif key == "install":
                save_pkgs(temp_pacman, pacman_all, selected_pacman)
                save_pkgs(temp_aur, aur_all, selected_aur)
                if flatpak_all:
                    save_pkgs(temp_flatpak, flatpak_all, selected_flatpak)
                with open(dotfiles_state_file, "w") as f:
                    f.write(restore_dotfiles + "\n")
                return 0
            elif key == "exit":
                return 1

if __name__ == "__main__":
    if len(sys.argv) < 6:
        print("Usage: restore_tui.py <respaldo_dir> <temp_pacman> <temp_aur> <temp_flatpak> <dotfiles_state_file>")
        sys.exit(1)
        
    respaldo_dir = sys.argv[1]
    temp_pacman = sys.argv[2]
    temp_aur = sys.argv[3]
    temp_flatpak = sys.argv[4]
    dotfiles_state_file = sys.argv[5]
    
    try:
        ret = curses.wrapper(main_menu, respaldo_dir, temp_pacman, temp_aur, temp_flatpak, dotfiles_state_file)
        sys.exit(ret)
    except KeyboardInterrupt:
        sys.exit(1)
