#+build !js
package app

import "core:fmt"
import "core:os"
import "core:path/filepath"

workspace_storage_path :: proc(kind: Workspace_Storage_Kind, allocator := context.allocator) -> (string, bool) {
	base, base_err := os.user_config_dir(allocator)
	if base_err != nil { return "", false }
	directory, directory_err := filepath.join({base, "TinyEDA"}, allocator)
	if directory_err != nil { return "", false }
	path, path_err := filepath.join({directory, workspace_storage_name(kind)}, allocator)
	if path_err != nil { return "", false }
	return path, true
}

workspace_storage_load :: proc(kind: Workspace_Storage_Kind, allocator := context.allocator) -> ([]byte, bool) {
	path, path_ok := workspace_storage_path(kind, context.temp_allocator)
	if !path_ok { return nil, false }
	data, read_err := os.read_entire_file(path, allocator)
	if read_err != nil { return nil, false }
	return data, true
}

workspace_storage_save :: proc(kind: Workspace_Storage_Kind, data: []byte) -> bool {
	path, path_ok := workspace_storage_path(kind, context.temp_allocator)
	if !path_ok { return false }
	directory := filepath.dir(path)
	if directory_err := os.make_directory_all(directory); directory_err != nil && directory_err != .Exist {
		return false
	}
	temporary_path := fmt.tprintf("%s.tmp", path)
	if write_err := os.write_entire_file(temporary_path, data); write_err != nil {
		return false
	}
	if rename_err := os.rename(temporary_path, path); rename_err != nil {
		_ = os.remove(temporary_path)
		return false
	}
	return true
}
