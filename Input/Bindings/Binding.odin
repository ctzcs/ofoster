package foster_input_bindings

import runtime "../.."
import enums "../Enums"

BindingKind :: enum { KeyboardKey, ControllerAxis, ControllerButton, MouseButton, MouseMotion }

// Binding is a compact tagged value.  Keeping the payload here makes bindings
// copyable and usable by the set types without requiring heap allocated
// interface values.
Binding :: struct {
	Kind: BindingKind,
	Key: enums.Keys,
	Axis: enums.Axes,
	Button: enums.Buttons,
	MouseButton: enums.MouseButtons,
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

binding_axis_value :: proc(binding: Binding, state: runtime.InputState, device: int) -> f32 {
	if device < 0 || device >= runtime.InputMaxControllers { return 0 }
	v := state.Controllers[device].axis[int(binding.Axis)] * f32(binding.Sign)
	return runtime.Clamp((v - binding.Deadzone) / (1 - binding.Deadzone), 0, 1)
}

BindingGetState :: proc(binding: Binding, input: ^runtime.Input, device: int) -> BindingState {
	result := BindingState{}
	switch binding.Kind {
	case .KeyboardKey:
		k := &input.State.Keyboard
		result = BindingState{Pressed=runtime.Pressed(k, binding.Key), Released=runtime.Released(k, binding.Key), Down=runtime.Down(k, binding.Key), Value=0, Timestamp=runtime.Timestamp(k, binding.Key)}
		if result.Down { result.Value = 1 }
	case .ControllerButton:
		if device < 0 || device >= runtime.InputMaxControllers { return result }
		c := &input.State.Controllers[device]
		result = BindingState{Pressed=runtime.ControllerPressed(c, binding.Button), Released=runtime.ControllerReleased(c, binding.Button), Down=runtime.ControllerDown(c, binding.Button), Value=0, Timestamp=runtime.ControllerTimestamp(c, binding.Button)}
		if result.Down { result.Value = 1 }
	case .ControllerAxis:
		if device < 0 || device >= runtime.InputMaxControllers { return result }
		c := &input.State.Controllers[device]
		v := binding_axis_value(binding, input.State, device)
		prev := binding_axis_value(binding, input.LastState, device)
		result.Value = v
		result.Down = v > 0
		result.Pressed = v > 0 && prev <= 0
		result.Released = v <= 0 && prev > 0
		result.Timestamp = runtime.ControllerAxisTimestamp(c, binding.Axis)
	case .MouseButton:
		m := &input.State.Mouse
		result = BindingState{Pressed=runtime.MousePressed(m, binding.MouseButton), Released=runtime.MouseReleased(m, binding.MouseButton), Down=runtime.MouseDown(m, binding.MouseButton), Value=0, Timestamp=runtime.PressedTimestamp(m, binding.MouseButton)}
		if result.Down { result.Value = 1 }
	case .MouseMotion:
		m := &input.State.Mouse
		v := m.Delta.X*binding.MotionAxis[0] + m.Delta.Y*binding.MotionAxis[1]
		v *= f32(binding.Sign)
		if binding.Max > binding.Min { v = runtime.Clamp(v, binding.Min, binding.Max) }
		result.Value = runtime.Clamp(v, f32(0), f32(1))
		result.Down = result.Value > 0
		result.Pressed = result.Down
		result.Timestamp = runtime.MotionTimestamp(m)
	}
	return result
}
