package main_web

import "base:runtime"
import "core:c"
import "core:mem"
import "../app"
import "../../third-party/imgui"

foreign import "odin_env"
foreign {
	web_set_clipboard_text :: proc "contextless" (data: rawptr, size: c.int) ---
}

@(private="file")
web_context: runtime.Context
web_clipboard_buffer: [dynamic]byte

web_clipboard_get :: proc "c" (ctx: ^imgui.Context) -> cstring {
	return cstring(raw_data(web_clipboard_buffer))
}

web_clipboard_set :: proc "c" (ctx: ^imgui.Context, text: cstring) {
	context = web_context
	bytes := ([^]byte)(text)
	length := 0
	for bytes[length] != 0 { length += 1 }
	web_set_clipboard_text(rawptr(text), c.int(length))
}

web_clipboard_init :: proc() {
	web_clipboard_buffer = make([dynamic]byte, 1)
	web_clipboard_buffer[0] = 0
	platform_io := imgui.GetPlatformIO()
	platform_io.PlatformGetClipboardTextFn = web_clipboard_get
	platform_io.PlatformSetClipboardTextFn = web_clipboard_set
}

@export
main_start :: proc "c" () {
	context = runtime.default_context()
	context.allocator = emscripten_allocator()
	runtime.init_global_temporary_allocator(1 * mem.Megabyte)
	context.logger = create_emscripten_logger()
	web_context = context

	app.Init()
	web_clipboard_init()
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
	delete(web_clipboard_buffer)
	web_clipboard_buffer = nil
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
web_read_alloc :: proc "c" (size: c.int) -> rawptr {
	context = web_context
	if size <= 0 {
		return nil
	}
	data, err := mem.alloc_bytes_non_zeroed(int(size), allocator = web_context.allocator)
	if err != nil {
		return nil
	}
	return raw_data(data)
}

@export
web_clipboard_changed :: proc "c" (memory: rawptr, size: c.int) {
	context = web_context
	resize(&web_clipboard_buffer, int(size) + 1)
	copy(web_clipboard_buffer[:int(size)], ([^]byte)(memory)[:int(size)])
	web_clipboard_buffer[size] = 0
	free(memory)
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
}

@export
web_write_completed :: proc "c" (request_id: u64, path_memory: rawptr, path_size: c.int, handle, file_size: u64, success: c.int) {
	context = web_context
	path := ([^]byte)(path_memory)[:int(path_size)]
	app.Web_Write_Completed(request_id, path, app.File_Handle(handle), file_size, success != 0)
	free(path_memory)
}
