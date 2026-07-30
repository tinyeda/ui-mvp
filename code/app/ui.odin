package app

import rl "vendor:raylib"
import "../../third-party/imgui"

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
