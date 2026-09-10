package foster_framework

import coretime "core:time"
import SDL "vendor:sdl3"
import "core:c"

// ===== merged from Input/InputProvider.odin =====


InputProvider :: struct { Input: ^Input }
InputProviderMake :: proc() -> InputProvider { p:=InputProvider{}; p.Input=new(Input); InputInit(p.Input,nil); return p }
InputProviderUpdate :: proc(p:^InputProvider,t:Time){if p.Input!=nil{InputStep(p.Input,t)}}
InputProviderText :: proc(p:^InputProvider,text:string){if p.Input!=nil {p.Input.State.Keyboard.Text=text}}
InputProviderKey :: proc(p:^InputProvider,key:Keys,pressed:bool,stamp:coretime.Duration){if p.Input!=nil{InputKey(p.Input,key,pressed,stamp)}}
InputProviderMouseButton :: proc(p:^InputProvider,button:MouseButtons,pressed:bool,stamp:coretime.Duration){if p.Input!=nil{InputMouseButton(p.Input,button,pressed,stamp)}}
InputProviderMouseMove :: proc(p:^InputProvider,position,delta:Vec2f,stamp:coretime.Duration){if p.Input!=nil{InputMouseMove(p.Input,position,delta,stamp)}}
InputProviderMouseWheel :: proc(p:^InputProvider,wheel:Vec2f){if p.Input!=nil{InputMouseWheel(p.Input,wheel)}}
InputProviderControllerButton :: proc(p:^InputProvider,id:ControllerID,button:int,pressed:bool,stamp:coretime.Duration){if p.Input!=nil{InputControllerButton(p.Input,id,button,pressed,stamp)}}
InputProviderControllerAxis :: proc(p:^InputProvider,id:ControllerID,axis:int,value:f32,stamp:coretime.Duration){if p.Input!=nil{InputControllerAxis(p.Input,id,axis,value,stamp)}}

// ===== merged from Input/Cursor.odin =====


CursorSystemType :: enum { Default, Text, Wait, Crosshair, Progress, ResizeNWSE, ResizeNESW, ResizeHorizontal, ResizeVertical, Move, NotAllowed, Pointer, ResizeNW, ResizeN, ResizeNE, ResizeE, ResizeSE, ResizeS, ResizeSW, ResizeW }
Cursor :: struct { FocusPoint: Point2, Size: Point2, SystemType: CursorSystemType, Image: ^Image, Handle: ^SDL.Cursor, Disposed: bool }
cursor_sdl_system :: proc(kind: CursorSystemType) -> SDL.SystemCursor {
	return SDL.SystemCursor(kind)
}
CursorMakeSystem :: proc(kind: CursorSystemType)->Cursor{return Cursor{SystemType=kind, Handle=SDL.CreateSystemCursor(cursor_sdl_system(kind))}}
CursorMakeImage :: proc(image:^Image,focus:Point2)->Cursor {
	result := Cursor{FocusPoint=focus}
	if image == nil || image.Width <= 0 || image.Height <= 0 || len(image.Pixels) == 0 { return result }
	result.Size = Point2{image.Width, image.Height}
	result.Image = image
	surface := SDL.CreateSurfaceFrom(c.int(image.Width), c.int(image.Height), SDL.PixelFormat.RGBA8888, raw_data(image.Pixels), c.int(image.Width * 4))
	if surface == nil { return result }
	result.Handle = SDL.CreateColorCursor(surface, c.int(focus.X), c.int(focus.Y))
	SDL.DestroySurface(surface)
	return result
}
CursorSet :: proc(c:^Cursor) -> bool { if c == nil || c.Disposed || c.Handle == nil do return false; return SDL.SetCursor(c.Handle) }
CursorDispose :: proc(c:^Cursor){if c == nil || c.Disposed do return;if c.Handle != nil{SDL.DestroyCursor(c.Handle);c.Handle=nil};c.Disposed=true;c.Image=nil}
