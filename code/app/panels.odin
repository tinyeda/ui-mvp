package app

import "core:fmt"
import "../../third-party/imgui"

Panel_Kind :: enum {
	Welcome,
	Project_Explorer,
	Text_Editor,
	Schematic,
	Layout,
	Console,
}

PANEL_KINDS :: [?]Panel_Kind{
	.Welcome,
	.Project_Explorer,
	.Text_Editor,
	.Schematic,
	.Layout,
	.Console,
}

Panel :: struct {
	id:        u64,
	kind:      Panel_Kind,
	open:      bool,
	dock_once: bool,
}

panels: [dynamic]Panel
next_panel_id: u64 = 1

panels_init :: proc() {
	panel_add(.Welcome)
	panel_add(.Project_Explorer)
}

panels_shutdown :: proc() {
	delete(panels)
	panels = nil
	next_panel_id = 1
}

panel_title :: proc(kind: Panel_Kind) -> string {
	switch kind {
	case .Welcome:          return "Welcome"
	case .Project_Explorer: return "Project Explorer"
	case .Text_Editor:      return "Text Editor"
	case .Schematic:        return "Schematic"
	case .Layout:           return "Layout"
	case .Console:          return "Console"
	}
	return "Panel"
}

panel_is_singleton :: proc(kind: Panel_Kind) -> bool {
	return kind == .Project_Explorer || kind == .Text_Editor
}

panel_exists :: proc(kind: Panel_Kind) -> bool {
	for panel in panels {
		if panel.kind == kind && panel.open {
			return true
		}
	}
	return false
}

panel_add :: proc(kind: Panel_Kind) {
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

panel_add_menu_item :: proc(kind: Panel_Kind) {
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
	case .Welcome:
		imgui.Text("Welcome to TinyEDA")
		if imgui.Button("Open File") { File_Browser_Open(.Pick_File) }
		imgui.SameLine(); if imgui.Button("Select Folder") { File_Browser_Open(.Pick_Folder) }
		imgui.SameLine(); if imgui.Button("Save As") { File_Browser_Open(.Save_File) }
		if len(latest_path) > 0 { imgui.Text("Latest: %s", fb_cstr(latest_path)) }
	case .Project_Explorer:
		File_Browser_Draw_Explorer_Contents()
	case .Text_Editor:
		text_editor_draw()
	case .Schematic:
		imgui.TextUnformatted("Schematic view")
		imgui.Separator()
		imgui.TextUnformatted("The schematic editor will be rendered here.")
	case .Layout:
		imgui.TextUnformatted("Layout view")
		imgui.Separator()
		imgui.TextUnformatted("The physical layout editor will be rendered here.")
	case .Console:
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
	for i in 0..<len(panels) {
		panel_draw(&panels[i], dockspace_id)
	}

	for i := len(panels) - 1; i >= 0; i -= 1 {
		if !panels[i].open {
			ordered_remove(&panels, i)
			workspace_mark_dirty()
		}
	}
}
