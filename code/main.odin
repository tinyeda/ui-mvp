package main

import "core:c"
import "vendor:glfw"
import "vendor:OpenGL"
import "../third-party/imgui"

framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width, height: c.int) {
	OpenGL.Viewport(0, 0, width, height)
}

main :: proc() {
	if !glfw.Init() {
		return
	}
	defer glfw.Terminate()

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, true)
	glfw.WindowHint(glfw.RESIZABLE, true)

	window := glfw.CreateWindow(1280, 720, "ImGui + Odin", nil, nil)
	if window == nil { return }
	defer glfw.DestroyWindow(window)

	glfw.MakeContextCurrent(window)
	glfw.SwapInterval(1)

	OpenGL.load_up_to(3, 3, glfw.gl_set_proc_address)
	OpenGL.Viewport(0, 0, 1280, 720)
	glfw.SetFramebufferSizeCallback(window, framebuffer_size_callback)

	imgui.CreateContext()
	defer imgui.DestroyContext()

	io := imgui.GetIO()
	io.ConfigFlags = io.ConfigFlags | {.NavEnableKeyboard}

	imgui.ImplGlfw_InitForOpenGL(rawptr(window), true)
	defer imgui.ImplGlfw_Shutdown()

	imgui.ImplOpenGL3_Init("#version 330")
	defer imgui.ImplOpenGL3_Shutdown()

	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		imgui.ImplOpenGL3_NewFrame()
		imgui.ImplGlfw_NewFrame()
		imgui.NewFrame()

		if imgui.Begin("TinyEDA", nil, {}) {
			imgui.Text("Welcome to TinyEDA")
			imgui.Separator()
			imgui.Text("This is running on macOS with OpenGL 3.3")
			imgui.End()
		}

		imgui.Render()

		fb_w, fb_h := glfw.GetFramebufferSize(window)
		OpenGL.Viewport(0, 0, fb_w, fb_h)
		OpenGL.ClearColor(0.1, 0.1, 0.1, 1.0)
		OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT)

		imgui.ImplOpenGL3_RenderDrawData(imgui.GetDrawData())

		glfw.SwapBuffers(window)
	}
}
