package app

import "core:fmt"
import "../../third-party/imgui"

PanelKind :: enum {
	WELCOME,
	PROJECT_EXPLORER,
	TEXT_EDITOR,
	SCHEMATIC,
	LAYOUT,
	CONSOLE,
}

PANEL_KINDS :: [?]PanelKind{
	.WELCOME,
	.PROJECT_EXPLORER,
	.TEXT_EDITOR,
	.SCHEMATIC,
	.LAYOUT,
	.CONSOLE,
}

Panel :: struct {
	id:        u64,
	kind:      PanelKind,
	open:      bool,
	dock_once: bool,
}

panels: [dynamic]Panel
next_panel_id: u64 = 1

panels_init :: proc() {
	panel_add(.WELCOME)
	panel_add(.PROJECT_EXPLORER)
}

panels_shutdown :: proc() {
	delete(panels)
	panels = nil
	next_panel_id = 1
}

panel_title :: proc(kind: PanelKind) -> string {
	switch kind {
	case .WELCOME:          return "Welcome"
	case .PROJECT_EXPLORER: return "Project Explorer"
	case .TEXT_EDITOR:      return "Text Editor"
	case .SCHEMATIC:        return "Schematic"
	case .LAYOUT:           return "Layout"
	case .CONSOLE:          return "Console"
	}
	return "Panel"
}

panel_is_singleton :: proc(kind: PanelKind) -> bool {
	return kind == .PROJECT_EXPLORER || kind == .TEXT_EDITOR
}

panel_exists :: proc(kind: PanelKind) -> bool {
	for panel in panels {
		if panel.kind == kind && panel.open {
			return true
		}
	}
	return false
}

panel_add :: proc(kind: PanelKind) {
	if panel_is_singleton(kind) && panel_exists(kind) {
		return
	}
	append(&panels, Panel{
		id = next_panel_id,
		kind = kind,
		open = true,
		dock_once = true,
	})
	next_panel_id += 1
	workspace_mark_dirty()
}

panel_add_menu_item :: proc(kind: PanelKind) {
	enabled := !panel_is_singleton(kind) || !panel_exists(kind)
	if imgui.MenuItem(fb_cstr(panel_title(kind)), nil, false, enabled) {
		panel_add(kind)
	}
}

panels_draw_add_menu :: proc() {
	for kind in PANEL_KINDS {
		panel_add_menu_item(kind)
	}
}

panels_draw_menu :: proc() {
	if !imgui.BeginMainMenuBar() {
		return
	}
	if imgui.BeginMenu("+") {
		panels_draw_add_menu()
		imgui.EndMenu()
	}
	if imgui.BeginMenu("Panels") {
		panels_draw_add_menu()
		imgui.EndMenu()
	}
	imgui.EndMainMenuBar()
}

panel_draw_contents :: proc(panel: ^Panel) {
	switch panel.kind {
	case .WELCOME:
		imgui.Text("Welcome to TinyEDA")
		if imgui.Button("Open File") { file_browser_open(.PICK_FILE) }
		imgui.SameLine(); if imgui.Button("Select Folder") { file_browser_open(.PICK_FOLDER) }
		imgui.SameLine(); if imgui.Button("Save As") { file_browser_open(.SAVE_FILE) }
		if len(latest_path) > 0 { imgui.Text("Latest: %s", fb_cstr(latest_path)) }
	case .PROJECT_EXPLORER:
		file_browser_draw_explorer_contents()
	case .TEXT_EDITOR:
		text_editor_draw()
	case .SCHEMATIC:
		imgui.TextUnformatted("Schematic view")
		imgui.Separator()
		imgui.TextUnformatted("The schematic editor will be rendered here.")
	case .LAYOUT:
		imgui.TextUnformatted("Layout view")
		imgui.Separator()
		imgui.TextUnformatted("The physical layout editor will be rendered here.")
	case .CONSOLE:
		imgui.TextUnformatted("Console")
		imgui.Separator()
		imgui.TextUnformatted("Tool output and commands will be shown here.")
	}
}

panel_draw :: proc(panel: ^Panel, dockspace_id: imgui.ID) {
	if panel.dock_once {
		imgui.SetNextWindowDockID(dockspace_id, .FirstUseEver)
		panel.dock_once = false
	}
	window_name := fmt.tprintf("%s###panel_%d\x00", panel_title(panel.kind), panel.id)
	if imgui.Begin(cstring(raw_data(window_name)), &panel.open, {}) {
		panel_draw_contents(panel)
	}
	imgui.End()
}

panels_draw :: proc(dockspace_id: imgui.ID) {
	for i in 0 ..< len(panels) {
		panel_draw(&panels[i], dockspace_id)
	}

	for i := len(panels) - 1; i >= 0; i -= 1 {
		if !panels[i].open {
			ordered_remove(&panels, i)
			workspace_mark_dirty()
		}
	}
}
