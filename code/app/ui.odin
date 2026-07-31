package app

import "../../third-party/imgui"

draw_ui :: proc() {
	imgui.DockSpaceOverViewport()

	if imgui.Begin("TinyEDA", nil, {}) {
		imgui.Text("Welcome to TinyEDA")
	}
	imgui.End()
}
