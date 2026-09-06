package foster_framework

// Linux 平台: dlopen 动态加载 libSDL3(优先带版本号的 soname)
import posix "core:sys/posix"

sdl_library: rawptr

sdl_library_loaded :: proc() -> bool {
	return sdl_library != nil
}

sdl_load_library :: proc() {
	sdl_library = cast(rawptr)posix.dlopen("libSDL3.so.0", {.LAZY, .GLOBAL})
	if sdl_library == nil {
		sdl_library = cast(rawptr)posix.dlopen("libSDL3.so", {.LAZY, .GLOBAL})
	}
	if sdl_library == nil {
		sdl_library = cast(rawptr)posix.dlopen("SDL3", {.LAZY, .GLOBAL})
	}
	if sdl_library == nil {
		panic("Failed to load SDL3 (libSDL3.so.0 not found; set LD_LIBRARY_PATH)")
	}
}

sdl_get_proc :: proc(name: cstring) -> rawptr {
	return posix.dlsym(cast(posix.Symbol_Table)sdl_library, name)
}
