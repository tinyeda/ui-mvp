package app

import "core:c"
import "vendor:raylib"
import "../../third-party/imgui"

TARGET_FPS :: 0
UI_FONT_SIZE :: 16.0
UI_FONT_DATA :: #load("../../third-party/fonts/atkinson-hyperlegible-next/AtkinsonHyperlegibleNext-Regular.ttf")

app_running: bool

load_ui_font :: proc(io: ^imgui.IO) -> bool {
	// ImGui takes ownership of memory passed without a FontConfig. Give it a
	// copy from its own allocator so it can safely retain and free the data.
	font_memory := imgui.MemAlloc(uint(len(UI_FONT_DATA)))
	if font_memory == nil {
		return false
	}
	font_bytes := ([^]byte)(font_memory)[:len(UI_FONT_DATA)]
	copy(font_bytes, UI_FONT_DATA)
	font := imgui.FontAtlas_AddFontFromMemoryTTF(
		io.Fonts,
		font_memory,
		i32(len(UI_FONT_DATA)),
		UI_FONT_SIZE,
	)
	if font == nil {
		return false
	}
	io.FontDefault = font
	return true
}

init :: proc() -> bool {
	config_flags: raylib.ConfigFlags = {.WINDOW_RESIZABLE}
	when ODIN_OS != .JS {
		config_flags += {.WINDOW_HIGHDPI}
	}
	raylib.SetConfigFlags(config_flags)
	raylib.InitWindow(1280, 720, "TinyEDA")
	if !raylib.IsWindowReady() {
		return false
	}
	raylib.SetTargetFPS(TARGET_FPS)

	imgui.Raylib_Setup(true)
	io := imgui.GetIO()
	load_ui_font(io)
	ui_scale_init()
	io.ConfigFlags |= {.NavEnableKeyboard, .DockingEnable}
	io.IniFilename = nil
	io.IniSavingRate = 1.0
	file_browser_init()
	workspace_init()

	app_running = true
	return true
}

frame :: proc() {
	raylib.BeginDrawing()
	raylib.ClearBackground(raylib.Color{20, 22, 26, 255})

	imgui.Raylib_Begin()
	draw_ui()
	imgui.Raylib_End()

	raylib.EndDrawing()
	workspace_update()
	free_all(context.temp_allocator)
}

is_running :: proc() -> bool {
	when ODIN_OS != .JS {
		if raylib.WindowShouldClose() {
			app_running = false
		}
	}
	return app_running
}

resize_window :: proc(width, height: int, display_scale: f32 = 1.0) {
	if width > 0 && height > 0 {
		raylib.SetWindowSize(c.int(width), c.int(height))
		ui_display_scale_set(display_scale)
	}
}

flush_workspace :: proc() {
	workspace_flush()
}

shutdown :: proc() {
	delete(latest_path)
	latest_path = ""
	workspace_shutdown()
	text_editor_shutdown()
	panels_shutdown()
	file_browser_shutdown()
	if !raylib.IsWindowReady() {
		return
	}
	imgui.Raylib_Shutdown()
	raylib.CloseWindow()
	app_running = false
}
