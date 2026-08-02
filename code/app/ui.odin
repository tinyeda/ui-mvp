package app

import "../../third-party/imgui"

latest_path: string

draw_ui :: proc() {
	imgui.DockSpaceOverViewport()

	if imgui.Begin("TinyEDA", nil, {}) {
		imgui.Text("Welcome to TinyEDA")
		if imgui.Button("Open File") { File_Browser_Open(.Pick_File) }
		imgui.SameLine(); if imgui.Button("Select Folder") { File_Browser_Open(.Pick_Folder) }
		imgui.SameLine(); if imgui.Button("Save As") { File_Browser_Open(.Save_File) }
		if result, ok := File_Browser_Take_Result(); ok {
			delete(latest_path)
			latest_path = result
		}
		if len(latest_path) > 0 { imgui.Text("Latest: %s", fb_cstr(latest_path)) }
	}
	imgui.End()
	File_Browser_Draw_Explorer()
	File_Browser_Draw_Modals()
}
