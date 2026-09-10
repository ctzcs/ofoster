#+build js wasm32, js wasm64p32

package foster_framework

// Web(js_wasm32) 平台实现：storage 的 OS 层/路径层 + 线程 ID。
// 本机平台对应 platform_native.odin（拆分原因见该文件头注释）。

import slashpath "core:path/slashpath"

// ===== storage OS 层（虚拟 FS 的 JS 桥）（原 storage_os_web.odin） =====
// 存储层 Web 文件后端(M4): 经 foster_web 桥落到 foster.js 的
// localStorage 虚拟文件系统(每个文件一个键, base64 载荷, 二进制安全)。
// 路径为虚拟绝对路径(如 /foster/<app>/settings.txt), 无目录层级 ——
// 目录类查询恒为 false, 枚举暂不支持(需要时再扩展桥)。

storage_os_exists :: proc(path: string) -> bool {
	if len(path) == 0 {
		return false
	}
	ptr, length := web_string_bytes(path)
	return fw_fs_exists(ptr, length) != 0
}

storage_os_is_directory :: proc(path: string) -> bool {
	_ = path
	return false // 扁平 FS, 无目录概念
}

storage_os_enumerate :: proc(path: string, allocator := context.allocator) -> []string {
	_ = path
	_ = allocator
	return nil // M4 非目标; 需要时在桥上加枚举接口
}

storage_os_make_directory_all :: proc(path: string) -> bool {
	_ = path
	return true // 扁平 FS: 视为成功
}

storage_os_remove :: proc(path: string) -> bool {
	if len(path) == 0 {
		return false
	}
	ptr, length := web_string_bytes(path)
	return fw_fs_remove(ptr, length) != 0
}

storage_os_read_file :: proc(path: string, allocator := context.allocator) -> []byte {
	if len(path) == 0 {
		return nil
	}
	ptr, length := web_string_bytes(path)
	size := fw_fs_size(ptr, length)
	if size < 0 {
		return nil
	}
	data := make([]byte, size, allocator)
	if size > 0 {
		read := fw_fs_read(ptr, length, &data[0], size)
		if read != size {
			delete(data)
			return nil
		}
	}
	return data
}

storage_os_write_file :: proc(path: string, data: []byte) -> bool {
	if len(path) == 0 {
		return false
	}
	path_ptr, path_len := web_string_bytes(path)
	if len(data) == 0 {
		return fw_fs_write(path_ptr, path_len, nil, 0) != 0
	}
	return fw_fs_write(path_ptr, path_len, &data[0], i32(len(data))) != 0
}

storage_os_working_directory :: proc(allocator := context.allocator) -> string {
	_ = allocator
	return ""
}

// ===== storage 路径层（斜杠路径语义）（原 storage_path_web.odin） =====
// 存储层 Web 路径后端: 用 core:path/slashpath 的纯斜杠实现。
// Web 侧根路径都是虚拟路径("/foster/<app>/"), 斜杠语义正确。


storage_path_clean :: proc(path: string, allocator := context.temp_allocator) -> string {
	return slashpath.clean(path, allocator)
}

storage_path_join :: proc(parts: []string, allocator := context.temp_allocator) -> string {
	return slashpath.join(parts, allocator)
}

storage_path_split :: proc(path: string) -> (dir, file: string) {
	return slashpath.split(path)
}

// ===== 线程 ID（wasm 无并发, 恒为主线程）（原 platform_thread_web.odin） =====
// Web 平台的线程 ID: wasm 无并发(Phase 1 无线程), 恒为主线程

platform_current_thread_id :: proc() -> int {
	return 1
}
