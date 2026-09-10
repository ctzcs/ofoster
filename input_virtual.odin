package foster_framework

import "core:time"

// ===== merged from Input/Virtual/VirtualInput.odin =====


VirtualInput :: struct {
	Input: ^Input,
	Name: string,
	ControllerIndex: int,
	Active: bool,
	IsDisposed: bool,
}

VirtualInputMake :: proc(input: ^Input, name: string, controller_index := 0) -> VirtualInput {
	return VirtualInput{Input=input, Name=name, ControllerIndex=controller_index, Active=true}
}
VirtualInputDispose :: proc(v: ^VirtualInput) { v.IsDisposed = true }
VirtualInputSetControllerIndex :: proc(v: ^VirtualInput, index: int) { if index >= 0 { v.ControllerIndex = index } }
VirtualInputSetActive :: proc(v: ^VirtualInput, active: bool) { if v != nil { v.Active = active } }
VirtualInputIsActive :: proc(v: ^VirtualInput) -> bool { return v != nil && v.Active && !v.IsDisposed }

// ===== merged from Input/Virtual/VirtualDevice.odin =====


VirtualDeviceIndexMode :: enum { Manual, AutomaticLatest }
VirtualDevice :: struct {
	Base: VirtualInput,
	IndexMode: VirtualDeviceIndexMode,
	Inputs: [dynamic]^VirtualInput,
	actions: [dynamic]^VirtualAction,
	axes: [dynamic]^VirtualAxis,
	sticks: [dynamic]^VirtualStick,
}
VirtualDeviceMake :: proc(input: ^Input, name: string, controller_index := 0) -> VirtualDevice { return VirtualDevice{Base=VirtualInputMake(input,name,controller_index),IndexMode=.Manual} }
VirtualDeviceSetControllerIndex :: proc(v: ^VirtualDevice, index: int) { if v.IndexMode == .Manual { v.Base.ControllerIndex=index; for p in v.Inputs { p.ControllerIndex=index } } }
VirtualDeviceAddAction :: proc(v: ^VirtualDevice, name: string, set := ActionBindingSet{}, buffer := f32(0)) -> ^VirtualAction { a := new(VirtualAction); a^=VirtualActionMake(v.Base.Input,name,set,v.Base.ControllerIndex,buffer); append(&v.actions,a); append(&v.Inputs,&a.Base); return a }
VirtualDeviceAddAxis :: proc(v: ^VirtualDevice, name: string, set := AxisBindingSet{}) -> ^VirtualAxis { a := new(VirtualAxis); a^=VirtualAxisMake(v.Base.Input,name,set,v.Base.ControllerIndex); append(&v.axes,a); append(&v.Inputs,&a.Base); return a }
VirtualDeviceAddStick :: proc(v: ^VirtualDevice, name: string, set := StickBindingSet{}) -> ^VirtualStick { s := new(VirtualStick); s^=VirtualStickMake(v.Base.Input,name,set,v.Base.ControllerIndex); append(&v.sticks,s); append(&v.Inputs,&s.Base); return s }
VirtualDeviceUpdate :: proc(v: ^VirtualDevice, t: Time) {
	if v.IndexMode == .AutomaticLatest && v.Base.Input != nil { latest:=0; for i in 1..<InputMaxControllers { if v.Base.Input.State.Controllers[i].IsGamepad && v.Base.Input.State.Controllers[i].InputTimestamp > v.Base.Input.State.Controllers[latest].InputTimestamp { latest=i } }; v.Base.ControllerIndex=latest; for p in v.Inputs { p.ControllerIndex=latest } }
	for a in v.actions { VirtualActionUpdate(a,t) }; for a in v.axes { VirtualAxisUpdate(a,t) }; for s in v.sticks { VirtualStickUpdate(s,t) }
}
VirtualDeviceDispose :: proc(v: ^VirtualDevice) { if v.Base.IsDisposed { return }; for p in v.Inputs { VirtualInputDispose(p) }; clear(&v.Inputs); clear(&v.actions); clear(&v.axes); clear(&v.sticks); v.Base.IsDisposed=true }
VirtualDeviceIsGamepadLatest :: proc(v: ^VirtualDevice) -> bool { if v.Base.Input == nil || v.Base.ControllerIndex < 0 || v.Base.ControllerIndex >= InputMaxControllers { return false }; c:=&v.Base.Input.State.Controllers[v.Base.ControllerIndex]; return c.IsGamepad && c.InputTimestamp > v.Base.Input.State.Keyboard.InputTimestamp }

// ===== merged from Input/Virtual/VirtualAction.odin =====


VirtualAction :: struct {
	Base: VirtualInput,
	Set: ActionBindingSet,
	RepeatDelay: f32,
	RepeatInterval: f32,
	Buffer: f32,
	Pressed, PressConsumed, Down, Released, Repeated: bool,
	Value, ValueNoDeadzone: f32,
	Timestamp: time.Duration,
}

VirtualActionMake :: proc(input: ^Input, name: string, set := ActionBindingSet{}, controller_index := 0, buffer := f32(0)) -> VirtualAction {
	return VirtualAction{Base=VirtualInputMake(input,name,controller_index), Set=set, RepeatDelay=RepeatDelay, RepeatInterval=RepeatInterval, Buffer=buffer}
}
VirtualActionUpdate :: proc(v: ^VirtualAction, t: Time) {
	if v.Base.IsDisposed || !v.Base.Active || v.Base.Input == nil { return }
	s := ActionBindingSetGetState(&v.Set, v.Base.Input, v.Base.ControllerIndex)
	v.Pressed, v.Released, v.Down, v.Value = s.Pressed, s.Released, s.Down, s.Value
	v.ValueNoDeadzone = s.Value
	v.Repeated = false
	if v.Pressed { v.PressConsumed = false; v.Timestamp = t.Elapsed } else if !v.PressConsumed && v.Timestamp > 0 && time.duration_seconds(t.Elapsed-v.Timestamp) < f64(v.Buffer) { v.Pressed = true }
	if v.Down && time.duration_seconds(t.Elapsed-v.Timestamp) > f64(v.RepeatDelay) && v.RepeatInterval > 0 {
		elapsed := time.duration_seconds(t.Elapsed-v.Timestamp) - f64(v.RepeatDelay)
		previous := elapsed - f64(t.Delta)
		v.Repeated = int(previous/f64(v.RepeatInterval)) < int(elapsed/f64(v.RepeatInterval))
	}
}
VirtualActionManualUpdate :: proc(v: ^VirtualAction, t: Time) { VirtualActionUpdate(v, t) }
VirtualActionConsumePress :: proc(v: ^VirtualAction) -> bool { if v.Pressed { v.Pressed=false; v.PressConsumed=true; return true }; return false }
VirtualActionClear :: proc(v: ^VirtualAction) { v.Pressed=false; v.Released=false; v.PressConsumed=true; v.Down=false; v.Repeated=false; v.Value=0; v.ValueNoDeadzone=0 }
VirtualActionSetControllerIndex :: proc(v: ^VirtualAction, index: int) { VirtualInputSetControllerIndex(&v.Base,index) }

// ===== merged from Input/Virtual/VirtualAxis.odin =====


VirtualAxis :: struct { Base: VirtualInput, Set: AxisBindingSet, Value: f32, IntValue: int, PressedSign: int }
VirtualAxisMake :: proc(input: ^Input, name: string, set := AxisBindingSet{}, controller_index := 0) -> VirtualAxis { return VirtualAxis{Base=VirtualInputMake(input,name,controller_index),Set=set} }
VirtualAxisUpdate :: proc(v: ^VirtualAxis, t: Time) { _ = t; if v.Base.IsDisposed || !v.Base.Active || v.Base.Input == nil { return }; v.Value=AxisBindingSetValue(&v.Set,v.Base.Input,v.Base.ControllerIndex); if v.Value > 0 { v.IntValue=1 } else if v.Value < 0 { v.IntValue=-1 } else { v.IntValue=0 }; v.PressedSign=AxisBindingSetPressedSign(&v.Set,v.Base.Input,v.Base.ControllerIndex) }
VirtualAxisManualUpdate :: proc(v: ^VirtualAxis, t: Time) { VirtualAxisUpdate(v, t) }
VirtualAxisPressed :: proc(v: ^VirtualAxis) -> bool { return v.PressedSign != 0 }
VirtualAxisPressedNegative :: proc(v: ^VirtualAxis) -> bool { return v.PressedSign < 0 }
VirtualAxisPressedPositive :: proc(v: ^VirtualAxis) -> bool { return v.PressedSign > 0 }
VirtualAxisClear :: proc(v: ^VirtualAxis) { v.Value=0; v.IntValue=0; v.PressedSign=0 }
VirtualAxisSetControllerIndex :: proc(v: ^VirtualAxis,index:int) { VirtualInputSetControllerIndex(&v.Base,index) }

// ===== merged from Input/Virtual/VirtualStick.odin =====


VirtualStick :: struct { Base: VirtualInput, Set: StickBindingSet, Value: [2]f32, IntValue: Point2, PressedLeft, PressedRight, PressedUp, PressedDown: bool }
VirtualStickMake :: proc(input: ^Input, name: string, set := StickBindingSet{}, controller_index := 0) -> VirtualStick { return VirtualStick{Base=VirtualInputMake(input,name,controller_index),Set=set} }
VirtualStickUpdate :: proc(v: ^VirtualStick, t: Time) { _ = t; if v.Base.IsDisposed || !v.Base.Active || v.Base.Input == nil { return }; v.Value=StickBindingSetValue(&v.Set,v.Base.Input,v.Base.ControllerIndex); v.IntValue=Point2{}; if v.Value[0] < 0 { v.IntValue.X=-1 }; if v.Value[0] > 0 { v.IntValue.X=1 }; if v.Value[1] < 0 { v.IntValue.Y=-1 }; if v.Value[1] > 0 { v.IntValue.Y=1 }; v.PressedLeft=false; v.PressedRight=false; v.PressedUp=false; v.PressedDown=false; for e in v.Set.Entries { l:=BindingGetState(e.Left,v.Base.Input,v.Base.ControllerIndex); r:=BindingGetState(e.Right,v.Base.Input,v.Base.ControllerIndex); u:=BindingGetState(e.Up,v.Base.Input,v.Base.ControllerIndex); d:=BindingGetState(e.Down,v.Base.Input,v.Base.ControllerIndex); v.PressedLeft |= l.Pressed; v.PressedRight |= r.Pressed; v.PressedUp |= u.Pressed; v.PressedDown |= d.Pressed } }
VirtualStickManualUpdate :: proc(v: ^VirtualStick, t: Time) { VirtualStickUpdate(v, t) }
VirtualStickClear :: proc(v: ^VirtualStick) { v.Value={}; v.IntValue={}; v.PressedLeft=false; v.PressedRight=false; v.PressedUp=false; v.PressedDown=false }
VirtualStickSetControllerIndex :: proc(v: ^VirtualStick,index:int) { VirtualInputSetControllerIndex(&v.Base,index) }
