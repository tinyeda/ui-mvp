#+build js
package app

foreign import "odin_env"
foreign {
	web_storage_size :: proc "contextless" (kind: WorkspaceStorageKind) -> i32 ---
	web_storage_load :: proc "contextless" (kind: WorkspaceStorageKind, data: rawptr, capacity: i32) -> i32 ---
	web_storage_save :: proc "contextless" (kind: WorkspaceStorageKind, data: rawptr, size: i32) -> i32 ---
}

workspace_storage_load :: proc(kind: WorkspaceStorageKind, allocator := context.allocator) -> (data: []byte, ok: bool) {
	size := web_storage_size(kind)
	if size <= 0 { return nil, false }
	allocated, allocation_error := make([]byte, int(size), allocator)
	if allocation_error != nil { return nil, false }
	data = allocated
	written := web_storage_load(kind, raw_data(data), size)
	if written != size {
		delete(data, allocator)
		return nil, false
	}
	return data, true
}

workspace_storage_save :: proc(kind: WorkspaceStorageKind, data: []byte) -> bool {
	return web_storage_save(kind, raw_data(data), i32(len(data))) != 0
}
