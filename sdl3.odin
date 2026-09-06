package foster_framework
// 库句柄与加载过程在 sdl3_windows.odin / sdl3_linux.odin 中按平台后缀自动选择:
//   sdl_library / sdl_load_library() / sdl_get_proc(name) / sdl_library_loaded()

SDL_InitFlags :: distinct u32

SDL_INIT_TIMER    : SDL_InitFlags : SDL_InitFlags(0x1)
SDL_INIT_AUDIO    : SDL_InitFlags : SDL_InitFlags(0x10)
SDL_INIT_VIDEO    : SDL_InitFlags : SDL_InitFlags(0x20)
SDL_INIT_JOYSTICK : SDL_InitFlags : SDL_InitFlags(0x200)
SDL_INIT_HAPTIC   : SDL_InitFlags : SDL_InitFlags(0x1000)
SDL_INIT_GAMEPAD  : SDL_InitFlags : SDL_InitFlags(0x2000)
SDL_INIT_EVENTS   : SDL_InitFlags : SDL_InitFlags(0x4000)
SDL_INIT_SENSOR   : SDL_InitFlags : SDL_InitFlags(0x08000)
SDL_INIT_CAMERA   : SDL_InitFlags : SDL_InitFlags(0x10000)

SDL_EventType :: enum u32 {
	SDL_EVENT_QUIT = 256,
	SDL_EVENT_WINDOW_RESIZED = 518,
	SDL_EVENT_WINDOW_RESTORED = 523,
	SDL_EVENT_WINDOW_MAXIMIZED = 522,
	SDL_EVENT_WINDOW_MINIMIZED = 521,
	SDL_EVENT_WINDOW_MOUSE_ENTER = 524,
	SDL_EVENT_WINDOW_MOUSE_LEAVE = 525,
	SDL_EVENT_WINDOW_FOCUS_GAINED = 526,
	SDL_EVENT_WINDOW_FOCUS_LOST = 527,
	SDL_EVENT_WINDOW_ENTER_FULLSCREEN = 535,
	SDL_EVENT_WINDOW_LEAVE_FULLSCREEN = 536,
	SDL_EVENT_WINDOW_CLOSE_REQUESTED = 528,

	SDL_EVENT_KEY_DOWN = 768,
	SDL_EVENT_KEY_UP = 769,
	SDL_EVENT_TEXT_INPUT = 771,

	SDL_EVENT_MOUSE_BUTTON_DOWN = 1025,
	SDL_EVENT_MOUSE_BUTTON_UP = 1026,
	SDL_EVENT_MOUSE_WHEEL = 1027,

	SDL_EVENT_JOYSTICK_AXIS_MOTION = 1536,
	SDL_EVENT_JOYSTICK_BUTTON_DOWN = 1539,
	SDL_EVENT_JOYSTICK_BUTTON_UP = 1540,
	SDL_EVENT_JOYSTICK_ADDED = 1541,
	SDL_EVENT_JOYSTICK_REMOVED = 1542,

	SDL_EVENT_GAMEPAD_AXIS_MOTION = 1616,
	SDL_EVENT_GAMEPAD_BUTTON_DOWN = 1617,
	SDL_EVENT_GAMEPAD_BUTTON_UP = 1618,
	SDL_EVENT_GAMEPAD_ADDED = 1619,
	SDL_EVENT_GAMEPAD_REMOVED = 1620,

	SDL_EVENT_POLL_SENTINEL = 32512,
}

SDL_Scancode :: distinct u32

SDLBool :: distinct u8

sdl_bool :: proc(b: bool) -> SDLBool { return SDLBool(u8(b)) }
sdl_bool_to_bool :: proc(b: SDLBool) -> bool { return u8(b) != 0 }

SDL_WindowEvent :: struct {
	type: SDL_EventType,
	reserved: u32,
	timestamp: u64,
	windowID: u32,
	data1: i32,
	data2: i32,
}

SDL_KeyboardEvent :: struct {
	type: SDL_EventType,
	reserved: u32,
	timestamp: u64,
	windowID: u32,
	which: u32,
	scancode: SDL_Scancode,
	key: u32,
	mod: u16,
	raw: u16,
	down: SDLBool,
	repeat: SDLBool,
}

SDL_TextInputEvent :: struct {
	type: SDL_EventType,
	reserved: u32,
	timestamp: u64,
	windowID: u32,
	text: cstring,
}

SDL_MouseButtonEvent :: struct {
	type: SDL_EventType,
	reserved: u32,
	timestamp: u64,
	windowID: u32,
	which: u32,
	button: u8,
	down: SDLBool,
	clicks: u8,
	padding: u8,
	x: f32,
	y: f32,
}

SDL_MouseWheelEvent :: struct {
	type: SDL_EventType,
	reserved: u32,
	timestamp: u64,
	windowID: u32,
	which: u32,
	x: f32,
	y: f32,
	direction: i32,
	mouse_x: f32,
	mouse_y: f32,
	integer_x: i32,
	integer_y: i32,
}

SDL_JoyDeviceEvent :: struct {
	type: SDL_EventType,
	reserved: u32,
	timestamp: u64,
	which: u32,
}

SDL_JoyButtonEvent :: struct {
	type: SDL_EventType,
	reserved: u32,
	timestamp: u64,
	which: u32,
	button: u8,
	down: SDLBool,
	padding1: u8,
	padding2: u8,
}

SDL_JoyAxisEvent :: struct {
	type: SDL_EventType,
	reserved: u32,
	timestamp: u64,
	which: u32,
	axis: u8,
	padding1: u8,
	padding2: u8,
	padding3: u8,
	value: i16,
	padding4: u16,
}

SDL_GamepadDeviceEvent :: struct {
	type: SDL_EventType,
	reserved: u32,
	timestamp: u64,
	which: u32,
}

SDL_GamepadButtonEvent :: struct {
	type: SDL_EventType,
	reserved: u32,
	timestamp: u64,
	which: u32,
	button: u8,
	down: SDLBool,
	padding1: u8,
	padding2: u8,
}

SDL_GamepadAxisEvent :: struct {
	type: SDL_EventType,
	reserved: u32,
	timestamp: u64,
	which: u32,
	axis: u8,
	padding1: u8,
	padding2: u8,
	padding3: u8,
	value: i16,
	padding4: u16,
}

SDL_Event :: struct #raw_union {
	type: u32,
	window: SDL_WindowEvent,
	key: SDL_KeyboardEvent,
	text: SDL_TextInputEvent,
	button: SDL_MouseButtonEvent,
	wheel: SDL_MouseWheelEvent,
	jdevice: SDL_JoyDeviceEvent,
	jbutton: SDL_JoyButtonEvent,
	jaxis: SDL_JoyAxisEvent,
	gdevice: SDL_GamepadDeviceEvent,
	gbutton: SDL_GamepadButtonEvent,
	gaxis: SDL_GamepadAxisEvent,
	padding: [128]u8,
}

SDL_WindowFlags :: distinct u64

SDL_WINDOW_FULLSCREEN         : SDL_WindowFlags : SDL_WindowFlags(0x0000000000000001)
SDL_WINDOW_HIDDEN             : SDL_WindowFlags : SDL_WindowFlags(0x0000000000000008)
SDL_WINDOW_RESIZABLE          : SDL_WindowFlags : SDL_WindowFlags(0x0000000000000020)
SDL_WINDOW_HIGH_PIXEL_DENSITY : SDL_WindowFlags : SDL_WindowFlags(0x0000000000002000)
SDL_WINDOW_INPUT_FOCUS        : SDL_WindowFlags : SDL_WindowFlags(0x0000000000000200)
SDL_WINDOW_MOUSE_FOCUS        : SDL_WindowFlags : SDL_WindowFlags(0x0000000000000400)
SDL_WINDOW_MAXIMIZED          : SDL_WindowFlags : SDL_WindowFlags(0x0000000000000080)


SDL_Init_Proc            :: proc "c" (flags: SDL_InitFlags) -> SDLBool
SDL_Quit_Proc            :: proc "c" ()
SDL_GetVersion_Proc      :: proc "c" () -> i32
SDL_GetError_Proc        :: proc "c" () -> cstring
SDL_SetHint_Proc         :: proc "c" (name, value: cstring) -> SDLBool
SDL_SetLogOutputFunction_Proc :: proc "c" (callback: rawptr, userdata: rawptr)
SDL_PumpEvents_Proc      :: proc "c" ()
SDL_PollEvent_Proc       :: proc "c" (event: ^SDL_Event) -> SDLBool

SDL_CreateWindow_Proc    :: proc "c" (title: cstring, w, h: i32, flags: SDL_WindowFlags) -> rawptr
SDL_DestroyWindow_Proc   :: proc "c" (window: rawptr)
SDL_ShowWindow_Proc      :: proc "c" (window: rawptr) -> SDLBool
SDL_HideWindow_Proc      :: proc "c" (window: rawptr) -> SDLBool
SDL_GetWindowID_Proc     :: proc "c" (window: rawptr) -> u32
SDL_GetWindowPosition_Proc :: proc "c" (window: rawptr, x, y: ^i32)
SDL_SetWindowPosition_Proc :: proc "c" (window: rawptr, x, y: i32)
SDL_GetWindowSize_Proc   :: proc "c" (window: rawptr, w, h: ^i32)
SDL_SetWindowSize_Proc   :: proc "c" (window: rawptr, w, h: i32)
SDL_GetWindowSizeInPixels_Proc :: proc "c" (window: rawptr, w, h: ^i32)
SDL_GetWindowFlags_Proc  :: proc "c" (window: rawptr) -> SDL_WindowFlags
SDL_SetWindowTitle_Proc  :: proc "c" (window: rawptr, title: cstring)
SDL_RaiseWindow_Proc     :: proc "c" (window: rawptr)
SDL_WarpMouseInWindow_Proc :: proc "c" (window: rawptr, x, y: f32)
SDL_GetWindowRelativeMouseMode_Proc :: proc "c" (window: rawptr) -> SDLBool
SDL_SetWindowRelativeMouseMode_Proc :: proc "c" (window: rawptr, enabled: SDLBool) -> SDLBool
SDL_StartTextInput_Proc  :: proc "c" (window: rawptr) -> SDLBool
SDL_StopTextInput_Proc   :: proc "c" (window: rawptr) -> SDLBool
SDL_TextInputActive_Proc :: proc "c" (window: rawptr) -> SDLBool

sdl_init_ptr: SDL_Init_Proc
sdl_quit_ptr: SDL_Quit_Proc
sdl_get_version_ptr: SDL_GetVersion_Proc
sdl_get_error_ptr: SDL_GetError_Proc
sdl_set_hint_ptr: SDL_SetHint_Proc
sdl_set_log_output_function_ptr: SDL_SetLogOutputFunction_Proc
sdl_pump_events_ptr: SDL_PumpEvents_Proc
sdl_poll_event_ptr: SDL_PollEvent_Proc

sdl_create_window_ptr: SDL_CreateWindow_Proc
sdl_destroy_window_ptr: SDL_DestroyWindow_Proc
sdl_show_window_ptr: SDL_ShowWindow_Proc
sdl_hide_window_ptr: SDL_HideWindow_Proc
sdl_get_window_id_ptr: SDL_GetWindowID_Proc
sdl_get_window_position_ptr: SDL_GetWindowPosition_Proc
sdl_set_window_position_ptr: SDL_SetWindowPosition_Proc
sdl_get_window_size_ptr: SDL_GetWindowSize_Proc
sdl_set_window_size_ptr: SDL_SetWindowSize_Proc
sdl_get_window_size_in_pixels_ptr: SDL_GetWindowSizeInPixels_Proc
sdl_get_window_flags_ptr: SDL_GetWindowFlags_Proc
sdl_set_window_title_ptr: SDL_SetWindowTitle_Proc
sdl_raise_window_ptr: SDL_RaiseWindow_Proc
sdl_warp_mouse_in_window_ptr: SDL_WarpMouseInWindow_Proc
sdl_get_window_relative_mouse_mode_ptr: SDL_GetWindowRelativeMouseMode_Proc
sdl_set_window_relative_mouse_mode_ptr: SDL_SetWindowRelativeMouseMode_Proc
sdl_start_text_input_ptr: SDL_StartTextInput_Proc
sdl_stop_text_input_ptr: SDL_StopTextInput_Proc
sdl_text_input_active_ptr: SDL_TextInputActive_Proc

sdl_require_loaded :: proc() {
	if sdl_library_loaded() {
		return
	}
	sdl_load_library()

	load_proc :: proc(name: cstring) -> rawptr {
		p := sdl_get_proc(name)
		if p == nil {
			panic("Missing SDL3 symbol")
		}
		return p
	}

	sdl_init_ptr = cast(SDL_Init_Proc)load_proc("SDL_Init")
	sdl_quit_ptr = cast(SDL_Quit_Proc)load_proc("SDL_Quit")
	sdl_get_version_ptr = cast(SDL_GetVersion_Proc)load_proc("SDL_GetVersion")
	sdl_get_error_ptr = cast(SDL_GetError_Proc)load_proc("SDL_GetError")
	sdl_set_hint_ptr = cast(SDL_SetHint_Proc)load_proc("SDL_SetHint")
	sdl_set_log_output_function_ptr = cast(SDL_SetLogOutputFunction_Proc)load_proc("SDL_SetLogOutputFunction")
	sdl_pump_events_ptr = cast(SDL_PumpEvents_Proc)load_proc("SDL_PumpEvents")
	sdl_poll_event_ptr = cast(SDL_PollEvent_Proc)load_proc("SDL_PollEvent")

	sdl_create_window_ptr = cast(SDL_CreateWindow_Proc)load_proc("SDL_CreateWindow")
	sdl_destroy_window_ptr = cast(SDL_DestroyWindow_Proc)load_proc("SDL_DestroyWindow")
	sdl_show_window_ptr = cast(SDL_ShowWindow_Proc)load_proc("SDL_ShowWindow")
	sdl_hide_window_ptr = cast(SDL_HideWindow_Proc)load_proc("SDL_HideWindow")
	sdl_get_window_id_ptr = cast(SDL_GetWindowID_Proc)load_proc("SDL_GetWindowID")
	sdl_get_window_position_ptr = cast(SDL_GetWindowPosition_Proc)load_proc("SDL_GetWindowPosition")
	sdl_set_window_position_ptr = cast(SDL_SetWindowPosition_Proc)load_proc("SDL_SetWindowPosition")
	sdl_get_window_size_ptr = cast(SDL_GetWindowSize_Proc)load_proc("SDL_GetWindowSize")
	sdl_set_window_size_ptr = cast(SDL_SetWindowSize_Proc)load_proc("SDL_SetWindowSize")
	sdl_get_window_size_in_pixels_ptr = cast(SDL_GetWindowSizeInPixels_Proc)load_proc("SDL_GetWindowSizeInPixels")
	sdl_get_window_flags_ptr = cast(SDL_GetWindowFlags_Proc)load_proc("SDL_GetWindowFlags")
	sdl_set_window_title_ptr = cast(SDL_SetWindowTitle_Proc)load_proc("SDL_SetWindowTitle")
	sdl_raise_window_ptr = cast(SDL_RaiseWindow_Proc)load_proc("SDL_RaiseWindow")
	sdl_warp_mouse_in_window_ptr = cast(SDL_WarpMouseInWindow_Proc)load_proc("SDL_WarpMouseInWindow")
	sdl_get_window_relative_mouse_mode_ptr = cast(SDL_GetWindowRelativeMouseMode_Proc)load_proc("SDL_GetWindowRelativeMouseMode")
	sdl_set_window_relative_mouse_mode_ptr = cast(SDL_SetWindowRelativeMouseMode_Proc)load_proc("SDL_SetWindowRelativeMouseMode")
	sdl_start_text_input_ptr = cast(SDL_StartTextInput_Proc)load_proc("SDL_StartTextInput")
	sdl_stop_text_input_ptr = cast(SDL_StopTextInput_Proc)load_proc("SDL_StopTextInput")
	sdl_text_input_active_ptr = cast(SDL_TextInputActive_Proc)load_proc("SDL_TextInputActive")
}

SDL_Init :: proc(flags: SDL_InitFlags) -> bool {
	sdl_require_loaded()
	return sdl_bool_to_bool(sdl_init_ptr(flags))
}

SDL_Quit :: proc() {
	if !sdl_library_loaded() {
		return
	}
	sdl_quit_ptr()
}

SDL_GetVersion :: proc() -> i32 {
	sdl_require_loaded()
	return sdl_get_version_ptr()
}

SDL_GetError :: proc() -> cstring {
	sdl_require_loaded()
	return sdl_get_error_ptr()
}

SDL_SetHint :: proc(name, value: cstring) -> bool {
	sdl_require_loaded()
	return sdl_bool_to_bool(sdl_set_hint_ptr(name, value))
}

SDL_SetLogOutputFunction :: proc(callback: rawptr, userdata: rawptr) {
	sdl_require_loaded()
	sdl_set_log_output_function_ptr(callback, userdata)
}

SDL_PumpEvents :: proc() {
	sdl_require_loaded()
	sdl_pump_events_ptr()
}

SDL_PollEvent :: proc(event: ^SDL_Event) -> bool {
	sdl_require_loaded()
	return sdl_bool_to_bool(sdl_poll_event_ptr(event))
}

SDL_CreateWindow :: proc(title: cstring, w, h: i32, flags: SDL_WindowFlags) -> rawptr {
	sdl_require_loaded()
	return sdl_create_window_ptr(title, w, h, flags)
}

SDL_DestroyWindow :: proc(window: rawptr) { sdl_require_loaded(); sdl_destroy_window_ptr(window) }
SDL_ShowWindow :: proc(window: rawptr) -> bool { sdl_require_loaded(); return sdl_bool_to_bool(sdl_show_window_ptr(window)) }
SDL_HideWindow :: proc(window: rawptr) -> bool { sdl_require_loaded(); return sdl_bool_to_bool(sdl_hide_window_ptr(window)) }
SDL_GetWindowID :: proc(window: rawptr) -> u32 { sdl_require_loaded(); return sdl_get_window_id_ptr(window) }
SDL_GetWindowPosition :: proc(window: rawptr, x, y: ^i32) { sdl_require_loaded(); sdl_get_window_position_ptr(window, x, y) }
SDL_SetWindowPosition :: proc(window: rawptr, x, y: i32) { sdl_require_loaded(); sdl_set_window_position_ptr(window, x, y) }
SDL_GetWindowSize :: proc(window: rawptr, w, h: ^i32) { sdl_require_loaded(); sdl_get_window_size_ptr(window, w, h) }
SDL_SetWindowSize :: proc(window: rawptr, w, h: i32) { sdl_require_loaded(); sdl_set_window_size_ptr(window, w, h) }
SDL_GetWindowSizeInPixels :: proc(window: rawptr, w, h: ^i32) { sdl_require_loaded(); sdl_get_window_size_in_pixels_ptr(window, w, h) }
SDL_GetWindowFlags :: proc(window: rawptr) -> SDL_WindowFlags { sdl_require_loaded(); return sdl_get_window_flags_ptr(window) }
SDL_SetWindowTitle :: proc(window: rawptr, title: cstring) { sdl_require_loaded(); sdl_set_window_title_ptr(window, title) }
SDL_RaiseWindow :: proc(window: rawptr) { sdl_require_loaded(); sdl_raise_window_ptr(window) }
SDL_WarpMouseInWindow :: proc(window: rawptr, x, y: f32) { sdl_require_loaded(); sdl_warp_mouse_in_window_ptr(window, x, y) }
SDL_GetWindowRelativeMouseMode :: proc(window: rawptr) -> bool { sdl_require_loaded(); return sdl_bool_to_bool(sdl_get_window_relative_mouse_mode_ptr(window)) }
SDL_SetWindowRelativeMouseMode :: proc(window: rawptr, enabled: bool) -> bool { sdl_require_loaded(); return sdl_bool_to_bool(sdl_set_window_relative_mouse_mode_ptr(window, sdl_bool(enabled))) }
SDL_StartTextInput :: proc(window: rawptr) -> bool { sdl_require_loaded(); return sdl_bool_to_bool(sdl_start_text_input_ptr(window)) }
SDL_StopTextInput :: proc(window: rawptr) -> bool { sdl_require_loaded(); return sdl_bool_to_bool(sdl_stop_text_input_ptr(window)) }
SDL_TextInputActive :: proc(window: rawptr) -> bool { sdl_require_loaded(); return sdl_bool_to_bool(sdl_text_input_active_ptr(window)) }
