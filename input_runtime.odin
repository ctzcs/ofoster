package foster_framework

import "core:math"
import coretime "core:time"
import SDL "vendor:sdl3"

ControllerID :: distinct u32

Keys :: enum int {
	Unknown = 0,
	A = 4, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
	D1 = 30, D2, D3, D4, D5, D6, D7, D8, D9, D0,
	Enter = 40,
	Escape,
	Backspace,
	Tab,
	Space,
	Minus,
	Equals,
	LeftBracket,
	RightBracket,
	Backslash,
	Semicolon = 51,
	Apostrophe,
	Tilde,
	Comma,
	Period,
	Slash,
	Capslock,
	F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
	PrintScreen = 70,
	ScrollLock,
	Pause,
	Insert,
	Home,
	PageUp,
	Delete,
	End,
	PageDown,
	Right,
	Left,
	Down,
	Up,
	Numlock,
	Application = 101,
	KeypadEquals = 103,
	F13 = 104, F14, F15, F16, F17, F18, F19, F20, F21, F22, F23, F24,
	Execute = 116,
	Help,
	Menu,
	Select,
	Stop,
	Redo,
	Undo,
	Cut,
	Copy,
	Paste,
	Find,
	Mute,
	VolumeUp,
	VolumeDown,
	KeypadComma = 133,
	AltErase = 153,
	SysReq,
	Cancel,
	Clear,
	Prior,
	Enter2,
	Separator,
	Out,
	Oper,
	ClearAgain,
	Keypad00 = 176,
	Keypad000,
	KeypadLeftParen = 182,
	KeypadRightParen,
	KeypadLeftBrace,
	KeypadRightBrace,
	KeypadTab,
	KeypadBackspace,
	KeypadA,
	KeypadB,
	KeypadC,
	KeypadD,
	KeypadE,
	KeypadF,
	KeypadXor,
	KeypadPower,
	KeypadPercent,
	KeypadLess,
	KeypadGreater,
	KeypadAmpersand = 199,
	KeypadColon = 203,
	KeypadHash,
	KeypadSpace,
	KeypadClear = 216,
	LeftControl = 224,
	LeftShift,
	LeftAlt,
	LeftOS,
	RightControl,
	RightShift,
	RightAlt,
	RightOS,
	KeypadDivide = 84,
	KeypadMultiply = 85,
	KeypadMinus = 86,
	KeypadPlus = 87,
	KeypadEnter = 88,
	Keypad1 = 89,
	Keypad2 = 90,
	Keypad3 = 91,
	Keypad4 = 92,
	Keypad5 = 93,
	Keypad6 = 94,
	Keypad7 = 95,
	Keypad8 = 96,
	Keypad9 = 97,
	Keypad0 = 98,
	KeypadPeroid = 99,
}

Buttons :: enum int {
	None = -1,
	South = 0,
	East,
	West,
	North,
	Back,
	Guide,
	Start,
	LeftStick,
	RightStick,
	LeftShoulder,
	RightShoulder,
	Up,
	Down,
	Left,
	Right,
}

Axes :: enum int {
	None = -1,
	LeftX = 0,
	LeftY,
	RightX,
	RightY,
	LeftTrigger,
	RightTrigger,
}

GamepadProviders :: enum {
	Unknown,
	Xbox,
	PlayStation,
	Nintendo,
}

GamepadTypes :: enum int {
	Unknown = 0,
	Standard,
	Xbox360,
	XboxOne,
	PS3,
	PS4,
	PS5,
	NintendoSwitchPro,
	NintendoSwitchJoyconLeft,
	NintendoSwitchJoyconRight,
	NintendoSwitchJoyconPair,
}

provider :: proc(t: GamepadTypes) -> GamepadProviders {
	#partial switch t {
	case .Standard, .Xbox360, .XboxOne:
		return .Xbox
	case .PS3, .PS4, .PS5:
		return .PlayStation
	case .NintendoSwitchPro, .NintendoSwitchJoyconLeft, .NintendoSwitchJoyconRight, .NintendoSwitchJoyconPair:
		return .Nintendo
	}
	return .Unknown
}

MouseButtons :: enum int {
	None = 0,
	Left = 1,
	Middle = 2,
	Right = 3,
}

Vec2f :: struct {
	X: f32,
	Y: f32,
}

InputEnabledFlag :: enum u8 {
	KeyboardKeys,
	Text,
	ControllerButtons,
	ControllerAxis,
	MouseButtons,
	MouseMotion,
	MouseWheel,
}

InputEnabledFlags :: distinct bit_set[InputEnabledFlag; u8]

InputEnabledAll : InputEnabledFlags : {.KeyboardKeys, .Text, .ControllerButtons, .ControllerAxis, .MouseButtons, .MouseMotion, .MouseWheel}
InputEnabledNone : InputEnabledFlags : {}

RepeatDelay: f32 = 0.4
RepeatInterval: f32 = 0.03

TextInputHandlerFn :: #type proc(text: string, window: ^Window)
ControllerConnectedFn :: #type proc(id: ControllerID)
ControllerDisconnectedFn :: #type proc(id: ControllerID)

KeyboardMaxKeys :: 512
MouseMaxButtons :: 5
ControllerMaxButtons :: 64
ControllerMaxAxes :: 64
InputMaxControllers :: 32

KeyboardState :: struct {
	Text: string,
	InputTimestamp: coretime.Duration,
	pressed: [KeyboardMaxKeys]bool,
	down: [KeyboardMaxKeys]bool,
	released: [KeyboardMaxKeys]bool,
	timestamp: [KeyboardMaxKeys]coretime.Duration,
	time: Time,
}

MouseState :: struct {
	InputTimestamp: coretime.Duration,
	Position: Vec2f,
	Delta: Vec2f,
	Wheel: Vec2f,
	pressed: [MouseMaxButtons]bool,
	down: [MouseMaxButtons]bool,
	released: [MouseMaxButtons]bool,
	timestamp: [MouseMaxButtons]coretime.Duration,
	motion_timestamp: coretime.Duration,
	time: Time,
}

ControllerState :: struct {
	Index: int,
	ID: ControllerID,
	Name: string,
	Connected: bool,
	IsGamepad: bool,
	InputTimestamp: coretime.Duration,
	GamepadType: GamepadTypes,
	Buttons: int,
	Axes: int,
	Vendor: u16,
	Product: u16,
	Version: u16,
	pressed: [ControllerMaxButtons]bool,
	down: [ControllerMaxButtons]bool,
	released: [ControllerMaxButtons]bool,
	timestamp: [ControllerMaxButtons]coretime.Duration,
	axis: [ControllerMaxAxes]f32,
	axis_timestamp: [ControllerMaxAxes]coretime.Duration,
	time: Time,
}

InputState :: struct {
	Keyboard: KeyboardState,
	Mouse: MouseState,
	Controllers: [InputMaxControllers]ControllerState,
}

JoystickHandle :: struct {
	ID: SDL.JoystickID,
	Ptr: ^SDL.Joystick,
}

GamepadHandle :: struct {
	ID: SDL.JoystickID,
	Ptr: ^SDL.Gamepad,
}

Input :: struct {
	App: ^App,
	State: InputState,
	LastState: InputState,
	NextState: InputState,
	Enabled: InputEnabledFlags,
	OnTextEvent: TextInputHandlerFn,
	OnControllerConnected: ControllerConnectedFn,
	OnControllerDisconnected: ControllerDisconnectedFn,
	last_mouse: Vec2f,
	open_joysticks: [dynamic]JoystickHandle,
	open_gamepads: [dynamic]GamepadHandle,
}

time_seconds :: proc(d: coretime.Duration) -> f64 {
	return coretime.duration_seconds(d)
}

trigger_repeat :: proc(time: Time, stamp: coretime.Duration, delay, interval: f32) -> bool {
	elapsed := time_seconds(time.Elapsed)
	previous := time_seconds(time.Previous)
	start := time_seconds(stamp) + f64(delay)
	if elapsed < start {
		return false
	}
	a := int(math.floor((previous - start) / f64(interval)))
	b := int(math.floor((elapsed - start) / f64(interval)))
	return b > a
}

keyboard_clear :: proc(k: ^KeyboardState) {
	k.Text = ""
	k.InputTimestamp = 0
	for i in 0..<KeyboardMaxKeys {
		k.pressed[i] = false
		k.down[i] = false
		k.released[i] = false
		k.timestamp[i] = 0
	}
}

keyboard_copy :: proc(dst: ^KeyboardState, src: KeyboardState) {
	dst.Text = src.Text
	dst.InputTimestamp = src.InputTimestamp
	dst.time = src.time
	dst.pressed = src.pressed
	dst.down = src.down
	dst.released = src.released
	dst.timestamp = src.timestamp
}

keyboard_step :: proc(k: ^KeyboardState, time: Time) {
	k.time = time
	k.Text = ""
	for i in 0..<KeyboardMaxKeys {
		k.pressed[i] = false
		k.released[i] = false
	}
}

keyboard_on_key :: proc(k: ^KeyboardState, key_index: int, pressed: bool, stamp: coretime.Duration) {
	if key_index < 0 || key_index >= KeyboardMaxKeys {
		return
	}
	if pressed {
		k.down[key_index] = true
		k.pressed[key_index] = true
		k.timestamp[key_index] = stamp
		k.InputTimestamp = stamp
	} else {
		k.down[key_index] = false
		k.released[key_index] = true
	}
}

mouse_clear :: proc(m: ^MouseState) {
	m.InputTimestamp = 0
	m.Position = {}
	m.Delta = {}
	m.Wheel = {}
	m.motion_timestamp = 0
	for i in 0..<MouseMaxButtons {
		m.pressed[i] = false
		m.down[i] = false
		m.released[i] = false
		m.timestamp[i] = 0
	}
}

mouse_copy :: proc(dst: ^MouseState, src: MouseState) {
	dst.InputTimestamp = src.InputTimestamp
	dst.Position = src.Position
	dst.Delta = src.Delta
	dst.Wheel = src.Wheel
	dst.motion_timestamp = src.motion_timestamp
	dst.time = src.time
	dst.pressed = src.pressed
	dst.down = src.down
	dst.released = src.released
	dst.timestamp = src.timestamp
}

mouse_step :: proc(m: ^MouseState, time: Time) {
	m.time = time
	m.Delta = {}
	m.Wheel = {}
	for i in 0..<MouseMaxButtons {
		m.pressed[i] = false
		m.released[i] = false
	}
}

mouse_on_button :: proc(m: ^MouseState, button_index: int, pressed: bool, stamp: coretime.Duration) {
	if button_index < 0 || button_index >= MouseMaxButtons {
		return
	}
	if pressed {
		m.down[button_index] = true
		m.pressed[button_index] = true
		m.timestamp[button_index] = stamp
		m.InputTimestamp = stamp
	} else {
		m.down[button_index] = false
		m.released[button_index] = true
	}
}

mouse_on_motion :: proc(m: ^MouseState, position, delta: Vec2f, stamp: coretime.Duration) {
	m.Position = position
	m.Delta = delta
	m.motion_timestamp = stamp
	m.InputTimestamp = stamp
}

mouse_on_wheel :: proc(m: ^MouseState, wheel: Vec2f) {
	m.Wheel = wheel
}

controller_clear_state :: proc(c: ^ControllerState) {
	c.InputTimestamp = 0
	for i in 0..<ControllerMaxButtons {
		c.pressed[i] = false
		c.down[i] = false
		c.released[i] = false
		c.timestamp[i] = 0
	}
	for i in 0..<ControllerMaxAxes {
		c.axis[i] = 0
		c.axis_timestamp[i] = 0
	}
}

controller_disconnect :: proc(c: ^ControllerState) {
	c.ID = ControllerID(0)
	c.Name = "Unknown"
	c.Connected = false
	c.IsGamepad = false
	c.GamepadType = .Unknown
	c.Buttons = 0
	c.Axes = 0
	c.Vendor = 0
	c.Product = 0
	c.Version = 0
	controller_clear_state(c)
}

controller_copy :: proc(dst: ^ControllerState, src: ControllerState) {
	dst.Index = src.Index
	dst.ID = src.ID
	dst.Name = src.Name
	dst.Connected = src.Connected
	dst.IsGamepad = src.IsGamepad
	dst.InputTimestamp = src.InputTimestamp
	dst.GamepadType = src.GamepadType
	dst.Buttons = src.Buttons
	dst.Axes = src.Axes
	dst.Vendor = src.Vendor
	dst.Product = src.Product
	dst.Version = src.Version
	dst.time = src.time
	dst.pressed = src.pressed
	dst.down = src.down
	dst.released = src.released
	dst.timestamp = src.timestamp
	dst.axis = src.axis
	dst.axis_timestamp = src.axis_timestamp
}

controller_step :: proc(c: ^ControllerState, time: Time) {
	c.time = time
	for i in 0..<ControllerMaxButtons {
		c.pressed[i] = false
		c.released[i] = false
	}
}

controller_connect :: proc(c: ^ControllerState, id: ControllerID, name: string, button_count, axis_count: int, is_gamepad: bool, gamepad_type: GamepadTypes, vendor, product, version: u16) {
	c.ID = id
	c.Name = name
	c.Connected = true
	c.IsGamepad = is_gamepad
	c.GamepadType = gamepad_type
	c.Buttons = min(button_count, ControllerMaxButtons)
	c.Axes = min(axis_count, ControllerMaxAxes)
	c.Vendor = vendor
	c.Product = product
	c.Version = version
}

controller_on_button :: proc(c: ^ControllerState, button_index: int, pressed: bool, stamp: coretime.Duration) {
	if button_index < 0 || button_index >= ControllerMaxButtons {
		return
	}
	if pressed {
		c.down[button_index] = true
		c.pressed[button_index] = true
		c.timestamp[button_index] = stamp
		c.InputTimestamp = stamp
	} else {
		c.down[button_index] = false
		c.released[button_index] = true
	}
}

controller_on_axis :: proc(c: ^ControllerState, axis_index: int, value: f32, stamp: coretime.Duration) {
	if axis_index < 0 || axis_index >= ControllerMaxAxes {
		return
	}
	c.axis[axis_index] = value
	c.axis_timestamp[axis_index] = stamp
	if math.abs(value) > 0.5 {
		c.InputTimestamp = stamp
	}
}

input_state_init :: proc(state: ^InputState) {
	keyboard_clear(&state.Keyboard)
	mouse_clear(&state.Mouse)
	for i in 0..<InputMaxControllers {
		state.Controllers[i].Index = i
		controller_disconnect(&state.Controllers[i])
	}
}

input_state_copy :: proc(dst: ^InputState, src: InputState) {
	keyboard_copy(&dst.Keyboard, src.Keyboard)
	mouse_copy(&dst.Mouse, src.Mouse)
	for i in 0..<InputMaxControllers {
		controller_copy(&dst.Controllers[i], src.Controllers[i])
	}
}

input_state_step :: proc(state: ^InputState, time: Time) {
	keyboard_step(&state.Keyboard, time)
	mouse_step(&state.Mouse, time)
	for i in 0..<InputMaxControllers {
		if state.Controllers[i].Connected {
			controller_step(&state.Controllers[i], time)
		}
	}
}

input_init :: proc(input: ^Input, app: ^App) {
	input.App = app
	input.Enabled = InputEnabledAll
	input_state_init(&input.State)
	input_state_init(&input.LastState)
	input_state_init(&input.NextState)
}

input_step :: proc(input: ^Input, time: Time) {
	input_state_copy(&input.LastState, input.State)
	input_state_copy(&input.State, input.NextState)
	input_state_step(&input.NextState, time)
}

get_controller :: proc(input: ^Input, id: ControllerID) -> ^ControllerState {
	for i in 0..<InputMaxControllers {
		if input.State.Controllers[i].ID == id {
			return &input.State.Controllers[i]
		}
	}
	return nil
}

get_next_controller :: proc(input: ^Input, id: ControllerID) -> ^ControllerState {
	for i in 0..<InputMaxControllers {
		if input.NextState.Controllers[i].ID == id {
			return &input.NextState.Controllers[i]
		}
	}
	return nil
}

input_connect_controller :: proc(input: ^Input, id: ControllerID, name: string, button_count, axis_count: int, is_gamepad: bool, gamepad_type: GamepadTypes, vendor, product, version: u16) {
	for i in 0..<InputMaxControllers {
		if input.NextState.Controllers[i].Connected {
			continue
		}
		controller_connect(&input.NextState.Controllers[i], id, name, button_count, axis_count, is_gamepad, gamepad_type, vendor, product, version)
		if input.OnControllerConnected != nil {
			input.OnControllerConnected(id)
		}
		return
	}
}

input_disconnect_controller :: proc(input: ^Input, id: ControllerID) {
	for i in 0..<InputMaxControllers {
		if input.NextState.Controllers[i].ID != id {
			continue
		}
		controller_disconnect(&input.NextState.Controllers[i])
		if input.OnControllerDisconnected != nil {
			input.OnControllerDisconnected(id)
		}
		return
	}
}

input_key :: proc(input: ^Input, key: Keys, pressed: bool, stamp: coretime.Duration) {
	if !(.KeyboardKeys in input.Enabled) {
		return
	}
	keyboard_on_key(&input.NextState.Keyboard, int(key), pressed, stamp)
}

input_mouse_button :: proc(input: ^Input, button: MouseButtons, pressed: bool, stamp: coretime.Duration) {
	if !(.MouseButtons in input.Enabled) {
		return
	}
	mouse_on_button(&input.NextState.Mouse, int(button), pressed, stamp)
}

input_mouse_move :: proc(input: ^Input, position, delta: Vec2f, stamp: coretime.Duration) {
	if !(.MouseMotion in input.Enabled) {
		return
	}
	mouse_on_motion(&input.NextState.Mouse, position, delta, stamp)
}

input_mouse_wheel :: proc(input: ^Input, wheel: Vec2f) {
	if !(.MouseWheel in input.Enabled) {
		return
	}
	mouse_on_wheel(&input.NextState.Mouse, wheel)
}

input_text :: proc(input: ^Input, text: string, window: ^Window) {
	if !(.Text in input.Enabled) || text == "" {
		return
	}
	input.NextState.Keyboard.Text = text
	if input.OnTextEvent != nil {
		input.OnTextEvent(text, window)
	}
}

input_controller_button :: proc(input: ^Input, id: ControllerID, button: int, pressed: bool, stamp: coretime.Duration) {
	if !(.ControllerButtons in input.Enabled) {
		return
	}
	controller := get_next_controller(input, id)
	if controller != nil {
		controller_on_button(controller, button, pressed, stamp)
	}
}

input_controller_axis :: proc(input: ^Input, id: ControllerID, axis: int, value: f32, stamp: coretime.Duration) {
	if !(.ControllerAxis in input.Enabled) {
		return
	}
	controller := get_next_controller(input, id)
	if controller != nil {
		controller_on_axis(controller, axis, value, stamp)
	}
}

input_update :: proc(input: ^Input, window: ^Window, stamp: coretime.Duration) {
	if window == nil || window.Handle == nil {
		return
	}

	// Wayland 不提供屏幕全局坐标(GetGlobalMouseState 与窗口位置恒为 0),
	// 导致鼠标位置永远停在 (0,0)、所有点击判定失效。
	// 改用窗口相对坐标的 GetMouseState: 各平台一致且 Wayland 安全。
	wx, wy: f32
	_ = SDL.GetMouseState(&wx, &wy)
	size := window_size(window)
	size_px := window_size_in_pixels(window)

	mouse_x := wx
	mouse_y := wy
	if size.X != 0 && size.Y != 0 {
		mouse_x = mouse_x / f32(size.X) * f32(size_px.X)
		mouse_y = mouse_y / f32(size.Y) * f32(size_px.Y)
	}

	delta := Vec2f{mouse_x - input.last_mouse.X, mouse_y - input.last_mouse.Y}
	if SDL.GetWindowRelativeMouseMode(window.Handle) {
		dx, dy: f32
		_ = SDL.GetRelativeMouseState(&dx, &dy)
		if size.X != 0 && size.Y != 0 {
			delta = Vec2f{dx / f32(size.X) * f32(size_px.X), dy / f32(size.Y) * f32(size_px.Y)}
		} else {
			delta = Vec2f{dx, dy}
		}
	}

	position := Vec2f{mouse_x, mouse_y}
	if position.X != input.last_mouse.X || position.Y != input.last_mouse.Y || delta.X != 0 || delta.Y != 0 {
		input.last_mouse = position
		input_mouse_move(input, position, delta, stamp)
	}
}

input_set_clipboard :: proc(input: ^Input, value: string) -> bool {
	_ = input
	return SDL.SetClipboardText(to_cstring(value))
}

input_get_clipboard :: proc(input: ^Input) -> string {
	_ = input
	text := SDL.GetClipboardText()
	if text == nil {
		return ""
	}
	return string(cstring(text))
}

input_rumble :: proc(input: ^Input, id: ControllerID, low_intensity, high_intensity, duration: f32) {
	_ = input
	low := u16(math.clamp(low_intensity, 0, 1) * 65535)
	high := u16(math.clamp(high_intensity, 0, 1) * 65535)
	ms := u32(duration * 1000)
	gamepad := SDL.GetGamepadFromID(cast(SDL.JoystickID)u32(id))
	if gamepad != nil {
		_ = SDL.RumbleGamepad(gamepad, low, high, ms)
		return
	}
	joystick := SDL.GetJoystickFromID(cast(SDL.JoystickID)u32(id))
	if joystick != nil {
		_ = SDL.RumbleJoystick(joystick, low, high, ms)
	}
}

input_close_devices :: proc(input: ^Input) {
	for joystick in input.open_joysticks {
		if joystick.Ptr != nil {
			SDL.CloseJoystick(joystick.Ptr)
		}
	}
	for gamepad in input.open_gamepads {
		if gamepad.Ptr != nil {
			SDL.CloseGamepad(gamepad.Ptr)
		}
	}
	delete(input.open_joysticks)
	delete(input.open_gamepads)
}

gamepad_name :: proc(ptr: ^SDL.Gamepad, fallback_id: SDL.JoystickID) -> string {
	if ptr != nil {
		return string(SDL.GetGamepadName(ptr))
	}
	return string(SDL.GetGamepadNameForID(fallback_id))
}

joystick_name :: proc(ptr: ^SDL.Joystick, fallback_id: SDL.JoystickID) -> string {
	if ptr != nil {
		return string(SDL.GetJoystickName(ptr))
	}
	return string(SDL.GetJoystickNameForID(fallback_id))
}

normalize_axis :: proc(value: i16) -> f32 {
	if value >= 0 {
		return f32(value) / 32767.0
	}
	return f32(value) / 32768.0
}

input_on_event :: proc(input: ^Input, window: ^Window, event: ^SDL.Event, stamp: coretime.Duration) {
	#partial switch event.type {
	case .MOUSE_BUTTON_DOWN:
		input_mouse_button(input, cast(MouseButtons)int(event.button.button), true, stamp)
	case .MOUSE_BUTTON_UP:
		input_mouse_button(input, cast(MouseButtons)int(event.button.button), false, stamp)
	case .MOUSE_WHEEL:
		input_mouse_wheel(input, Vec2f{event.wheel.x, event.wheel.y})
	case .KEY_DOWN:
		if !event.key.repeat {
			input_key(input, cast(Keys)int(event.key.scancode), true, stamp)
		}
	case .KEY_UP:
		if !event.key.repeat {
			input_key(input, cast(Keys)int(event.key.scancode), false, stamp)
		}
	case .TEXT_INPUT:
		input_text(input, string(event.text.text), window)
	case .JOYSTICK_ADDED:
		id := event.jdevice.which
		if SDL.IsGamepad(id) {
			break
		}
		ptr := SDL.OpenJoystick(id)
		append(&input.open_joysticks, JoystickHandle{id, ptr})
		input_connect_controller(input, ControllerID(u32(id)), joystick_name(ptr, id), int(SDL.GetNumJoystickButtons(ptr)), int(SDL.GetNumJoystickAxes(ptr)), false, .Unknown, u16(SDL.GetJoystickVendor(ptr)), u16(SDL.GetJoystickProduct(ptr)), u16(SDL.GetJoystickProductVersion(ptr)))
	case .JOYSTICK_REMOVED:
		id := event.jdevice.which
		if SDL.IsGamepad(id) {
			break
		}
		for i := len(input.open_joysticks) - 1; i >= 0; i -= 1 {
			if input.open_joysticks[i].ID == id {
				if input.open_joysticks[i].Ptr != nil {
					SDL.CloseJoystick(input.open_joysticks[i].Ptr)
				}
				ordered_remove(&input.open_joysticks, i)
			}
		}
		input_disconnect_controller(input, ControllerID(u32(id)))
	case .JOYSTICK_BUTTON_DOWN:
		if !SDL.IsGamepad(event.jbutton.which) {
			input_controller_button(input, ControllerID(u32(event.jbutton.which)), int(event.jbutton.button), true, stamp)
		}
	case .JOYSTICK_BUTTON_UP:
		if !SDL.IsGamepad(event.jbutton.which) {
			input_controller_button(input, ControllerID(u32(event.jbutton.which)), int(event.jbutton.button), false, stamp)
		}
	case .JOYSTICK_AXIS_MOTION:
		if !SDL.IsGamepad(event.jaxis.which) {
			input_controller_axis(input, ControllerID(u32(event.jaxis.which)), int(event.jaxis.axis), normalize_axis(event.jaxis.value), stamp)
		}
	case .GAMEPAD_ADDED:
		id := event.gdevice.which
		ptr := SDL.OpenGamepad(id)
		append(&input.open_gamepads, GamepadHandle{id, ptr})
		input_connect_controller(input, ControllerID(u32(id)), gamepad_name(ptr, id), 15, 6, true, cast(GamepadTypes)int(SDL.GetGamepadType(ptr)), u16(SDL.GetGamepadVendor(ptr)), u16(SDL.GetGamepadProduct(ptr)), u16(SDL.GetGamepadProductVersion(ptr)))
	case .GAMEPAD_REMOVED:
		id := event.gdevice.which
		for i := len(input.open_gamepads) - 1; i >= 0; i -= 1 {
			if input.open_gamepads[i].ID == id {
				if input.open_gamepads[i].Ptr != nil {
					SDL.CloseGamepad(input.open_gamepads[i].Ptr)
				}
				ordered_remove(&input.open_gamepads, i)
			}
		}
		input_disconnect_controller(input, ControllerID(u32(id)))
	case .GAMEPAD_BUTTON_DOWN:
		input_controller_button(input, ControllerID(u32(event.gbutton.which)), int(cast(SDL.GamepadButton)event.gbutton.button), true, stamp)
	case .GAMEPAD_BUTTON_UP:
		input_controller_button(input, ControllerID(u32(event.gbutton.which)), int(cast(SDL.GamepadButton)event.gbutton.button), false, stamp)
	case .GAMEPAD_AXIS_MOTION:
		input_controller_axis(input, ControllerID(u32(event.gaxis.which)), int(cast(SDL.GamepadAxis)event.gaxis.axis), normalize_axis(event.gaxis.value), stamp)
	}
}

Pressed :: proc(state: ^KeyboardState, key: Keys) -> bool { i:=int(key);return state!=nil&&i>=0&&i<KeyboardMaxKeys&&state.pressed[i] }
Down :: proc(state: ^KeyboardState, key: Keys) -> bool { i:=int(key);return state!=nil&&i>=0&&i<KeyboardMaxKeys&&state.down[i] }
Released :: proc(state: ^KeyboardState, key: Keys) -> bool { i:=int(key);return state!=nil&&i>=0&&i<KeyboardMaxKeys&&state.released[i] }
Timestamp :: proc(state: ^KeyboardState, key: Keys) -> coretime.Duration { i:=int(key);if state==nil||i<0||i>=KeyboardMaxKeys{return 0};return state.timestamp[i] }
Repeated :: proc(state: ^KeyboardState, key: Keys, delay := RepeatDelay, interval := RepeatInterval) -> bool {
	if Pressed(state, key) { return true }
	return Down(state, key) && trigger_repeat(state.time, Timestamp(state, key), delay, interval)
}
PressedOrRepeated :: proc(state: ^KeyboardState, key: Keys, delay := RepeatDelay, interval := RepeatInterval) -> bool { return Pressed(state, key) || Repeated(state, key, delay, interval) }
KeyboardFirstDown :: proc(state:^KeyboardState)->(Keys,bool){if state==nil{return .Unknown,false};for i in 0..<KeyboardMaxKeys{if state.down[i]{return Keys(i),true}};return .Unknown,false}
KeyboardFirstPressed :: proc(state:^KeyboardState)->(Keys,bool){if state==nil{return .Unknown,false};for i in 0..<KeyboardMaxKeys{if state.pressed[i]{return Keys(i),true}};return .Unknown,false}
KeyboardFirstReleased :: proc(state:^KeyboardState)->(Keys,bool){if state==nil{return .Unknown,false};for i in 0..<KeyboardMaxKeys{if state.released[i]{return Keys(i),true}};return .Unknown,false}
KeyboardCtrl :: proc(state:^KeyboardState)->bool{return state!=nil&&(Down(state,.LeftControl)||Down(state,.RightControl))}
KeyboardShift :: proc(state:^KeyboardState)->bool{return state!=nil&&(Down(state,.LeftShift)||Down(state,.RightShift))}
KeyboardAlt :: proc(state:^KeyboardState)->bool{return state!=nil&&(Down(state,.LeftAlt)||Down(state,.RightAlt))}
KeyboardCtrlTimestamp :: proc(state:^KeyboardState)->coretime.Duration{if state==nil{return 0};a:=Timestamp(state,.LeftControl);b:=Timestamp(state,.RightControl);if a>b{return a};return b}
KeyboardShiftTimestamp :: proc(state:^KeyboardState)->coretime.Duration{if state==nil{return 0};a:=Timestamp(state,.LeftShift);b:=Timestamp(state,.RightShift);if a>b{return a};return b}
KeyboardAltTimestamp :: proc(state:^KeyboardState)->coretime.Duration{if state==nil{return 0};a:=Timestamp(state,.LeftAlt);b:=Timestamp(state,.RightAlt);if a>b{return a};return b}
KeyboardCtrlOrCommand :: KeyboardCtrl
KeyboardCtrlOrCommandTimestamp :: KeyboardCtrlTimestamp

MousePressed :: proc(state: ^MouseState, button: MouseButtons) -> bool { i:=int(button);return state!=nil&&i>=0&&i<MouseMaxButtons&&state.pressed[i] }
MouseDown :: proc(state: ^MouseState, button: MouseButtons) -> bool { i:=int(button);return state!=nil&&i>=0&&i<MouseMaxButtons&&state.down[i] }
MouseReleased :: proc(state: ^MouseState, button: MouseButtons) -> bool { i:=int(button);return state!=nil&&i>=0&&i<MouseMaxButtons&&state.released[i] }
PressedTimestamp :: proc(state: ^MouseState, button: MouseButtons) -> coretime.Duration { i:=int(button);if state==nil||i<0||i>=MouseMaxButtons{return 0};return state.timestamp[i] }
MotionTimestamp :: proc(state: ^MouseState) -> coretime.Duration { if state == nil { return 0 }; return state.motion_timestamp }
MouseX :: proc(state:^MouseState)->f32{if state==nil{return 0};return state.Position.X}
MouseY :: proc(state:^MouseState)->f32{if state==nil{return 0};return state.Position.Y}
MouseLeftPressed :: proc(state:^MouseState)->bool{return MousePressed(state,.Left)}
MouseLeftDown :: proc(state:^MouseState)->bool{return MouseDown(state,.Left)}
MouseLeftReleased :: proc(state:^MouseState)->bool{return MouseReleased(state,.Left)}
MouseRightPressed :: proc(state:^MouseState)->bool{return MousePressed(state,.Right)}
MouseRightDown :: proc(state:^MouseState)->bool{return MouseDown(state,.Right)}
MouseRightReleased :: proc(state:^MouseState)->bool{return MouseReleased(state,.Right)}
MouseMiddlePressed :: proc(state:^MouseState)->bool{return MousePressed(state,.Middle)}
MouseMiddleDown :: proc(state:^MouseState)->bool{return MouseDown(state,.Middle)}
MouseMiddleReleased :: proc(state:^MouseState)->bool{return MouseReleased(state,.Middle)}
MouseRepeated :: proc(state:^MouseState,button:MouseButtons,delay:=RepeatDelay,interval:=RepeatInterval)->bool{if MousePressed(state,button){return true};if state==nil{return false};i:=int(button);if i<0||i>=MouseMaxButtons{return false};return MouseDown(state,button)&&trigger_repeat(state.time,state.timestamp[i],delay,interval)}

ControllerPressed :: proc(state: ^ControllerState, button: Buttons) -> bool { i:=int(button);return state!=nil&&i>=0&&i<ControllerMaxButtons&&state.pressed[i] }
ControllerDown :: proc(state: ^ControllerState, button: Buttons) -> bool { i:=int(button);return state!=nil&&i>=0&&i<ControllerMaxButtons&&state.down[i] }
ControllerReleased :: proc(state: ^ControllerState, button: Buttons) -> bool { i:=int(button);return state!=nil&&i>=0&&i<ControllerMaxButtons&&state.released[i] }
ControllerAxisValue :: proc(state: ^ControllerState, axis: Axes) -> f32 { i:=int(axis);if state==nil||i<0||i>=ControllerMaxAxes{return 0};return state.axis[i] }
ControllerTimestamp :: proc(state: ^ControllerState, button: Buttons) -> coretime.Duration { i:=int(button);if state==nil||i<0||i>=ControllerMaxButtons{return 0};return state.timestamp[i] }
ControllerAxisTimestamp :: proc(state: ^ControllerState, axis: Axes) -> coretime.Duration { i:=int(axis);if state==nil||i<0||i>=ControllerMaxAxes{return 0};return state.axis_timestamp[i] }
ControllerRepeated :: proc(state: ^ControllerState, button: Buttons, delay := RepeatDelay, interval := RepeatInterval) -> bool {
	if ControllerPressed(state, button) { return true }
	return ControllerDown(state, button) && trigger_repeat(state.time, ControllerTimestamp(state, button), delay, interval)
}
ControllerPressedOrRepeated :: proc(state:^ControllerState,button:Buttons,delay:=RepeatDelay,interval:=RepeatInterval)->bool{return ControllerPressed(state,button)||ControllerRepeated(state,button,delay,interval)}
ControllerGamepadProvider :: proc(state:^ControllerState)->GamepadProviders{if state==nil{return .Unknown};return provider(state.GamepadType)}
ControllerLeftStick :: proc(state:^ControllerState)->Vec2f{if state==nil{return {}};return Vec2f{state.axis[int(Axes.LeftX)],state.axis[int(Axes.LeftY)]}}
ControllerRightStick :: proc(state:^ControllerState)->Vec2f{if state==nil{return {}};return Vec2f{state.axis[int(Axes.RightX)],state.axis[int(Axes.RightY)]}}

GetController :: get_controller
InputStateClear :: proc(state:^InputState){if state==nil{return};input_state_init(state)}
InputStateSnapshot :: proc(state:^InputState)->InputState{result:InputState;input_state_copy(&result,state^);return result}
InputStateGetController :: proc(state:^InputState,id:ControllerID)->^ControllerState{if state==nil{return nil};for i:=0;i<InputMaxControllers;i+=1{if state.Controllers[i].Connected&&state.Controllers[i].ID==id{return &state.Controllers[i]}};return nil}
InputCreateEcho :: proc(input:^Input)->Input{if input==nil{return {}};return Input{App=input.App,Enabled=input.Enabled}}
SetClipboardString :: input_set_clipboard
GetClipboardString :: input_get_clipboard
Rumble :: input_rumble
AddSDLGamepadMapping :: proc(mapping: string) -> bool { return SDL.AddGamepadMapping(to_cstring(mapping)) >= 0 }
InputKey :: input_key
InputMouseButton :: input_mouse_button
InputMouseMove :: input_mouse_move
InputMouseWheel :: input_mouse_wheel
InputText :: input_text
InputControllerButton :: input_controller_button
InputControllerAxis :: input_controller_axis
InputInit :: input_init
InputStep :: input_step
