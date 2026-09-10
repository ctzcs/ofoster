package foster_framework

import "core:time"
import "core:math"

// ===== merged from Input/Bindings/Binding.odin =====


BindingKind :: enum { KeyboardKey, ControllerAxis, ControllerButton, MouseButton, MouseMotion }

// Binding is a compact tagged value.  Keeping the payload here makes bindings
// copyable and usable by the set types without requiring heap allocated
// interface values.
Binding :: struct {
	Kind: BindingKind,
	Key: Keys,
	Axis: Axes,
	Button: Buttons,
	MouseButton: MouseButtons,
	Sign: int,
	Deadzone: f32,
	MotionAxis: [2]f32,
	Min: f32,
	Max: f32,
}

BindingFromKeyboard :: proc(v: KeyboardKeyBinding) -> Binding { return Binding{Kind=.KeyboardKey, Key=v.Key} }
BindingFromControllerAxis :: proc(v: ControllerAxisBinding) -> Binding { return Binding{Kind=.ControllerAxis, Axis=v.Axis, Sign=v.Sign, Deadzone=v.Deadzone} }
BindingFromControllerButton :: proc(v: ControllerButtonBinding) -> Binding { return Binding{Kind=.ControllerButton, Button=v.Button} }
BindingFromMouseButton :: proc(v: MouseButtonBinding) -> Binding { return Binding{Kind=.MouseButton, MouseButton=v.Button} }
BindingFromMouseMotion :: proc(v: MouseMotionBinding) -> Binding { return Binding{Kind=.MouseMotion, MotionAxis=v.Axis, Sign=v.Sign, Min=v.Min, Max=v.Max} }

BindingDescriptor :: proc(binding: Binding) -> string {
	switch binding.Kind {
	case .KeyboardKey: return "Keyboard Key"
	case .ControllerAxis: return "Controller Axis"
	case .ControllerButton: return "Controller Button"
	case .MouseButton: return "Mouse Button"
	case .MouseMotion: return "Mouse Motion"
	}
	return "Binding"
}

binding_axis_value :: proc(binding: Binding, state: InputState, device: int) -> f32 {
	if device < 0 || device >= InputMaxControllers { return 0 }
	v := state.Controllers[device].axis[int(binding.Axis)] * f32(binding.Sign)
	return Clamp((v - binding.Deadzone) / (1 - binding.Deadzone), 0, 1)
}

BindingGetState :: proc(binding: Binding, input: ^Input, device: int) -> BindingState {
	result := BindingState{}
	switch binding.Kind {
	case .KeyboardKey:
		k := &input.State.Keyboard
		result = BindingState{Pressed=KeyboardPressed(k, binding.Key), Released=KeyboardReleased(k, binding.Key), Down=KeyboardDown(k, binding.Key), Value=0, Timestamp=Timestamp(k, binding.Key)}
		if result.Down { result.Value = 1 }
	case .ControllerButton:
		if device < 0 || device >= InputMaxControllers { return result }
		c := &input.State.Controllers[device]
		result = BindingState{Pressed=ControllerPressed(c, binding.Button), Released=ControllerReleased(c, binding.Button), Down=ControllerDown(c, binding.Button), Value=0, Timestamp=ControllerTimestamp(c, binding.Button)}
		if result.Down { result.Value = 1 }
	case .ControllerAxis:
		if device < 0 || device >= InputMaxControllers { return result }
		c := &input.State.Controllers[device]
		v := binding_axis_value(binding, input.State, device)
		prev := binding_axis_value(binding, input.LastState, device)
		result.Value = v
		result.Down = v > 0
		result.Pressed = v > 0 && prev <= 0
		result.Released = v <= 0 && prev > 0
		result.Timestamp = ControllerAxisTimestamp(c, binding.Axis)
	case .MouseButton:
		m := &input.State.Mouse
		result = BindingState{Pressed=MousePressed(m, binding.MouseButton), Released=MouseReleased(m, binding.MouseButton), Down=MouseDown(m, binding.MouseButton), Value=0, Timestamp=PressedTimestamp(m, binding.MouseButton)}
		if result.Down { result.Value = 1 }
	case .MouseMotion:
		m := &input.State.Mouse
		v := m.Delta.X*binding.MotionAxis[0] + m.Delta.Y*binding.MotionAxis[1]
		v *= f32(binding.Sign)
		if binding.Max > binding.Min { v = Clamp(v, binding.Min, binding.Max) }
		result.Value = Clamp(v, f32(0), f32(1))
		result.Down = result.Value > 0
		result.Pressed = result.Down
		result.Timestamp = MotionTimestamp(m)
	}
	return result
}

// ===== merged from Input/Bindings/BindingAxisOverlap.odin =====


BindingAxisOverlap :: enum { TakeNewer, TakeOlder, CancelOut }

BindingAxisOverlapResolve :: proc(overlap: BindingAxisOverlap, negative, positive: BindingState) -> f32 {
    if overlap == .CancelOut do return Clamp(positive.Value - negative.Value, -1, 1)
    if positive.Down && negative.Down {
        if overlap == .TakeNewer { if negative.Timestamp > positive.Timestamp do return -negative.Value; return positive.Value }
        if negative.Timestamp < positive.Timestamp do return -negative.Value; return positive.Value
    }
    if positive.Down do return positive.Value
    if negative.Down do return -negative.Value
    return 0
}

// ===== merged from Input/Bindings/BindingState.odin =====


BindingState :: struct { Pressed, Released, Down: bool, Value: f32, Timestamp: time.Duration }

// ===== merged from Input/Bindings/ControllerAxisBinding.odin =====


ControllerAxisBinding :: struct { Axis: Axes, Sign: int, Deadzone: f32 }
ControllerAxisBindingMake :: proc(axis: Axes, sign: int, deadzone: f32) -> ControllerAxisBinding { return ControllerAxisBinding{axis, sign, deadzone} }

// ===== merged from Input/Bindings/ControllerButtonBinding.odin =====


ControllerButtonBinding :: struct { Button: Buttons }
ControllerButtonBindingMake :: proc(button: Buttons) -> ControllerButtonBinding { return ControllerButtonBinding{button} }

// ===== merged from Input/Bindings/KeyboardKeyBinding.odin =====


KeyboardKeyBinding :: struct { Key: Keys }
KeyboardKeyBindingMake :: proc(key: Keys) -> KeyboardKeyBinding { return KeyboardKeyBinding{key} }
KeyboardKeyBindingDescriptor :: proc(binding: KeyboardKeyBinding) -> string { return "Keyboard Key" }

// ===== merged from Input/Bindings/MouseButtonBinding.odin =====


MouseButtonBinding :: struct { Button: MouseButtons }
MouseButtonBindingMake :: proc(button: MouseButtons) -> MouseButtonBinding { return MouseButtonBinding{button} }

// ===== merged from Input/Bindings/MouseMotionBinding.odin =====

MouseMotionBinding :: struct { Axis: [2]f32, Sign: int, Min, Max: f32 }
MouseMotionBindingMake :: proc(axis: [2]f32, sign: int, min_value, max_value: f32) -> MouseMotionBinding { return MouseMotionBinding{axis, sign, min_value, max_value} }

// ===== merged from Input/Sets/ActionBindingSet.odin =====


ActionEntry :: struct { Binding: Binding, Masks: [dynamic]string }
ActionBindingSet :: struct { Entries: [dynamic]ActionEntry }
ActionBindingSetMake :: proc() -> ActionBindingSet { return ActionBindingSet{} }
ActionBindingSetAdd :: proc(set: ^ActionBindingSet, binding: Binding, masks: ..string) {
	e := ActionEntry{Binding=binding}; for m in masks { append(&e.Masks, m) }; append(&set.Entries, e)
}
ActionBindingSetAddKey :: proc(set: ^ActionBindingSet, key: Keys, masks: ..string) { ActionBindingSetAdd(set, Binding{Kind=.KeyboardKey, Key=key}, ..masks[:]) }
ActionBindingSetAddButton :: proc(set: ^ActionBindingSet, button: Buttons, masks: ..string) { ActionBindingSetAdd(set, Binding{Kind=.ControllerButton, Button=button}, ..masks[:]) }
ActionBindingSetAddMouseButton :: proc(set: ^ActionBindingSet, button: MouseButtons, masks: ..string) { ActionBindingSetAdd(set, Binding{Kind=.MouseButton, MouseButton=button}, ..masks[:]) }
ActionBindingSetAddAxis :: proc(set: ^ActionBindingSet, axis: Axes, sign: int, deadzone := f32(0), masks: ..string) { ActionBindingSetAdd(set, Binding{Kind=.ControllerAxis, Axis=axis, Sign=sign, Deadzone=deadzone}, ..masks[:]) }
ActionBindingSetGetState :: proc(set: ^ActionBindingSet, input: ^Input, device: int) -> BindingState {
	r := BindingState{}
	for e in set.Entries { s := BindingGetState(e.Binding, input, device); r.Pressed |= s.Pressed; r.Released |= s.Released; r.Down |= s.Down; if s.Value > r.Value { r.Value = s.Value }; if s.Timestamp > r.Timestamp { r.Timestamp = s.Timestamp } }
	return r
}
ActionBindingSetClear :: proc(set: ^ActionBindingSet) { clear(&set.Entries) }
ActionBindingSet_ActionEntry :: ActionEntry


// ===== merged from Input/Sets/AxisBindingSet.odin =====


AxisEntry :: struct { Negative, Positive: Binding, Overlap: BindingAxisOverlap, Masks: [dynamic]string }
AxisBindingSet :: struct { Entries: [dynamic]AxisEntry }
AxisBindingSetAdd :: proc(set: ^AxisBindingSet, negative, positive: Binding, overlap := BindingAxisOverlap.TakeNewer, masks: ..string) {
	e := AxisEntry{Negative=negative, Positive=positive, Overlap=overlap}; for m in masks { append(&e.Masks, m) }; append(&set.Entries, e)
}
AxisBindingSetAddKeys :: proc(set: ^AxisBindingSet, negative, positive: Keys, overlap := BindingAxisOverlap.TakeNewer, masks: ..string) { AxisBindingSetAdd(set, Binding{Kind=.KeyboardKey, Key=negative}, Binding{Kind=.KeyboardKey, Key=positive}, overlap, ..masks[:]) }
AxisBindingSetAddButtons :: proc(set: ^AxisBindingSet, negative, positive: Buttons, overlap := BindingAxisOverlap.TakeNewer, masks: ..string) { AxisBindingSetAdd(set, Binding{Kind=.ControllerButton, Button=negative}, Binding{Kind=.ControllerButton, Button=positive}, overlap, ..masks[:]) }
AxisBindingSetAddAxis :: proc(set: ^AxisBindingSet, axis: Axes, overlap := BindingAxisOverlap.TakeNewer, masks: ..string) { AxisBindingSetAdd(set, Binding{Kind=.ControllerAxis, Axis=axis, Sign=-1}, Binding{Kind=.ControllerAxis, Axis=axis, Sign=1}, overlap, ..masks[:]) }
AxisBindingSetValue :: proc(set: ^AxisBindingSet, input: ^Input, device: int) -> f32 {
	value: f32 = 0
	for e in set.Entries { n := BindingGetState(e.Negative, input, device); p := BindingGetState(e.Positive, input, device); v := BindingAxisOverlapResolve(e.Overlap, n, p); if math.abs(v) > math.abs(value) { value = v } }
	return value
}
AxisBindingSetPressedSign :: proc(set: ^AxisBindingSet, input: ^Input, device: int) -> int { return int(math.sign(AxisBindingSetValue(set, input, device))) }
AxisBindingSetClear :: proc(set: ^AxisBindingSet) { clear(&set.Entries) }
AxisBindingSet_AxisEntry :: AxisEntry


// ===== merged from Input/Sets/StickBindingSet.odin =====


StickEntry :: struct { Left, Right, Up, Down: Binding, CircularDeadzone: f32, Overlap: BindingAxisOverlap, Masks: [dynamic]string }
StickBindingSet :: struct { Entries: [dynamic]StickEntry }
StickBindingSetAdd :: proc(set: ^StickBindingSet, left, right, up, down: Binding, deadzone := f32(0), overlap := BindingAxisOverlap.TakeNewer, masks: ..string) {
	e := StickEntry{Left=left, Right=right, Up=up, Down=down, CircularDeadzone=deadzone, Overlap=overlap}; for m in masks { append(&e.Masks, m) }; append(&set.Entries, e)
}
StickBindingSetAddKeys :: proc(set: ^StickBindingSet, left, right, up, down: Keys, overlap := BindingAxisOverlap.TakeNewer, masks: ..string) { StickBindingSetAdd(set, Binding{Kind=.KeyboardKey, Key=left}, Binding{Kind=.KeyboardKey, Key=right}, Binding{Kind=.KeyboardKey, Key=up}, Binding{Kind=.KeyboardKey, Key=down}, 0, overlap, ..masks[:]) }
StickBindingSetAddButtons :: proc(set: ^StickBindingSet, left, right, up, down: Buttons, overlap := BindingAxisOverlap.TakeNewer, masks: ..string) { StickBindingSetAdd(set, Binding{Kind=.ControllerButton, Button=left}, Binding{Kind=.ControllerButton, Button=right}, Binding{Kind=.ControllerButton, Button=up}, Binding{Kind=.ControllerButton, Button=down}, 0, overlap, ..masks[:]) }
StickBindingSetAddAxes :: proc(set: ^StickBindingSet, x, y: Axes, deadzone: f32, overlap := BindingAxisOverlap.TakeNewer, masks: ..string) { StickBindingSetAdd(set, Binding{Kind=.ControllerAxis, Axis=x, Sign=-1}, Binding{Kind=.ControllerAxis, Axis=x, Sign=1}, Binding{Kind=.ControllerAxis, Axis=y, Sign=-1}, Binding{Kind=.ControllerAxis, Axis=y, Sign=1}, deadzone, overlap, ..masks[:]) }
StickBindingSetValue :: proc(set: ^StickBindingSet, input: ^Input, device: int) -> [2]f32 {
	value: [2]f32 = {}
	for e in set.Entries { l := BindingGetState(e.Left,input,device); r := BindingGetState(e.Right,input,device); u := BindingGetState(e.Up,input,device); d := BindingGetState(e.Down,input,device); next := [2]f32{BindingAxisOverlapResolve(e.Overlap,l,r), BindingAxisOverlapResolve(e.Overlap,u,d)}; if e.CircularDeadzone > 0 && next[0]*next[0]+next[1]*next[1] < e.CircularDeadzone*e.CircularDeadzone { continue }; if next[0]*next[0]+next[1]*next[1] > value[0]*value[0]+value[1]*value[1] { value = next } }
	return value
}
StickBindingSetClear :: proc(set: ^StickBindingSet) { clear(&set.Entries) }
StickBindingSet_StickEntry :: StickEntry
