package app

import "core:c"
import rl "vendor:raylib"
import "../../third-party/imgui"

TARGET_FPS :: 0

running: bool

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
	io.ConfigFlags |= {.NavEnableKeyboard, .DockingEnable}
	file_browser_init()

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

Shutdown :: proc() {
	delete(latest_path)
	latest_path = ""
	file_browser_shutdown()
	if !rl.IsWindowReady() {
		return
	}
	imgui.Raylib_Shutdown()
	rl.CloseWindow()
	running = false
}
