package app

import "core:fmt"
import "core:strings"
import "../../third-party/imgui"

FileBrowserMode :: enum { EXPLORER, PICK_FILE, PICK_FOLDER, SAVE_FILE }

FileHandle :: distinct u64
FILE_BROWSER_MAX_READ_SIZE :: 16 * 1024 * 1024

BrowserEntry :: struct { name: string, is_dir: bool, size: u64 }
VirtualFile :: struct { path: string, handle: FileHandle, size: u64 }
FileReadResult :: struct {
	request_id: u64,
	data: []byte,
	ok: bool,
}
FileWriteResult :: struct {
	request_id: u64,
	ok: bool,
}
FileBrowserState :: struct {
	path: string,
	entries: [dynamic]BrowserEntry,
	files: [dynamic]VirtualFile,
	selected: int,
	mode: FileBrowserMode,
	open_requested: bool,
	result: string,
	result_ready: bool,
	filename: [256]byte,
	next_request_id: u64,
	read_pending: bool,
	read_result: FileReadResult,
	read_result_ready: bool,
	write_pending: bool,
	write_result: FileWriteResult,
	write_result_ready: bool,
}

browser: FileBrowserState

when ODIN_OS == .JS {
	foreign import "odin_env"
	foreign {
		web_pick_files :: proc "contextless" (folder: i32) ---
		web_read_file :: proc "contextless" (handle: FileHandle, offset: u64, length: u32, request_id: u64) ---
		web_write_file :: proc "contextless" (path: rawptr, path_length: i32, data: rawptr, data_length: i32, request_id: u64) ---
		web_export_project :: proc "contextless" () ---
	}
}

fb_cstr :: proc(s: string) -> cstring { z := fmt.tprintf("%s\x00", s); return cstring(raw_data(z)) }

file_browser_init :: proc() {
	browser.selected = -1
	when ODIN_OS == .JS {
		browser.path = strings.clone("/workspace")
	} else {
		browser.path = fb_native_initial_path()
	}
	file_browser_refresh()
}

file_browser_shutdown :: proc() {
	delete(browser.path); delete(browser.result)
	for e in browser.entries { delete(e.name) }
	delete(browser.entries)
	for f in browser.files { delete(f.path) }
	delete(browser.files)
	delete(browser.read_result.data)
}

file_browser_refresh :: proc() {
	for e in browser.entries { delete(e.name) }
	clear(&browser.entries)
	browser.selected = -1
	when ODIN_OS == .JS {
		prefix := strings.trim_prefix(browser.path, "/workspace")
		prefix = strings.trim_prefix(prefix, "/")
		for f in browser.files {
			rest := f.path
			if len(prefix) > 0 {
				wanted := fmt.tprintf("%s/", prefix)
				if !strings.has_prefix(rest, wanted) { continue }
				rest = strings.trim_prefix(rest, wanted)
			}
			parts := strings.split(rest, "/")
			if len(parts) == 0 || len(parts[0]) == 0 { continue }
			is_dir := len(parts) > 1
			found := false
			for e in browser.entries { if e.name == parts[0] { found = true; break } }
			if !found { append(&browser.entries, BrowserEntry{strings.clone(parts[0]), is_dir, is_dir ? 0 : f.size}) }
		}
	} else {
		fb_native_list()
	}
}

fb_join :: proc(base, name: string) -> string {
	when ODIN_OS == .JS { return fmt.tprintf("%s/%s", strings.trim_suffix(base, "/"), name) }
	else { return fb_native_join(base, name) }
}

fb_web_parent :: proc(path: string) -> string {
	for i := len(path) - 1; i >= len("/workspace"); i -= 1 { if path[i] == '/' { return path[:i] } }
	return "/workspace"
}

fb_set_path :: proc(path: string) { delete(browser.path); browser.path = strings.clone(path); file_browser_refresh() }

file_browser_open :: proc(mode: FileBrowserMode) {
	browser.mode = mode; browser.open_requested = true; browser.result_ready = false; browser.selected = -1
	if mode == .SAVE_FILE { browser.filename = {}; copy(browser.filename[:], "untitled.eda") }
}
file_browser_take_result :: proc() -> (string, bool) {
	if !browser.result_ready { return "", false }
	browser.result_ready = false
	result := browser.result
	browser.result = ""
	return result, true
}

file_browser_file_size :: proc(path: string) -> (u64, bool) {
	when ODIN_OS == .JS {
		rel := strings.trim_prefix(strings.trim_prefix(path, "/workspace"), "/")
		for file in browser.files { if file.path == rel { return file.size, true } }
		return 0, false
	} else {
		return fb_native_file_size(path)
	}
}

file_browser_request_read :: proc(path: string, offset: u64, length: u32) -> (u64, bool) {
	if length == 0 || length > FILE_BROWSER_MAX_READ_SIZE || browser.read_pending || browser.read_result_ready {
		return 0, false
	}

	browser.next_request_id += 1
	if browser.next_request_id == 0 { browser.next_request_id = 1 }
	request_id := browser.next_request_id

	when ODIN_OS == .JS {
		rel := strings.trim_prefix(strings.trim_prefix(path, "/workspace"), "/")
		for file in browser.files {
			if file.path == rel {
				browser.read_pending = true
				browser.read_result.request_id = request_id
				web_read_file(file.handle, offset, length, request_id)
				return request_id, true
			}
		}
		return 0, false
	} else {
		browser.read_pending = true
		browser.read_result.request_id = request_id
		data, ok := fb_native_read_range(path, offset, length)
		fb_complete_read_owned(request_id, data, ok)
		return request_id, true
	}
}

// The caller owns result.data and must delete it.
file_browser_take_read_result :: proc() -> (FileReadResult, bool) {
	if !browser.read_result_ready { return {}, false }
	result := browser.read_result
	browser.read_result = {}
	browser.read_result_ready = false
	return result, true
}

file_browser_request_write :: proc(path: string, data: []byte) -> (u64, bool) {
	if len(path) == 0 || len(data) > FILE_BROWSER_MAX_READ_SIZE || browser.write_pending || browser.write_result_ready {
		return 0, false
	}
	browser.next_request_id += 1
	if browser.next_request_id == 0 { browser.next_request_id = 1 }
	request_id := browser.next_request_id
	browser.write_pending = true
	browser.write_result = FileWriteResult{request_id = request_id}
	when ODIN_OS == .JS {
		web_write_file(raw_data(path), i32(len(path)), raw_data(data), i32(len(data)), request_id)
	} else {
		fb_complete_write(request_id, fb_native_write(path, data))
	}
	return request_id, true
}

file_browser_take_write_result :: proc() -> (FileWriteResult, bool) {
	if !browser.write_result_ready { return {}, false }
	result := browser.write_result
	browser.write_result = {}
	browser.write_result_ready = false
	return result, true
}

fb_complete_write :: proc(request_id: u64, ok: bool) {
	if !browser.write_pending || browser.write_result.request_id != request_id { return }
	browser.write_pending = false
	browser.write_result.ok = ok
	browser.write_result_ready = true
}

fb_complete_read_owned :: proc(request_id: u64, data: []byte, ok: bool) {
	if !browser.read_pending || browser.read_result.request_id != request_id {
		delete(data)
		return
	}
	browser.read_pending = false
	browser.read_result = FileReadResult{request_id, data, ok}
	browser.read_result_ready = true
}

web_register_file :: proc(path: []byte, handle: FileHandle, size: u64) {
	when ODIN_OS == .JS {
		file_path := string(path)
		for &file in browser.files {
			if file.path == file_path {
				file.handle = handle
				file.size = size
				return
			}
		}
		append(&browser.files, VirtualFile{strings.clone(file_path), handle, size})
	}
}

web_read_completed :: proc(request_id: u64, data: []byte, ok: bool) {
	when ODIN_OS == .JS {
		fb_complete_read_owned(request_id, data, ok)
	}
}
web_write_completed :: proc(request_id: u64, path: []byte, handle: FileHandle, size: u64, ok: bool) {
	when ODIN_OS == .JS {
		if ok {
			web_register_file(path, handle, size)
			file_browser_refresh()
		}
		fb_complete_write(request_id, ok)
	}
}
web_transfer_finished :: proc() { when ODIN_OS == .JS { file_browser_refresh() } }

fb_accept :: proc(path: string) { delete(browser.result); browser.result = strings.clone(path); browser.result_ready = true }

fb_contents :: proc(modal: bool) {
	if imgui.Button("Up") {
		when ODIN_OS == .JS { if browser.path != "/workspace" { fb_set_path(fb_web_parent(browser.path)) } }
		else { fb_native_up() }
	}
	imgui.SameLine()
	when ODIN_OS == .JS {
		if imgui.Button("Import Files") { web_pick_files(0) }; imgui.SameLine()
		if imgui.Button("Import Folder") { web_pick_files(1) }; imgui.SameLine()
		imgui.BeginDisabled(len(browser.files) == 0)
		if imgui.Button("Export Project (.zip)") { web_export_project() }
		imgui.EndDisabled()
	} else {
		if imgui.Button("Home") { fb_native_home() }
		imgui.SameLine(); if imgui.Button("Refresh") { file_browser_refresh() }
	}
	imgui.Text("%s", fb_cstr(browser.path))
	when ODIN_OS == .JS {
		imgui.TextWrapped("Browser-local project: saves are kept in this site's storage. Export regularly; browser data may be cleared.")
	}
	if imgui.BeginTable("browser_entries", 3, {.BordersInnerH, .BordersOuterH, .BordersInnerV, .BordersOuterV, .RowBg, .ScrollY}, {0, modal ? 300 : 0}) {
		imgui.TableSetupColumn("Name"); imgui.TableSetupColumn("Type"); imgui.TableSetupColumn("Size"); imgui.TableHeadersRow()
		for e, i in browser.entries {
			imgui.TableNextRow(); _ = imgui.TableSetColumnIndex(0)
			if imgui.Selectable(fb_cstr(e.name), browser.selected == i, {.SpanAllColumns}) {
				browser.selected = i
				if imgui.IsMouseDoubleClicked(.Left) {
					p := fb_join(browser.path, e.name)
					if e.is_dir {
						fb_set_path(p)
					} else if modal && browser.mode == .PICK_FILE {
						fb_accept(p); imgui.CloseCurrentPopup()
					} else if !modal {
						text_editor_open_path(p)
					}
				}
			}
			_ = imgui.TableSetColumnIndex(1); imgui.TextUnformatted(e.is_dir ? "Folder" : "File")
			_ = imgui.TableSetColumnIndex(2); if !e.is_dir { imgui.Text("%llu", e.size) }
		}
		imgui.EndTable()
	}
	if modal {
		if browser.mode == .SAVE_FILE { _ = imgui.InputText("Filename", cstring(&browser.filename[0]), len(browser.filename)) }
		filename_length := strings.index_byte(string(browser.filename[:]), 0)
		if filename_length < 0 { filename_length = len(browser.filename) }
		selected_file := browser.selected >= 0 && !browser.entries[browser.selected].is_dir
		can_accept := false
		switch browser.mode {
		case .PICK_FILE:   can_accept = selected_file
		case .PICK_FOLDER: can_accept = true
		case .SAVE_FILE:   can_accept = filename_length > 0
		case .EXPLORER:
		}
		imgui.BeginDisabled(!can_accept)
		if imgui.Button(browser.mode == .SAVE_FILE ? "Save" : "Select") {
			path := browser.path
			if browser.mode == .SAVE_FILE { path = fb_join(path, string(browser.filename[:filename_length])) }
			else if browser.mode == .PICK_FILE { path = fb_join(path, browser.entries[browser.selected].name) }
			else if browser.selected >= 0 && browser.entries[browser.selected].is_dir { path = fb_join(path, browser.entries[browser.selected].name) }
			fb_accept(path); imgui.CloseCurrentPopup()
		}
		imgui.EndDisabled()
		imgui.SameLine(); if imgui.Button("Cancel") { imgui.CloseCurrentPopup() }
	}
}

file_browser_draw_explorer_contents :: proc() { fb_contents(false) }
file_browser_draw_modals :: proc() {
	if browser.open_requested { imgui.OpenPopup("File Browser"); browser.open_requested = false }
	if imgui.BeginPopupModal("File Browser", nil, {.AlwaysAutoResize}) { fb_contents(true); imgui.EndPopup() }
}
