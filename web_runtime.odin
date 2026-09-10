#+build js wasm32, js wasm64p32

package foster_framework

// Web (js_wasm32) 后端桥接层 —— M0: 生命周期 / 窗口尺寸 / 清屏 / 事件队列骨架。
// 桥接模式沿用 vehicles/web-spike 已验证方案:
//   - foreign import "foster_web" + contextless 声明, 参数只用原始类型
//   - JS 侧手动实例化 wasm 并持有 memory(见 Internal/Web/foster.js)
//   - 帧循环由 JS requestAnimationFrame 驱动导出的 foster_step
// 桌面平台不编译本文件; framework_runtime.odin 里的 `when ODIN_OS == .JS`
// 分支引用此处符号, 分支外代码永不触碰 SDL 调用(未调用的 SDL proc 不进 wasm 导入表)。

import "core:fmt"
import coretime "core:time"

foreign import foster_web_lib "foster_web"

@(default_calling_convention="contextless")
foreign foster_web_lib {
	fw_init              :: proc(title_ptr: rawptr, title_len: i32) -> bool ---
	fw_canvas_size       :: proc(w: ^i32, h: ^i32) ---
	fw_canvas_pixel_size :: proc(w: ^i32, h: ^i32) ---
	fw_set_title         :: proc(title_ptr: rawptr, title_len: i32) ---
	fw_clear             :: proc(r, g, b, a: f32) ---
	fw_present           :: proc() ---
	fw_poll_event        :: proc(ev: ^WebEvent) -> bool ---
	fw_log               :: proc(msg_ptr: rawptr, msg_len: i32) ---
}

// ---- M1: WebGL2 图形桥 -----------------------------------------------------
// GL 对象在 foster.js 的句柄表里, 句柄 = 表索引(1 起, 0 = 空)。
// Odin 侧把句柄存进 SDL 的 ^GPUXxx 指针字段(u32 值转指针)。

@(default_calling_convention="contextless")
foreign foster_web_lib {
	fw_gl_create_shader    :: proc(stage: u32, code_ptr: rawptr, code_len: i32) -> u32 ---
	fw_gl_release_shader   :: proc(handle: u32) ---
	fw_gl_create_pipeline  :: proc(vs, fs: u32, blend_enable: u32, color_src, color_dst, color_op: u32, alpha_src, alpha_dst, alpha_op: u32, color_mask: u32, cull_mode: u32, fill_mode: u32) -> u32 ---
	fw_gl_release_pipeline :: proc(handle: u32) ---
	fw_gl_create_buffer    :: proc(buffer_type: u32, byte_size: i32) -> u32 ---
	fw_gl_upload_buffer    :: proc(handle: u32, data: rawptr, size: i32, offset: i32) ---
	fw_gl_release_buffer   :: proc(handle: u32) ---
	fw_gl_create_texture   :: proc(width, height: i32) -> u32 ---
	fw_gl_upload_texture   :: proc(handle: u32, width, height: i32, data: rawptr, size: i32) ---
	fw_gl_release_texture  :: proc(handle: u32) ---
	fw_gl_create_sampler   :: proc(filter: u32, wrap_x: u32, wrap_y: u32) -> u32 ---
	fw_gl_release_sampler  :: proc(handle: u32) ---

	fw_begin_pass        :: proc(fbo_texture: u32, clear_r, clear_g, clear_b, clear_a: f32, do_clear: u32) ---
	fw_end_pass          :: proc() ---
	fw_bind_pipeline     :: proc(handle: u32) ---
	fw_set_matrix4       :: proc(stage: u32, slot: u32, data: rawptr) ---
	fw_set_float         :: proc(stage: u32, slot: u32, value: f32) ---
	fw_bind_texture      :: proc(unit: u32, texture: u32, sampler: u32) ---
	fw_bind_vertex_buffer :: proc(slot: u32, buffer: u32, stride: i32) ---
	fw_vertex_attribute  :: proc(location: u32, slot: u32, type_ordinal: u32, normalized: u32, stride: i32, offset: i32) ---
	fw_bind_index_buffer :: proc(buffer: u32) ---
	fw_draw_elements     :: proc(count: i32, index_type: u32, byte_offset: i32, instances: i32) ---
	fw_draw_arrays       :: proc(count: i32, offset: i32, instances: i32) ---
	fw_set_viewport      :: proc(x, y, w, h: i32, fb_height: i32) ---
	fw_set_scissor       :: proc(x, y, w, h: i32, fb_height: i32) ---

	// ---- M3: 输入 ----
	fw_set_mouse_relative :: proc(enabled: u32) ---

	// ---- 窗口(全屏) ----
	fw_set_fullscreen :: proc(enabled: u32) ---
	fw_is_fullscreen :: proc() -> u32 ---

	// ---- M4: 虚拟文件系统(localStorage) ----
	fw_fs_exists :: proc(path_ptr: rawptr, path_len: i32) -> u32 ---
	fw_fs_size   :: proc(path_ptr: rawptr, path_len: i32) -> i32 ---
	fw_fs_read   :: proc(path_ptr: rawptr, path_len: i32, buf: rawptr, buf_len: i32) -> i32 ---
	fw_fs_write  :: proc(path_ptr: rawptr, path_len: i32, data_ptr: rawptr, data_len: i32) -> u32 ---
	fw_fs_remove :: proc(path_ptr: rawptr, path_len: i32) -> u32 ---
}

// 内建 GLSL 着色器源码(与 spv/dxil/msl 同语义, spirv-cross 反编译校对)
batcher_vertex_glsl    :: #load("assets/shaders/Batcher.vertex.glsl")
batcher_fragment_glsl  :: #load("assets/shaders/Batcher.fragment.glsl")
textured_vertex_glsl   :: #load("assets/shaders/Textured.vertex.glsl")
textured_fragment_glsl :: #load("assets/shaders/Textured.fragment.glsl")
msdf_vertex_glsl       :: #load("assets/shaders/Msdf.vertex.glsl")
msdf_fragment_glsl     :: #load("assets/shaders/Msdf.fragment.glsl")

// 句柄转换: u32 <-> SDL 指针字段
web_handle_ptr :: proc(h: u32) -> rawptr {
	if h == 0 {
		return nil
	}
	return rawptr(uintptr(h))
}

web_handle_u32 :: proc(p: rawptr) -> u32 {
	if p == nil {
		return 0
	}
	return u32(uintptr(p))
}

// CommandBuffer / RenderPass 的非 nil 占位(现有 nil 守卫依赖)
web_cmd_placeholder: u64
web_renderpass_placeholder: u64

// 枚举 → 序号(JS 侧按序号映射 GL 常量)。序号与各 enum 声明顺序一致。
web_blend_factor :: proc(f: BlendFactor) -> u32 { return u32(f) }
web_blend_op :: proc(op: BlendOp) -> u32 { return u32(op) }
web_cull_mode :: proc(m: CullMode) -> u32 { return u32(m) }
web_fill_mode :: proc(m: FillMode) -> u32 { return u32(m) }
web_texture_filter :: proc(f: TextureFilter) -> u32 { return u32(f) }
web_texture_wrap :: proc(w: TextureWrap) -> u32 { return u32(w) }
web_shader_stage :: proc(s: ShaderStage) -> u32 { return u32(s) }

web_index_type :: proc(f: IndexFormat) -> u32 {
	// 0 = UNSIGNED_SHORT, 1 = UNSIGNED_INT
	switch f {
	case .Sixteen: return 0
	case .ThirtyTwo: return 1
	}
	return 1
}

web_index_type_size :: proc(f: IndexFormat) -> i32 {
	switch f {
	case .Sixteen: return 2
	case .ThirtyTwo: return 4
	}
	return 4
}

web_vertex_type :: proc(t: VertexType) -> u32 {
	// 与 VertexType 枚举序号一致; JS 侧映射为 (size, gl_type)
	return u32(t)
}

// Foster 内部 Web 事件。不假扮 SDL.Event 结构; 窗口事件在 poll_events 的
// .JS 分支里映射为 SDL.EventType 枚举值复用现有 window_on_event, 输入事件
// 直接派发到 input_key/input_mouse_* 等现有入口。
// 结构布局被 foster.js 按小端写入(24 字节), 改字段必须两侧同步。
WebEventKind :: enum u32 {
	Quit,               // 浏览器侧请求退出(pagehide)
	WindowResized,      // A = CSS 宽, B = CSS 高
	WindowFocusGained,
	WindowFocusLost,
	KeyDown,            // A = scancode(Keys 值同 SDL), B = repeat
	KeyUp,              // A = scancode
	MouseMove,          // F = x 像素, G = y 像素
	MouseButtonDown,    // A = 按钮(1左/2中/3右), F/G = x/y
	MouseButtonUp,      // A = 按钮, F/G = x/y
	MouseWheel,         // F = dx, G = dy(向上为正)
}

WebEvent :: struct {
	Kind: WebEventKind,
	A:    i32,
	B:    i32,
	C:    i32,
	F:    f32,
	G:    f32,
}

// 字符串传参辅助(rawptr + 长度)
web_string_bytes :: proc(s: string) -> (ptr: rawptr, length: i32) {
	if len(s) == 0 {
		return nil, 0
	}
	bytes := transmute([]byte)s
	return &bytes[0], i32(len(bytes))
}

web_app: ^App

web_frame_delta: coretime.Duration

// Device 句柄的非 nil 占位: 让 GraphicsDevice 现有的 nil 守卫照常成立,
// 但该指针永远不会被传给任何 SDL 调用(JS 分支不触碰 SDL)。
web_device_placeholder: u64

web_relocate_app :: proc(app: ^App) -> ^App {
	// main() 在 .JS 下于 Run 返回后立即返回, 其栈帧(含调用方声明的 App 结构)会被
	// 后续调用复用。在 run() 入口把 App 拷贝到堆上并修正内部回指针, 之后的一切
	// (含 StartupProc 里初始化的 Batcher 等)都指向堆副本。
	// 注意: 经 AppSetUserData 传入的状态仍应是全局变量或堆分配(见文档 §0)。
	heap_app := new(App)
	heap_app^ = app^

	heap_app.Window.App = heap_app
	heap_app.Window.GraphicsDevice = &heap_app.GraphicsDevice
	heap_app.Input.App = heap_app
	heap_app.FileSystem.App = heap_app

	device := &heap_app.GraphicsDevice
	if device.HasWindowRenderTarget {
		device.WindowRenderTarget.GraphicsDevice = device
		for i in 0..<len(device.WindowRenderTarget.Attachments) {
			device.WindowRenderTarget.Attachments[i].GraphicsDevice = device
		}
	}
	if device.HasBackbufferTarget {
		device.BackbufferTarget.GraphicsDevice = device
		for i in 0..<len(device.BackbufferTarget.Attachments) {
			device.BackbufferTarget.Attachments[i].GraphicsDevice = device
		}
	}

	return heap_app
}

web_enter_run_loop :: proc(app: ^App) {
	web_app = app
}

web_take_frame_delta :: proc() -> coretime.Duration {
	delta := web_frame_delta
	web_frame_delta = 0
	return delta
}

web_log :: proc(message: string) {
	if len(message) > 0 {
		bytes := transmute([]byte)message
		fw_log(&bytes[0], i32(len(bytes)))
	}
}

// M0: 仅返回虚拟前缀; M4 接 localStorage/IndexedDB 虚拟文件系统时替换。
web_user_path :: proc(name: string) -> string {
	return fmt.aprintf("/foster/%s/", name)
}

web_window_size :: proc() -> Point2 {
	// M1: 与像素尺寸一致(矩阵/视口/帧缓冲统一用绘制缓冲像素, DPR>1 也正确);
	// M3 接输入时再区分 CSS 逻辑坐标与像素坐标
	return web_window_size_in_pixels()
}

web_window_size_in_pixels :: proc() -> Point2 {
	w, h: i32
	fw_canvas_pixel_size(&w, &h)
	return Point2{int(w), int(h)}
}

// run() 在 .JS 下返回后, 每帧由 foster.js 的 requestAnimationFrame 调用。
@(export)
foster_step :: proc(dt: f64) -> (keep_going: bool) {
	app := web_app
	if app == nil || !app.Running {
		web_log("foster_step: stop (no app / not running)")
		return false
	}
	clamped := dt
	if clamped > 0.25 {
		clamped = 0.25 // 页面隐藏后恢复时钳制首帧步长
	}
	web_frame_delta = coretime.Duration(clamped * 1e9)

	tick_app(app)

	if app.Exiting {
		web_log("foster_step: exiting -> run_finish")
		run_finish(app)
		return false
	}
	return true
}
