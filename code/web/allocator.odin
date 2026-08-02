package main_web

import "base:intrinsics"
import "core:c"
import "core:mem"

@(default_calling_convention = "c")
foreign {
	calloc :: proc(num, size: c.size_t) -> rawptr ---
	free   :: proc(ptr: rawptr) ---
	malloc :: proc(size: c.size_t) -> rawptr ---
}

emscripten_allocator :: proc "contextless" () -> mem.Allocator {
	return mem.Allocator{emscripten_allocator_proc, nil}
}

emscripten_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (data: []byte, err: mem.Allocator_Error) {
	aligned_alloc :: proc(
		size, alignment: int,
		zero_memory: bool,
	) -> ([]byte, mem.Allocator_Error) {
		a := max(alignment, align_of(rawptr))
		space := size + a - 1

		allocated_memory: rawptr
		if zero_memory {
			allocated_memory = calloc(c.size_t(space + size_of(rawptr)), 1)
		} else {
			allocated_memory = malloc(c.size_t(space + size_of(rawptr)))
		}
		if allocated_memory == nil {
			return nil, .Out_Of_Memory
		}

		aligned_memory := rawptr(mem.ptr_offset((^u8)(allocated_memory), size_of(rawptr)))
		ptr := uintptr(aligned_memory)
		aligned_ptr := (ptr - 1 + uintptr(a)) & -uintptr(a)
		difference := int(aligned_ptr - ptr)
		if size + difference > space {
			free(allocated_memory)
			return nil, .Out_Of_Memory
		}

		aligned_memory = rawptr(aligned_ptr)
		mem.ptr_offset((^rawptr)(aligned_memory), -1)^ = allocated_memory
		return mem.byte_slice(aligned_memory, size), nil
	}

	aligned_free :: proc(pointer: rawptr) {
		if pointer != nil {
			free(mem.ptr_offset((^rawptr)(pointer), -1)^)
		}
	}

	aligned_resize :: proc(
		pointer: rawptr,
		old_size, new_size, new_alignment: int,
		zero_memory: bool,
	) -> ([]byte, mem.Allocator_Error) {
		bytes, err := aligned_alloc(new_size, new_alignment, zero_memory)
		if err != nil {
			return nil, err
		}
		intrinsics.mem_copy(raw_data(bytes), pointer, min(old_size, new_size))
		aligned_free(pointer)
		return bytes, nil
	}

	switch mode {
	case .Alloc:
		return aligned_alloc(size, alignment, true)
	case .Alloc_Non_Zeroed:
		return aligned_alloc(size, alignment, false)
	case .Free:
		aligned_free(old_memory)
		return nil, nil
	case .Resize:
		if old_memory == nil {
			return aligned_alloc(size, alignment, true)
		}
		return aligned_resize(old_memory, old_size, size, alignment, true)
	case .Resize_Non_Zeroed:
		if old_memory == nil {
			return aligned_alloc(size, alignment, false)
		}
		return aligned_resize(old_memory, old_size, size, alignment, false)
	case .Query_Features:
		set := (^mem.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {
				.Alloc,
				.Alloc_Non_Zeroed,
				.Free,
				.Resize,
				.Resize_Non_Zeroed,
				.Query_Features,
			}
		}
		return nil, nil
	case .Free_All, .Query_Info:
		return nil, .Mode_Not_Implemented
	}
	return nil, .Mode_Not_Implemented
}
