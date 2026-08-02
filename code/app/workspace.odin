package app

import "core:encoding/json"
import "core:time"
import "../../third-party/imgui"

WORKSPACE_VERSION :: 1
WORKSPACE_SAVE_DELAY :: time.Second

Workspace_Storage_Kind :: enum i32 {
	Config,
	ImGui,
}

Saved_Panel :: struct {
	id:   i128   `json:"id"`,
	kind: string `json:"kind"`,
}

Workspace_Config :: struct {
	format:        string        `json:"format"`,
	version:       int           `json:"version"`,
	next_panel_id: i128          `json:"next_panel_id"`,
	panel_count:   int           `json:"panel_count"`,
	panels:        []Saved_Panel `json:"panels"`,
}

workspace_dirty: bool
workspace_loading: bool
workspace_save_at: time.Tick

workspace_storage_name :: proc(kind: Workspace_Storage_Kind) -> string {
	switch kind {
	case .Config: return "workspace.json"
	case .ImGui:  return "imgui.ini"
	}
	return "workspace.data"
}

panel_kind_key :: proc(kind: Panel_Kind) -> string {
	switch kind {
	case .Welcome:          return "welcome"
	case .Project_Explorer: return "project_explorer"
	case .Text_Editor:      return "text_editor"
	case .Schematic:        return "schematic"
	case .Layout:           return "layout"
	case .Console:          return "console"
	}
	return ""
}

panel_kind_from_key :: proc(key: string) -> (Panel_Kind, bool) {
	switch key {
	case "welcome":          return .Welcome, true
	case "project_explorer": return .Project_Explorer, true
	case "text_editor":      return .Text_Editor, true
	case "schematic":        return .Schematic, true
	case "layout":           return .Layout, true
	case "console":          return .Console, true
	}
	return {}, false
}

workspace_restore_panels :: proc(data: []byte, dock_once: bool) -> bool {
	config: Workspace_Config
	if unmarshal_err := json.unmarshal(data, &config, allocator = context.temp_allocator); unmarshal_err != nil {
		return false
	}
	if config.format != "tinyeda-workspace" ||
	   config.version != WORKSPACE_VERSION ||
	   config.next_panel_id <= 0 ||
	   config.next_panel_id > i128(max(i64)) ||
	   config.panel_count < 0 ||
	   config.panel_count != len(config.panels) {
		return false
	}

	restored := make([dynamic]Panel, 0, len(config.panels), context.temp_allocator)
	max_id: u64
	for saved in config.panels {
		kind, kind_ok := panel_kind_from_key(saved.kind)
		if !kind_ok || saved.id <= 0 || saved.id > i128(max(i64)) {
			return false
		}
		id := u64(saved.id)
		for panel in restored {
			if panel.id == id || panel_is_singleton(kind) && panel.kind == kind {
				return false
			}
		}
		append(&restored, Panel{
			id = id,
			kind = kind,
			open = true,
			dock_once = dock_once,
		})
		max_id = max(max_id, id)
	}
	if u64(config.next_panel_id) <= max_id {
		return false
	}

	delete(panels)
	panels = make([dynamic]Panel, len(restored))
	copy(panels[:], restored[:])
	next_panel_id = u64(config.next_panel_id)
	return true
}

workspace_config_data :: proc(allocator := context.allocator) -> ([]byte, bool) {
	if next_panel_id == 0 || next_panel_id > u64(max(i64)) {
		return nil, false
	}
	saved_panels := make([]Saved_Panel, len(panels), context.temp_allocator)
	for panel, i in panels {
		if panel.id == 0 || panel.id > u64(max(i64)) {
			return nil, false
		}
		saved_panels[i] = Saved_Panel{i128(panel.id), panel_kind_key(panel.kind)}
	}
	config := Workspace_Config{
		format = "tinyeda-workspace",
		version = WORKSPACE_VERSION,
		next_panel_id = i128(next_panel_id),
		panel_count = len(saved_panels),
		panels = saved_panels,
	}
	data, marshal_err := json.marshal(
		config,
		json.Marshal_Options{spec = .JSON, pretty = true, use_spaces = true, spaces = 2},
		allocator,
	)
	return data, marshal_err == nil
}

workspace_save :: proc() -> bool {
	config_data, config_ok := workspace_config_data(context.temp_allocator)
	if !config_ok { return false }

	ini_size: uint
	ini_cstring := imgui.SaveIniSettingsToMemory(&ini_size)
	ini_data := ([^]byte)(ini_cstring)[:int(ini_size)]
	config_saved := workspace_storage_save(.Config, config_data)
	ini_saved := workspace_storage_save(.ImGui, ini_data)
	return config_saved && ini_saved
}

workspace_mark_dirty :: proc() {
	if workspace_loading { return }
	workspace_dirty = true
	workspace_save_at = time.tick_add(time.tick_now(), WORKSPACE_SAVE_DELAY)
}

workspace_init :: proc() {
	workspace_loading = true
	config_data, config_found := workspace_storage_load(.Config, context.temp_allocator)
	ini_data, ini_found := workspace_storage_load(.ImGui, context.temp_allocator)
	ini_restorable := ini_found && len(ini_data) > 0
	config_restored := config_found && workspace_restore_panels(config_data, !ini_restorable)
	if !config_restored {
		panels_init()
	}
	if ini_restorable {
		imgui.LoadIniSettingsFromMemory(cstring(raw_data(ini_data)), uint(len(ini_data)))
	}
	workspace_loading = false
	if !config_restored || !ini_restorable {
		workspace_mark_dirty()
	}
}

workspace_update :: proc() {
	io := imgui.GetIO()
	if io.WantSaveIniSettings {
		io.WantSaveIniSettings = false
		workspace_dirty = true
		if workspace_save() {
			workspace_dirty = false
		} else {
			workspace_save_at = time.tick_add(time.tick_now(), WORKSPACE_SAVE_DELAY)
		}
	}
	if workspace_dirty && time.tick_diff(workspace_save_at, time.tick_now()) >= 0 {
		if workspace_save() {
			workspace_dirty = false
		} else {
			workspace_save_at = time.tick_add(time.tick_now(), WORKSPACE_SAVE_DELAY)
		}
	}
}

workspace_flush :: proc() {
	if workspace_save() {
		workspace_dirty = false
	}
}

workspace_shutdown :: proc() {
	workspace_flush()
	workspace_loading = false
	workspace_save_at = {}
}
