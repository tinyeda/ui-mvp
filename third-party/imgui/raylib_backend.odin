package imgui

import "core:c"
import rl "vendor:raylib"

@(default_calling_convention = "c")
foreign imguilib {
	@(link_name = "rlImGuiSetup")
	Raylib_Setup       :: proc(dark_theme: bool) ---
	@(link_name = "rlImGuiBegin")
	Raylib_Begin       :: proc() ---
	@(link_name = "rlImGuiBeginDelta")
	Raylib_Begin_Delta :: proc(delta_time: f32) ---
	@(link_name = "rlImGuiEnd")
	Raylib_End         :: proc() ---
	@(link_name = "rlImGuiShutdown")
	Raylib_Shutdown    :: proc() ---

	@(link_name = "rlImGuiImage")
	Raylib_Image                    :: proc(texture: ^rl.Texture) ---
	@(link_name = "rlImGuiImageSize")
	Raylib_Image_Size               :: proc(texture: ^rl.Texture, width, height: c.int) ---
	@(link_name = "rlImGuiImageSizeV")
	Raylib_Image_Size_V             :: proc(texture: ^rl.Texture, size: rl.Vector2) ---
	@(link_name = "rlImGuiImageRect")
	Raylib_Image_Rect               :: proc(texture: ^rl.Texture, width, height: c.int, source: rl.Rectangle) ---
	@(link_name = "rlImGuiImageRenderTexture")
	Raylib_Image_Render_Texture     :: proc(texture: ^rl.RenderTexture) ---
	@(link_name = "rlImGuiImageRenderTextureFit")
	Raylib_Image_Render_Texture_Fit :: proc(texture: ^rl.RenderTexture, center: bool) ---
	@(link_name = "rlImGuiImageButton")
	Raylib_Image_Button             :: proc(name: cstring, texture: ^rl.Texture) -> bool ---
	@(link_name = "rlImGuiImageButtonSize")
	Raylib_Image_Button_Size        :: proc(name: cstring, texture: ^rl.Texture, size: rl.Vector2) -> bool ---
}
