#+build !js
package app

import "core:os"
import "core:path/filepath"
import "core:strings"

fb_native_initial_path :: proc() -> string {
	return os.get_working_directory(context.allocator) or_else strings.clone(".")
}

fb_native_list :: proc() {
	infos, err := os.read_all_directory_by_path(browser.path, context.allocator)
	if err != nil { return }
	defer os.file_info_slice_delete(infos, context.allocator)
	for pass in 0..<2 { for info in infos {
		is_dir := info.type == .Directory
		if (pass == 0) == is_dir {
			append(&browser.entries, Browser_Entry{strings.clone(info.name), is_dir, u64(max(info.size, 0))})
		}
	} }
}

fb_native_home :: proc() {
	if home, err := os.user_home_dir(context.temp_allocator); err == nil { fb_set_path(home) }
}

fb_native_join :: proc(base, name: string) -> string { return filepath.join({base, name}, context.temp_allocator) or_else base }
fb_native_up :: proc() { p, _ := filepath.split(browser.path); if len(p) > 0 { fb_set_path(p) } }

fb_native_file_size :: proc(path: string) -> (u64, bool) {
	file, open_error := os.open(path)
	if open_error != nil { return 0, false }
	defer os.close(file)
	size, size_error := os.file_size(file)
	return u64(max(size, 0)), size_error == nil
}

fb_native_read_range :: proc(path: string, offset: u64, length: u32) -> ([]byte, bool) {
	if offset > u64(max(i64)) { return nil, false }
	file, open_error := os.open(path)
	if open_error != nil { return nil, false }
	defer os.close(file)

	data := make([]byte, int(length))
	bytes_read, read_error := os.read_at(file, data, i64(offset))
	if read_error != nil && read_error != .EOF {
		delete(data)
		return nil, false
	}
	if bytes_read == len(data) { return data, true }
	result := make([]byte, bytes_read)
	copy(result, data[:bytes_read])
	delete(data)
	return result, true
}
