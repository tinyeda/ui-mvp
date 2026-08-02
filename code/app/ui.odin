package app

import "../../third-party/imgui"

latest_path: string

draw_ui :: proc() {
	panels_draw_menu()
	dockspace_id := imgui.DockSpaceOverViewport()

	if result, ok := File_Browser_Take_Result(); ok {
		delete(latest_path)
		latest_path = result
	}

	panels_draw(dockspace_id)
	File_Browser_Draw_Modals()
}
