package main_web

import "core:c"
import "core:fmt"
import "core:log"
import "core:strings"

EMSCRIPTEN_LOGGER_OPTIONS :: log.Options{.Level, .Short_File_Path, .Line}

create_emscripten_logger :: proc(
	lowest := log.Level.Debug,
	options := EMSCRIPTEN_LOGGER_OPTIONS,
) -> log.Logger {
	return log.Logger{
		data = nil,
		procedure = logger_proc,
		lowest_level = lowest,
		options = options,
	}
}

@(default_calling_convention = "c")
foreign {
	puts :: proc(buffer: cstring) -> c.int ---
}

@(private="file")
logger_proc :: proc(
	logger_data: rawptr,
	level: log.Level,
	text: string,
	options: log.Options,
	location := #caller_location,
) {
	builder := strings.builder_make(context.temp_allocator)
	strings.write_string(&builder, level_headers[level])
	do_location_header(options, &builder, location)
	fmt.sbprint(&builder, text)

	if buffer, err := strings.to_cstring(&builder); err == nil {
		puts(buffer)
	}
}

@(private="file")
level_headers := [?]string {
	0 ..< 10 = "[DEBUG] --- ",
	10 ..< 20 = "[INFO ] --- ",
	20 ..< 30 = "[WARN ] --- ",
	30 ..< 40 = "[ERROR] --- ",
	40 ..< 50 = "[FATAL] --- ",
}

@(private="file")
do_location_header :: proc(
	options: log.Options,
	buffer: ^strings.Builder,
	location := #caller_location,
) {
	if log.Location_Header_Opts & options == nil {
		return
	}

	fmt.sbprint(buffer, "[")
	file := location.file_path
	if .Short_File_Path in options {
		last := 0
		for rune, index in location.file_path {
			if rune == '/' {
				last = index + 1
			}
		}
		file = location.file_path[last:]
	}

	if log.Location_File_Opts & options != nil {
		fmt.sbprint(buffer, file)
	}
	if .Line in options {
		if log.Location_File_Opts & options != nil {
			fmt.sbprint(buffer, ":")
		}
		fmt.sbprint(buffer, location.line)
	}
	if .Procedure in options {
		if (log.Location_File_Opts | {.Line}) & options != nil {
			fmt.sbprint(buffer, ":")
		}
		fmt.sbprintf(buffer, "%s()", location.procedure)
	}
	fmt.sbprint(buffer, "] ")
}
