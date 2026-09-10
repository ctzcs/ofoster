"use strict";

// OFoster Web 桥 —— Odin 侧 foreign import "foster_web" 的 JS 实现(web_runtime.odin)。
// 用法(与 odin.js 同目录加载):
//   <script>window.FOSTER_WASM = "game.wasm";</script>
//   <script src="odin.js"></script>
//   <script src="foster.js"></script>
// 可选: window.FOSTER_CANVAS_ID (默认 "foster"), window.FOSTER_LOG_ID (默认 "foster-log")。
//
// 手动实例化 wasm(不用 odin.runWasm): 需要持有 memory 以便 rawptr 传参,
// 以及直接驱动导出的 foster_step。模式与 vehicles/web-spike 一致。
//
// M1: WebGL2 即时式状态机 —— 句柄表(shader/pipeline/buffer/texture/sampler)、
// 渲染通道、管线状态(blend/cull/fill)、逐 draw uniform、VAO 顶点装配、索引绘制。

(function () {
	const WASM_URL = window.FOSTER_WASM || "game.wasm";
	const canvas = document.getElementById(window.FOSTER_CANVAS_ID || "foster");
	const logEl = document.getElementById(window.FOSTER_LOG_ID || "foster-log");
	// 诊断日志默认隐藏: URL 加 ?debug=1 常显; 出现 ERROR 行时自动弹出
	const debugVisible = new URLSearchParams(location.search).has("debug");
	const showLog = () => { if (logEl) logEl.style.display = "block"; };
	if (debugVisible) showLog();
	const log = (msg) => {
		if (logEl) {
			logEl.textContent += msg + "\n";
			if (!debugVisible && /\bERROR\b/.test(msg)) showLog();
		}
		console.log(msg);
	};

	if (!canvas) { log("[foster.js] missing <canvas id=foster>"); return; }
	const gl = canvas.getContext("webgl2", { antialias: true, alpha: false, preserveDrawingBuffer: true });
	if (!gl) { log("[foster.js] WebGL2 not available"); return; }

	// --- 常量 ---
	const GL = {
		FLOAT: 0x1406, UNSIGNED_BYTE: 0x1401, SHORT: 0x1402, UNSIGNED_SHORT: 0x1403, UNSIGNED_INT: 0x1405,
		NEAREST: 0x2600, LINEAR: 0x2601,
		REPEAT: 0x2901, MIRRORED_REPEAT: 0x8370, CLAMP_TO_EDGE: 0x812F,
		FUNC_ADD: 0x8006, FUNC_SUBTRACT: 0x800A, FUNC_REVERSE_SUBTRACT: 0x800B, MIN: 0x8007, MAX: 0x8008,
		ZERO: 0, ONE: 1,
		SRC_COLOR: 0x0300, ONE_MINUS_SRC_COLOR: 0x0301, DST_COLOR: 0x0306, ONE_MINUS_DST_COLOR: 0x0307,
		SRC_ALPHA: 0x0302, ONE_MINUS_SRC_ALPHA: 0x0303, DST_ALPHA: 0x0304, ONE_MINUS_DST_ALPHA: 0x0305,
		CONSTANT_COLOR: 0x8001, ONE_MINUS_CONSTANT_COLOR: 0x8002, SRC_ALPHA_SATURATE: 0x0308,
	};
	// 序号映射(与 Odin 侧 enum 声明顺序一致)
	const BLEND_FACTOR = [
		GL.ZERO, GL.ONE, GL.SRC_COLOR, GL.ONE_MINUS_SRC_COLOR, GL.DST_COLOR, GL.ONE_MINUS_DST_COLOR,
		GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.DST_ALPHA, GL.ONE_MINUS_DST_ALPHA,
		GL.CONSTANT_COLOR, GL.ONE_MINUS_CONSTANT_COLOR, GL.SRC_ALPHA_SATURATE,
	];
	const BLEND_OP = [GL.FUNC_ADD, GL.FUNC_SUBTRACT, GL.FUNC_REVERSE_SUBTRACT, GL.MIN, GL.MAX];
	const CULL = [0, gl.FRONT, gl.BACK]; // 0 = 禁用
	// FillMode.Line 需要 polygonMode, WebGL2 不支持 —— Web 后端恒按填充绘制(已知差异)。
	const VERTEX_TYPE = [ // VertexType 序号 → [size, glType]
		null,          // None
		[1, GL.FLOAT], // Float
		[2, GL.FLOAT], // Float2
		[3, GL.FLOAT], // Float3
		[4, GL.FLOAT], // Float4
		[4, gl.BYTE],        // Byte4
		[4, GL.UNSIGNED_BYTE], // UByte4
		[2, GL.SHORT],       // Short2
		[2, GL.UNSIGNED_SHORT], // UShort2
		[4, GL.SHORT],       // Short4
		[4, GL.UNSIGNED_SHORT], // UShort4
	];
	const FILTER = [GL.NEAREST, GL.LINEAR];
	const WRAP = [GL.REPEAT, GL.MIRRORED_REPEAT, GL.CLAMP_TO_EDGE];
	const INDEX_TYPE = [GL.UNSIGNED_SHORT, GL.UNSIGNED_INT];

	// --- 事件队列(Odin 侧 fw_poll_event 逐条取) ---
	// WebEvent 布局(web_runtime.odin): kind u32 @0, a i32 @4, b i32 @8, c i32 @12, f f32 @16, g f32 @20
	const EV = { Quit: 0, WindowResized: 1, WindowFocusGained: 2, WindowFocusLost: 3, KeyDown: 4, KeyUp: 5, MouseMove: 6, MouseButtonDown: 7, MouseButtonUp: 8, MouseWheel: 9 };
	const eventQueue = [];
	const push = (kind, a = 0, b = 0, c = 0, f = 0, g = 0) => eventQueue.push({ kind, a, b, c, f, g });

	// e.code → SDL scancode(Foster Keys 值与 SDL scancode 一致)
	const KEYCODE = (() => {
		const t = {};
		const add = (code, sc) => { t[code] = sc; };
		for (let i = 0; i < 26; i++) add("Key" + String.fromCharCode(65 + i), 4 + i);   // A=4..Z=29
		for (let i = 1; i <= 9; i++) add("Digit" + i, 29 + i);                            // 1=30..9=38
		add("Digit0", 39);
		add("Enter", 40); add("Escape", 41); add("Backspace", 42); add("Tab", 43); add("Space", 44);
		add("Minus", 45); add("Equal", 46); add("BracketLeft", 47); add("BracketRight", 48); add("Backslash", 49);
		add("Semicolon", 51); add("Quote", 52); add("Backquote", 53); add("Comma", 54); add("Period", 55); add("Slash", 56);
		add("CapsLock", 57);
		for (let i = 1; i <= 12; i++) add("F" + i, 57 + i);                                // F1=58..F12=69
		add("PrintScreen", 70); add("ScrollLock", 71); add("Pause", 72); add("Insert", 73);
		add("Home", 74); add("PageUp", 75); add("Delete", 76); add("End", 77); add("PageDown", 78);
		add("ArrowRight", 79); add("ArrowLeft", 80); add("ArrowDown", 81); add("ArrowUp", 82);
		add("NumLock", 83);
		add("NumpadDivide", 84); add("NumpadMultiply", 85); add("NumpadSubtract", 86); add("NumpadAdd", 87);
		add("NumpadEnter", 88);
		for (let i = 1; i <= 9; i++) add("Numpad" + i, 88 + i);                           // 89..97
		add("Numpad0", 98); add("NumpadDecimal", 99);
		add("ControlLeft", 224); add("ShiftLeft", 225); add("AltLeft", 226); add("MetaLeft", 227);
		add("ControlRight", 228); add("ShiftRight", 229); add("AltRight", 230); add("MetaRight", 231);
		return t;
	})();

	// 会截获的按键(防页面滚动等默认行为)
	const isGameKey = (code) => code in KEYCODE;

	// --- canvas 尺寸同步(CSS 尺寸 × DPR = 绘制缓冲尺寸) ---
	function syncCanvasSize() {
		const dpr = window.devicePixelRatio || 1;
		const w = Math.max(1, Math.floor(canvas.clientWidth * dpr));
		const h = Math.max(1, Math.floor(canvas.clientHeight * dpr));
		if (canvas.width !== w || canvas.height !== h) {
			canvas.width = w;
			canvas.height = h;
			push(EV.WindowResized, canvas.clientWidth | 0, canvas.clientHeight | 0);
		}
	}
	if (typeof ResizeObserver !== "undefined") new ResizeObserver(syncCanvasSize).observe(canvas);
	window.addEventListener("resize", syncCanvasSize);
	window.addEventListener("focus", () => push(EV.WindowFocusGained));
	window.addEventListener("blur", () => push(EV.WindowFocusLost));
	window.addEventListener("pagehide", () => push(EV.Quit));

	// --- M3: 键盘 / 鼠标 / 滚轮 / Pointer Lock ---
	const mouseButtonSDL = (b) => b === 0 ? 1 : b === 1 ? 2 : b === 2 ? 3 : 0; // DOM → SDL(左1中2右3)

	function pixelPos(e) {
		// clientX/Y 相对 canvas 归一: getBoundingClientRect 受页面 zoom/transform 影响,
		// 按 rect 与 clientWidth 比例换算回 CSS 尺寸, 再乘 DPR 得绘制缓冲像素
		const dpr = window.devicePixelRatio || 1;
		const rect = canvas.getBoundingClientRect();
		const sx = rect.width > 0 ? canvas.clientWidth / rect.width : 1;
		const sy = rect.height > 0 ? canvas.clientHeight / rect.height : 1;
		return [(e.clientX - rect.left) * sx * dpr, (e.clientY - rect.top) * sy * dpr];
	}

	// Pointer Lock 虚拟坐标(锁定后 movementX/Y 累积)
	let pointerLocked = false;
	let virtualX = 0, virtualY = 0;

	window.addEventListener("keydown", (e) => {
		const sc = KEYCODE[e.code];
		if (sc === undefined) return;
		if (isGameKey(e.code)) e.preventDefault();
		push(EV.KeyDown, sc, e.repeat ? 1 : 0);
	});
	window.addEventListener("keyup", (e) => {
		const sc = KEYCODE[e.code];
		if (sc === undefined) return;
		push(EV.KeyUp, sc, 0);
	});
	canvas.addEventListener("pointerdown", (e) => {
		const [x, y] = pixelPos(e);
		push(EV.MouseButtonDown, mouseButtonSDL(e.button), 0, 0, x, y);
		canvas.setPointerCapture(e.pointerId);
	});
	canvas.addEventListener("pointerup", (e) => {
		const [x, y] = pixelPos(e);
		push(EV.MouseButtonUp, mouseButtonSDL(e.button), 0, 0, x, y);
	});
	canvas.addEventListener("pointermove", (e) => {
		if (pointerLocked) {
			const dpr = window.devicePixelRatio || 1;
			virtualX += e.movementX * dpr;
			virtualY += e.movementY * dpr;
			push(EV.MouseMove, 0, 0, 0, virtualX, virtualY);
		} else {
			const [x, y] = pixelPos(e);
			push(EV.MouseMove, 0, 0, 0, x, y);
		}
	});
	canvas.addEventListener("wheel", (e) => {
		e.preventDefault();
		// 归一化: ±100 像素 ≈ 1 个滚轮刻度, SDL 语义向上为正
		push(EV.MouseWheel, 0, 0, 0, e.deltaX / 100, -e.deltaY / 100);
	}, { passive: false });
	canvas.addEventListener("contextmenu", (e) => e.preventDefault());
	document.addEventListener("pointerlockchange", () => {
		pointerLocked = document.pointerLockElement === canvas;
		if (pointerLocked) {
			virtualX = canvas.width / 2;
			virtualY = canvas.height / 2;
		}
	});

	// 调试句柄(仅供开发排查; 游戏代码不要依赖)
	const callCounts = Object.create(null);
	const countedBridge = new Proxy({}, {
		get(_, prop) {
			if (prop in bridge) {
				return function (...args) {
					callCounts[prop] = (callCounts[prop] || 0) + 1;
					return bridge[prop].apply(this, args);
				};
			}
			return undefined;
		},
	});
	window.__fosterDebug = {
		push: push,
		queueDepth: () => eventQueue.length,
		drain: () => eventQueue.splice(0, eventQueue.length),
		calls: callCounts,
	};

	// --- GL 初始状态 ---
	gl.disable(gl.DEPTH_TEST);
	gl.disable(gl.STENCIL_TEST);
	gl.disable(gl.CULL_FACE);
	gl.disable(gl.SCISSOR_TEST);
	gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
	gl.enable(gl.BLEND); // 具体混合因子由管线状态设置

	// 默认 1x1 白纹理(无纹理批次的占位, 对应桌面的 DebugTexture)
	const whiteTex = gl.createTexture();
	gl.bindTexture(gl.TEXTURE_2D, whiteTex);
	gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, GL.UNSIGNED_BYTE, new Uint8Array([255, 255, 255, 255]));

	// --- 句柄表 ---
	const objects = new Map();
	let nextHandle = 1;
	function retain(kind, obj) {
		const h = nextHandle++;
		objects.set(h, { kind, obj });
		return h;
	}
	function release(h) {
		const e = objects.get(h);
		if (!e) return;
		switch (e.kind) {
			case "shader": gl.deleteShader(e.obj); break;
			case "pipeline":
				gl.deleteProgram(e.obj.program);
				gl.deleteVertexArray(e.obj.vao);
				break;
			case "buffer": gl.deleteBuffer(e.obj.gl); break;
			case "texture": gl.deleteTexture(e.obj); break;
			case "sampler": gl.deleteSampler(e.obj); break;
		}
		objects.delete(h);
	}
	const get = (h) => (objects.get(h) || {}).obj;

	// --- M4: localStorage 虚拟 FS 辅助 ---
	const FS_PREFIX = "fosterfs:";
	const fsKey = (path) => FS_PREFIX + path;
	const fsReadBytes = (path) => {
		const v = localStorage.getItem(fsKey(path));
		if (v === null) return null;
		return base64ToBytes(v);
	};
	function bytesToBase64(bytes) {
		let bin = "";
		const chunk = 0x8000;
		for (let i = 0; i < bytes.length; i += chunk) {
			bin += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
		}
		return btoa(bin);
	}
	function base64ToBytes(b64) {
		const bin = atob(b64);
		const out = new Uint8Array(bin.length);
		for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
		return out;
	}

	// --- 逐 draw uniform 暂存(管线绑定时清空, draw 时应用) ---
	let pendingMatrix = null;   // Float32Array(16) 或 null
	let pendingFragFloat = null;

	function compileShader(stage, code) {
		const type = stage === 0 ? gl.VERTEX_SHADER : gl.FRAGMENT_SHADER;
		const s = gl.createShader(type);
		gl.shaderSource(s, code);
		gl.compileShader(s);
		if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
			log("[foster.js] shader compile error:\n" + gl.getShaderInfoLog(s) + "\n--- source ---\n" + code);
			gl.deleteShader(s);
			return 0;
		}
		return retain("shader", s);
	}

	// --- 桥实现 ---
	const bridge = {
		memory: null,
		setMemory(m) { bridge.memory = m; },

		fw_init(titlePtr, titleLen) {
			syncCanvasSize();
			if (titleLen > 0) document.title = readString(titlePtr, titleLen);
			return true;
		},
		fw_canvas_size(wPtr, hPtr) {
			const dv = new DataView(bridge.memory.buffer);
			dv.setInt32(wPtr, canvas.clientWidth | 0, true);
			dv.setInt32(hPtr, canvas.clientHeight | 0, true);
		},
		fw_canvas_pixel_size(wPtr, hPtr) {
			const dv = new DataView(bridge.memory.buffer);
			dv.setInt32(wPtr, canvas.width, true);
			dv.setInt32(hPtr, canvas.height, true);
		},
		fw_set_title(ptr, len) { if (len > 0) document.title = readString(ptr, len); },
		fw_clear(r, g, b, a) {
			gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
			gl.clearColor(r, g, b, a);
			gl.clear(gl.COLOR_BUFFER_BIT);
		},
		fw_present() { /* WebGL2: rAF 合成即 present */ },
		fw_poll_event(evPtr) {
			if (eventQueue.length === 0) return false;
			const ev = eventQueue.shift();
			const dv = new DataView(bridge.memory.buffer, evPtr, 24);
			dv.setUint32(0, ev.kind, true);
			dv.setInt32(4, ev.a, true);
			dv.setInt32(8, ev.b, true);
			dv.setInt32(12, ev.c, true);
			dv.setFloat32(16, ev.f, true);
			dv.setFloat32(20, ev.g, true);
			return true;
		},
		fw_log(ptr, len) { if (len > 0) log(readString(ptr, len)); },

		// ---- GL 资源 ----
		fw_gl_create_shader(stage, codePtr, codeLen) {
			return compileShader(stage, readString(codePtr, codeLen));
		},
		fw_gl_release_shader(h) { release(h); },
		fw_gl_create_pipeline(vs, fs, blendEnable, cSrc, cDst, cOp, aSrc, aDst, aOp, colorMask, cull, fill) {
			const vsObj = get(vs), fsObj = get(fs);
			if (!vsObj || !fsObj) return 0;
			const p = gl.createProgram();
			gl.attachShader(p, vsObj);
			gl.attachShader(p, fsObj);
			gl.linkProgram(p);
			if (!gl.getProgramParameter(p, gl.LINK_STATUS)) {
				log("[foster.js] program link error: " + gl.getProgramInfoLog(p));
				gl.deleteProgram(p);
				return 0;
			}
			const prog = {
				program: p,
				vao: gl.createVertexArray(),
				// 状态(绑定时应用)
				blendEnable: blendEnable !== 0,
				cSrc: BLEND_FACTOR[cSrc], cDst: BLEND_FACTOR[cDst], cOp: BLEND_OP[cOp],
				aSrc: BLEND_FACTOR[aSrc], aDst: BLEND_FACTOR[aDst], aOp: BLEND_OP[aOp],
				colorMask: colorMask & 15, cull: CULL[cull] || 0,
				// uniform 位置(懒查询缓存)
				locs: {},
			};
			// sampler 统一 0 号单元
			gl.useProgram(p);
			const texLoc = gl.getUniformLocation(p, "u_tex");
			if (texLoc) gl.uniform1i(texLoc, 0);
			return retain("pipeline", prog);
		},
		fw_gl_release_pipeline(h) { release(h); },
		fw_gl_create_buffer(bufferType, byteSize) {
			// bufferType: 0=vertex 1=index 2=storage; 大小仅作提示, 上传时按需生效
			const b = gl.createBuffer();
			gl.bindVertexArray(null);
			const target = bufferType === 1 ? gl.ELEMENT_ARRAY_BUFFER : gl.ARRAY_BUFFER;
			gl.bindBuffer(target, b);
			gl.bufferData(target, byteSize, gl.DYNAMIC_DRAW);
			return retain("buffer", { gl: b, target });
		},
		fw_gl_upload_buffer(h, dataPtr, size, offset) {
			const b = get(h);
			if (!b) return;
			gl.bindVertexArray(null); // 保护 VAO 的 ELEMENT 绑定
			gl.bindBuffer(b.target, b.gl);
			gl.bufferSubData(b.target, offset, new Uint8Array(bridge.memory.buffer, dataPtr, size));
		},
		fw_gl_release_buffer(h) { const b = get(h); if (b) gl.deleteBuffer(b.gl); release(h); },
		fw_gl_create_texture(width, height) {
			const t = gl.createTexture();
			gl.bindTexture(gl.TEXTURE_2D, t);
			gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, GL.UNSIGNED_BYTE, null);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, GL.NEAREST);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, GL.NEAREST);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
			return retain("texture", t);
		},
		fw_gl_upload_texture(h, width, height, dataPtr, size) {
			const t = get(h);
			if (!t) return;
			gl.bindTexture(gl.TEXTURE_2D, t);
			const view = new Uint8Array(bridge.memory.buffer, dataPtr, size);
			// 9 参重载(带 width/height): 部分环境的 WebGL2 绑定不接受 7 参形式
			gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, view);
		},
		fw_gl_release_texture(h) { release(h); },
		fw_gl_create_sampler(filter, wrapX, wrapY) {
			const s = gl.createSampler();
			gl.samplerParameteri(s, gl.TEXTURE_MIN_FILTER, FILTER[filter]);
			gl.samplerParameteri(s, gl.TEXTURE_MAG_FILTER, FILTER[filter]);
			gl.samplerParameteri(s, gl.TEXTURE_WRAP_S, WRAP[wrapX]);
			gl.samplerParameteri(s, gl.TEXTURE_WRAP_T, WRAP[wrapY]);
			return retain("sampler", s);
		},
		fw_gl_release_sampler(h) { release(h); },

		// ---- 帧内命令 ----
		fw_begin_pass(fboTexture, r, g, b, a, doClear) {
			// M1: fboTexture 0 = 窗口画布; M2 接纹理 FBO
			gl.bindFramebuffer(gl.FRAMEBUFFER, null);
			gl.disable(gl.SCISSOR_TEST);
			if (doClear) {
				gl.clearColor(r, g, b, a);
				gl.clear(gl.COLOR_BUFFER_BIT);
			}
		},
		fw_end_pass() {
			gl.disable(gl.SCISSOR_TEST);
			gl.bindVertexArray(null);
		},
		fw_bind_pipeline(h) {
			const prog = get(h);
			if (!prog) return;
			pendingMatrix = null;
			pendingFragFloat = null;
			gl.useProgram(prog.program);
			gl.bindVertexArray(prog.vao);
			if (prog.blendEnable) {
				gl.enable(gl.BLEND);
				gl.blendEquationSeparate(prog.cOp, prog.aOp);
				gl.blendFuncSeparate(prog.cSrc, prog.cDst, prog.aSrc, prog.aDst);
			} else {
				gl.disable(gl.BLEND);
			}
			const m = prog.colorMask;
			gl.colorMask(!!(m & 1), !!(m & 2), !!(m & 4), !!(m & 8));
			if (prog.cull) { gl.enable(gl.CULL_FACE); gl.cullFace(prog.cull); }
			else gl.disable(gl.CULL_FACE);
		},
		fw_set_matrix4(stage, slot, dataPtr) {
			pendingMatrix = new Float32Array(bridge.memory.buffer, dataPtr, 16).slice();
		},
		fw_set_float(stage, slot, value) {
			pendingFragFloat = value;
		},
		fw_bind_texture(unit, texture, sampler) {
			gl.activeTexture(gl.TEXTURE0 + unit);
			gl.bindTexture(gl.TEXTURE_2D, texture ? get(texture) : whiteTex);
			gl.bindSampler(unit, sampler ? get(sampler) : null);
		},
		fw_bind_vertex_buffer(slot, buffer, stride) {
			const b = get(buffer);
			if (!b) return;
			gl.bindBuffer(gl.ARRAY_BUFFER, b.gl);
		},
		fw_vertex_attribute(location, slot, typeOrdinal, normalized, stride, offset) {
			const vt = VERTEX_TYPE[typeOrdinal];
			if (!vt) return;
			gl.enableVertexAttribArray(location);
			gl.vertexAttribPointer(location, vt[0], vt[1], normalized !== 0, stride, offset);
		},
		fw_bind_index_buffer(buffer) {
			const b = get(buffer);
			if (!b) return;
			gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.gl);
		},
		fw_draw_elements(count, indexType, byteOffset, instances) {
			applyPendingUniforms();
			if (instances > 1) gl.drawElementsInstanced(gl.TRIANGLES, count, INDEX_TYPE[indexType], byteOffset, instances);
			else gl.drawElements(gl.TRIANGLES, count, INDEX_TYPE[indexType], byteOffset);
		},
		fw_draw_arrays(count, offset, instances) {
			applyPendingUniforms();
			if (instances > 1) gl.drawArraysInstanced(gl.TRIANGLES, offset, count, instances);
			else gl.drawArrays(gl.TRIANGLES, offset, count);
		},
		fw_set_viewport(x, y, w, h, fbHeight) {
			gl.viewport(x, fbHeight - y - h, w, h); // SDL_GPU 左上原点 → GL 左下原点
		},
		fw_set_scissor(x, y, w, h, fbHeight) {
			gl.enable(gl.SCISSOR_TEST);
			gl.scissor(x, fbHeight - y - h, w, h);
		},

		// ---- M3: 相对鼠标 ----
		fw_set_mouse_relative(enabled) {
			if (enabled) {
				if (canvas.requestPointerLock) canvas.requestPointerLock();
			} else {
				if (document.exitPointerLock) document.exitPointerLock();
			}
		},

		// ---- 窗口全屏 ----
		fw_set_fullscreen(enabled) {
			try {
				if (enabled) {
					const el = document.documentElement;
					(el.requestFullscreen || el.webkitRequestFullscreen || function(){}).call(el);
				} else {
					(document.exitFullscreen || document.webkitExitFullscreen || function(){}).call(document);
				}
			} catch (e) { log("[foster.js] fullscreen: " + e); }
		},
		fw_is_fullscreen() {
			return (document.fullscreenElement || document.webkitFullscreenElement) ? 1 : 0;
		},

		// ---- M4: 虚拟文件系统(localStorage, 每文件一键, base64 二进制安全) ----
		fw_fs_exists(pathPtr, pathLen) {
			return localStorage.getItem(fsKey(readString(pathPtr, pathLen))) !== null ? 1 : 0;
		},
		fw_fs_size(pathPtr, pathLen) {
			const b = fsReadBytes(readString(pathPtr, pathLen));
			return b === null ? -1 : b.length;
		},
		fw_fs_read(pathPtr, pathLen, bufPtr, bufLen) {
			const b = fsReadBytes(readString(pathPtr, pathLen));
			if (b === null) return -1;
			const n = Math.min(b.length, bufLen);
			new Uint8Array(bridge.memory.buffer, bufPtr, n).set(b.subarray(0, n));
			return n;
		},
		fw_fs_write(pathPtr, pathLen, dataPtr, dataLen) {
			try {
				const bytes = new Uint8Array(bridge.memory.buffer, dataPtr, dataLen);
				localStorage.setItem(fsKey(readString(pathPtr, pathLen)), bytesToBase64(bytes));
				return 1;
			} catch (e) {
				log("[foster.js] fs write failed: " + e);
				return 0;
			}
		},
		fw_fs_remove(pathPtr, pathLen) {
			localStorage.removeItem(fsKey(readString(pathPtr, pathLen)));
			return 1;
		},
	};

	function applyPendingUniforms() {
		if (pendingMatrix !== null) {
			const loc = uniformLoc("u_matrix");
			if (loc) gl.uniformMatrix4fv(loc, false, pendingMatrix);
		}
		if (pendingFragFloat !== null) {
			const loc = uniformLoc("u_distance_range");
			if (loc) gl.uniform1f(loc, pendingFragFloat);
		}
	}

	let currentProgram = null;
	function uniformLoc(name) {
		if (!currentProgram) return null;
		const prog = get(currentProgram);
		if (!prog) return null;
		if (!(name in prog.locs)) prog.locs[name] = gl.getUniformLocation(prog.program, name);
		return prog.locs[name];
	}

	// 追踪当前管线(applyPendingUniforms 用)
	const origBindPipeline = bridge.fw_bind_pipeline;
	bridge.fw_bind_pipeline = function (h) { currentProgram = h; origBindPipeline(h); };

	function readString(ptr, len) {
		return new TextDecoder("utf-8").decode(new Uint8Array(bridge.memory.buffer, ptr, len));
	}

	// --- 实例化 + 帧循环 ---
	(async () => {
		try {
			syncCanvasSize();
			const wmi = new odin.WasmMemoryInterface();
			const imports = odin.setupDefaultImports(wmi, logEl, null);
			imports.foster_web = countedBridge;
			// 游戏侧附加桥(如音频): 页面在加载 foster.js 前设置 window.FOSTER_EXTRA_IMPORTS
			const extras = window.FOSTER_EXTRA_IMPORTS || {};
			for (const k in extras) imports[k] = extras[k];
			const file = await (await fetch(WASM_URL, { cache: "no-cache" })).arrayBuffer();
			const wasm = await WebAssembly.instantiate(file, imports);
			const exp = wasm.instance.exports;
			wmi.setExports(exp);
			if (exp.memory) {
				wmi.setMemory(exp.memory);
				bridge.setMemory(exp.memory);
				for (const k in extras) {
					if (extras[k] && typeof extras[k].setMemory === "function") extras[k].setMemory(exp.memory);
				}
			}
			window.__fosterExports = exp;
			log("[foster.js] instantiated, exports: " + Object.keys(exp).filter(k => !k.startsWith("_")).join(","));

			if (exp._start) exp._start(); // main → InitApp → Run(注册 web_app 后返回)

			if (exp.foster_step) {
				const ctxPtr = exp.default_context_ptr();
				let prev = undefined;
				const frame = (ts) => {
					if (prev === undefined) prev = ts;
					const dt = (ts - prev) * 0.001;
					prev = ts;
					let keep = true;
					try {
						keep = exp.foster_step(dt, ctxPtr);
					} catch (e) {
						log("[foster.js] foster_step ERROR: " + e);
						return; // 停止帧循环, 避免错误刷屏
					}
					if (keep) requestAnimationFrame(frame);
				};
				requestAnimationFrame(frame);
			} else {
				log("[foster.js] no foster_step export — did the app call foster.Run?");
			}
		} catch (e) {
			log("[foster.js] ERROR " + e);
		}
	})();
})();
