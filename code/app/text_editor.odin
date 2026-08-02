package app

import "base:runtime"
import "core:fmt"
import "core:strings"
import "../../third-party/imgui"

TEXT_EDITOR_INITIAL_CAPACITY :: 4096

Text_Document :: struct {
	path:           string,
	buffer:         [dynamic]byte,
	open:           bool,
	dirty:          bool,
	loading:        bool,
	saving:         bool,
	save_failed:    bool,
	binary:         bool,
	read_request:   u64,
	write_request:  u64,
	revision:        u64,
	save_revision:   u64,
	runtime_context: runtime.Context,
}

text_documents: [dynamic]Text_Document
text_active_document: int = -1

text_editor_file_name :: proc(path: string) -> string {
	last_slash := strings.last_index(path, "/")
	when ODIN_OS != .JS {
		last_backslash := strings.last_index(path, "\\")
		last_slash = max(last_slash, last_backslash)
	}
	if last_slash >= 0 && last_slash + 1 < len(path) {
		return path[last_slash + 1:]
	}
	return path
}

text_document_make_buffer :: proc(contents: []byte) -> [dynamic]byte {
	capacity := max(len(contents) + 1, TEXT_EDITOR_INITIAL_CAPACITY)
	buffer := make([dynamic]byte, capacity)
	copy(buffer[:len(contents)], contents)
	buffer[len(contents)] = 0
	return buffer
}

text_document_contents :: proc(document: ^Text_Document) -> []byte {
	length := 0
	for length < len(document.buffer) && document.buffer[length] != 0 {
		length += 1
	}
	return document.buffer[:length]
}

text_contents_are_editable :: proc(contents: []byte) -> bool {
	for byte in contents {
		if byte == 0 { return false }
	}
	return true
}

text_editor_find :: proc(path: string) -> int {
	for document, index in text_documents {
		if document.path == path {
			return index
		}
	}
	return -1
}

text_editor_ensure_panel :: proc() {
	if !panel_exists(.Text_Editor) {
		panel_add(.Text_Editor)
	}
}

text_editor_open_path :: proc(path: string) {
	if index := text_editor_find(path); index >= 0 {
		text_documents[index].open = true
		text_active_document = index
		text_editor_ensure_panel()
		return
	}

	size, found := File_Browser_File_Size(path)
	if !found || size > FILE_BROWSER_MAX_READ_SIZE {
		return
	}

	document := Text_Document{
		path = strings.clone(path),
		buffer = text_document_make_buffer(nil),
		open = true,
		runtime_context = context,
	}
	if size > 0 {
		request_id, requested := File_Browser_Request_Read(path, 0, u32(size))
		if !requested {
			delete(document.path)
			delete(document.buffer)
			return
		}
		document.loading = true
		document.read_request = request_id
	}
	append(&text_documents, document)
	text_active_document = len(text_documents) - 1
	text_editor_ensure_panel()
}

text_editor_new_path :: proc(path: string) {
	if index := text_editor_find(path); index >= 0 {
		text_active_document = index
		text_documents[index].open = true
		text_editor_ensure_panel()
		return
	}
	append(&text_documents, Text_Document{
		path = strings.clone(path),
		buffer = text_document_make_buffer(nil),
		open = true,
		dirty = true,
		revision = 1,
		runtime_context = context,
	})
	text_active_document = len(text_documents) - 1
	text_editor_ensure_panel()
}

text_editor_save :: proc(index: int) {
	if index < 0 || index >= len(text_documents) {
		return
	}
	document := &text_documents[index]
	if document.loading || document.saving || document.binary || !document.dirty {
		return
	}
	request_id, requested := File_Browser_Request_Write(document.path, text_document_contents(document))
	if requested {
		document.saving = true
		document.save_failed = false
		document.write_request = request_id
		document.save_revision = document.revision
	} else {
		document.save_failed = true
	}
}

text_editor_update :: proc() {
	if result, ready := File_Browser_Take_Read_Result(); ready {
		for &document in text_documents {
			if document.read_request != result.request_id {
				continue
			}
			document.loading = false
			document.read_request = 0
			if result.ok && text_contents_are_editable(result.data) {
				delete(document.buffer)
				document.buffer = text_document_make_buffer(result.data)
			} else if result.ok {
				document.binary = true
			} else {
				document.save_failed = true
			}
			break
		}
		delete(result.data)
	}

	if result, ready := File_Browser_Take_Write_Result(); ready {
		for &document in text_documents {
			if document.write_request != result.request_id {
				continue
			}
			document.saving = false
			document.write_request = 0
			document.save_failed = !result.ok
			if result.ok && document.revision == document.save_revision {
				document.dirty = false
			}
			break
		}
	}

	if ui_scale_shortcut(.S) {
		text_editor_save(text_active_document)
	}
}

text_editor_resize_callback :: proc "c" (data: ^imgui.InputTextCallbackData) -> i32 {
	document := (^Text_Document)(data.UserData)
	if document == nil || data.EventFlag != {.CallbackResize} {
		return 0
	}
	context = document.runtime_context
	if resize(&document.buffer, int(data.BufSize)) != nil {
		return 1
	}
	data.Buf = cstring(raw_data(document.buffer))
	return 0
}

text_editor_draw_document :: proc(document: ^Text_Document, index: int) {
	if document.loading {
		imgui.TextUnformatted("Loading...")
		return
	}
	if document.binary {
		imgui.TextUnformatted("This file contains binary data and cannot be edited as text.")
		return
	}
	if document.save_failed {
		imgui.TextUnformatted("Could not read or save this file.")
	}
	if document.saving {
		imgui.TextUnformatted("Saving...")
	}
	available := imgui.GetContentRegionAvail()
	if imgui.InputTextMultiline(
		fb_cstr(fmt.tprintf("###text_document_%d", index)),
		cstring(raw_data(document.buffer)),
		uint(len(document.buffer)),
		available,
		{.AllowTabInput, .CallbackResize},
		transmute(imgui.InputTextCallback)text_editor_resize_callback,
		document,
	) {
		document.dirty = true
		document.save_failed = false
		document.revision += 1
	}
}

text_editor_draw :: proc() {
	if imgui.Button("New File") {
		File_Browser_Open(.Save_File)
	}
	imgui.SameLine()
	if imgui.Button("Open File") {
		File_Browser_Open(.Pick_File)
	}
	imgui.SameLine()
	can_save := text_active_document >= 0 && text_active_document < len(text_documents) &&
	            text_documents[text_active_document].dirty && !text_documents[text_active_document].saving &&
	            !text_documents[text_active_document].binary
	imgui.BeginDisabled(!can_save)
	if imgui.Button("Save") {
		text_editor_save(text_active_document)
	}
	imgui.EndDisabled()

	if len(text_documents) == 0 {
		imgui.Separator()
		imgui.TextUnformatted("Open a text file or create a new one to start editing.")
		return
	}

	if imgui.BeginTabBar("text_documents", {.Reorderable, .AutoSelectNewTabs}) {
		for index in 0..<len(text_documents) {
			document := &text_documents[index]
			flags: imgui.TabItemFlags
			if document.dirty {
				flags += {.UnsavedDocument}
			}
			label := fmt.tprintf("%s###text_tab_%d\x00", text_editor_file_name(document.path), index)
			if imgui.BeginTabItem(cstring(raw_data(label)), &document.open, flags) {
				text_active_document = index
				text_editor_draw_document(document, index)
				imgui.EndTabItem()
			}
		}
		imgui.EndTabBar()
	}

	for index := len(text_documents) - 1; index >= 0; index -= 1 {
		if text_documents[index].open {
			continue
		}
		delete(text_documents[index].path)
		delete(text_documents[index].buffer)
		ordered_remove(&text_documents, index)
		if text_active_document >= index {
			text_active_document -= 1
		}
	}
}

text_editor_shutdown :: proc() {
	for &document in text_documents {
		delete(document.path)
		delete(document.buffer)
	}
	delete(text_documents)
	text_documents = nil
	text_active_document = -1
}
