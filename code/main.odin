package main

import rl "vendor:raylib"
import "../third-party/imgui"

TARGET_FPS :: 0

draw_ui :: proc() {
	imgui.DockSpaceOverViewport()

	if imgui.Begin("TinyEDA", nil, {}) {
		imgui.Text("Welcome to TinyEDA")
		imgui.Separator()
		imgui.Text("Raylib provides the platform and renderer layer")
		imgui.SeparatorText("Performance")
		imgui.Text("FPS: %d", rl.GetFPS())
		imgui.Text("Frame time: %.2f ms", f64(rl.GetFrameTime()) * 1000)
		imgui.Text("Target FPS: %d", TARGET_FPS)
	}
	imgui.End()
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_HIGHDPI, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "TinyEDA")
	if !rl.IsWindowReady() { return }
	defer rl.CloseWindow()
	rl.SetTargetFPS(TARGET_FPS)

	imgui.Raylib_Setup(true)
	defer imgui.Raylib_Shutdown()

	io := imgui.GetIO()
	io.ConfigFlags |= {.NavEnableKeyboard, .DockingEnable}

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{20, 22, 26, 255})

		imgui.Raylib_Begin()
		draw_ui()
		imgui.Raylib_End()
		rl.EndDrawing()
	}
}
