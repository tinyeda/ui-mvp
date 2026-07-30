package main_web

import "base:runtime"
import "core:c"
import "core:mem"
import "../app"

@(private="file")
web_context: runtime.Context

@export
main_start :: proc "c" () {
	context = runtime.default_context()
	context.allocator = emscripten_allocator()
	runtime.init_global_temporary_allocator(1 * mem.Megabyte)
	context.logger = create_emscripten_logger()
	web_context = context

	app.Init()
}

@export
main_update :: proc "c" () -> bool {
	context = web_context
	app.Frame()
	return app.Running()
}

@export
main_end :: proc "c" () {
	context = web_context
	app.Shutdown()
}

@export
web_window_size_changed :: proc "c" (width, height: c.int) {
	context = web_context
	app.Resize(int(width), int(height))
}
