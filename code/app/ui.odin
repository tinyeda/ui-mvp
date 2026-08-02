package app

import "../../third-party/imgui"

UI_SCALE_MIN :: 0.75
UI_SCALE_MAX :: 2.0
UI_SCALE_STEP :: 0.125

latest_path: string
ui_scale: f32 = 1.0
ui_display_scale: f32 = 1.0
ui_scale_base_style: imgui.Style

ui_scale_init :: proc() {
	ui_scale = 1.0
	ui_display_scale = 1.0
	ui_scale_base_style = imgui.GetStyle()^
}

ui_scale_shortcut :: proc(key: imgui.Key, shift: bool = false) -> bool {
	ctrl_mods := i32(imgui.KEY_MOD_CTRL)
	super_mods := i32(imgui.KEY_MOD_SUPER)
	if shift {
		ctrl_mods |= i32(imgui.KEY_MOD_SHIFT)
		super_mods |= i32(imgui.KEY_MOD_SHIFT)
	}
	flags: imgui.InputFlags = {.RouteGlobal}
	ctrl_pressed := imgui.Shortcut(imgui.KeyChord(ctrl_mods | i32(key)), flags)
	super_pressed := imgui.Shortcut(imgui.KeyChord(super_mods | i32(key)), flags)
	return ctrl_pressed || super_pressed
}

ui_scale_apply :: proc() {
	// Web renders in device pixels, while ui_scale is the user's logical zoom.
	combined_scale := ui_scale * ui_display_scale
	style := imgui.GetStyle()
	style^ = ui_scale_base_style
	imgui.Style_ScaleAllSizes(style, combined_scale)
	style.FontScaleMain = ui_scale_base_style.FontScaleMain * combined_scale
}

ui_scale_set :: proc(scale: f32) {
	new_scale := clamp(scale, UI_SCALE_MIN, UI_SCALE_MAX)
	if new_scale == ui_scale {
		return
	}
	ui_scale = new_scale
	ui_scale_apply()
}

ui_display_scale_set :: proc(scale: f32) {
	new_scale := scale > 0 ? scale : 1.0
	if new_scale == ui_display_scale {
		return
	}
	ui_display_scale = new_scale
	ui_scale_apply()
}

ui_scale_update :: proc() {
	increase := ui_scale_shortcut(.Equal) ||
	            ui_scale_shortcut(.Equal, true) ||
	            ui_scale_shortcut(.KeypadAdd)
	decrease := ui_scale_shortcut(.Minus) || ui_scale_shortcut(.KeypadSubtract)
	reset := ui_scale_shortcut(._0) || ui_scale_shortcut(.Keypad0)

	if increase {
		ui_scale_set(ui_scale + UI_SCALE_STEP)
	} else if decrease {
		ui_scale_set(ui_scale - UI_SCALE_STEP)
	} else if reset {
		ui_scale_set(1.0)
	}
}

draw_ui :: proc() {
	ui_scale_update()
	panels_draw_menu()
	dockspace_id := imgui.DockSpaceOverViewport()

	if result, ok := File_Browser_Take_Result(); ok {
		delete(latest_path)
		latest_path = result
	}

	panels_draw(dockspace_id)
	File_Browser_Draw_Modals()
}
