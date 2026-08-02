package app

import "core:c"
import rl "vendor:raylib"
import "../../third-party/imgui"

TARGET_FPS :: 0
UI_FONT_SIZE :: 16.0
UI_FONT_DATA :: #load("../../third-party/fonts/atkinson-hyperlegible-next/AtkinsonHyperlegibleNext-Regular.ttf")

running: bool

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

Init :: proc() -> bool {
	config_flags: rl.ConfigFlags = {.WINDOW_RESIZABLE}
	when ODIN_OS != .JS {
		config_flags += {.WINDOW_HIGHDPI}
	}
	rl.SetConfigFlags(config_flags)
	rl.InitWindow(1280, 720, "TinyEDA")
	if !rl.IsWindowReady() {
		return false
	}
	rl.SetTargetFPS(TARGET_FPS)

	imgui.Raylib_Setup(true)
	io := imgui.GetIO()
	load_ui_font(io)
	ui_scale_init()
	io.ConfigFlags |= {.NavEnableKeyboard, .DockingEnable}
	io.IniFilename = nil
	io.IniSavingRate = 1.0
	file_browser_init()
	workspace_init()

	running = true
	return true
}

Frame :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{20, 22, 26, 255})

	imgui.Raylib_Begin()
	draw_ui()
	imgui.Raylib_End()

	rl.EndDrawing()
	workspace_update()
	free_all(context.temp_allocator)
}

Running :: proc() -> bool {
	when ODIN_OS != .JS {
		if rl.WindowShouldClose() {
			running = false
		}
	}
	return running
}

Resize :: proc(width, height: int) {
	if width > 0 && height > 0 {
		rl.SetWindowSize(c.int(width), c.int(height))
	}
}

Flush_Workspace :: proc() {
	workspace_flush()
}

Shutdown :: proc() {
	delete(latest_path)
	latest_path = ""
	workspace_shutdown()
	panels_shutdown()
	file_browser_shutdown()
	if !rl.IsWindowReady() {
		return
	}
	imgui.Raylib_Shutdown()
	rl.CloseWindow()
	running = false
}
