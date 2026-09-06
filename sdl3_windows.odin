package foster_framework

// Windows 平台: 运行时动态加载 SDL3.dll(与 exe 同目录或系统路径)
import "core:sys/windows"

sdl_library: windows.HMODULE

sdl_library_loaded :: proc() -> bool {
	return sdl_library != windows.HMODULE(nil)
}

sdl_load_library :: proc() {
	sdl_library = windows.LoadLibraryW(windows.L("SDL3.dll"))
	if sdl_library == windows.HMODULE(nil) {
		sdl_library = windows.LoadLibraryW(windows.L("SDL3"))
	}
	if sdl_library == windows.HMODULE(nil) {
		panic("Failed to load SDL3")
	}
}

sdl_get_proc :: proc(name: cstring) -> rawptr {
	return windows.GetProcAddress(sdl_library, cast(windows.LPCSTR)name)
}
