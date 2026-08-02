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
web_window_size_changed :: proc "c" (width, height: c.int, display_scale: f32) {
	context = web_context
	app.Resize(int(width), int(height), display_scale)
}

@export
main_flush_workspace :: proc "c" () {
	context = web_context
	app.Flush_Workspace()
}

@export
web_transfer_alloc :: proc "c" (size: c.int) -> rawptr {
	return malloc(c.size_t(size))
}

@export
web_register_file :: proc "c" (memory: rawptr, path_size: c.int, handle, file_size: u64) {
	context = web_context
	path := ([^]byte)(memory)[:int(path_size)]
	app.Web_Register_File(path, app.File_Handle(handle), file_size)
	free(memory)
}

@export
web_transfer_finished :: proc "c" () {
	context = web_context
	app.Web_Transfer_Finished()
}

@export
web_read_completed :: proc "c" (request_id: u64, memory: rawptr, size, success: c.int) {
	context = web_context
	data := ([^]byte)(memory)[:int(size)]
	app.Web_Read_Completed(request_id, data, success != 0)
	free(memory)
}
