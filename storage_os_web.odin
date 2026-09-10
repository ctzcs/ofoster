#+build js wasm32, js wasm64p32

package foster_framework

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
