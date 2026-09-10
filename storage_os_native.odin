#+build !js

package foster_framework

// 存储层本机文件后端: 所有 core:os 调用收口在这里(core:os 在 js 目标不可用,
// storage_runtime.odin 通过本层间接使用)。Web 对应实现在 storage_os_web.odin。

import "core:strings"
import os "core:os"

storage_os_exists :: proc(path: string) -> bool {
	return os.exists(path)
}

storage_os_is_directory :: proc(path: string) -> bool {
	return os.is_directory(path)
}

storage_os_enumerate :: proc(path: string, allocator := context.allocator) -> []string {
	infos, err := os.read_all_directory_by_path(path, allocator)
	if err != nil {
		return nil
	}
	defer os.file_info_slice_delete(infos, allocator)

	result := make([dynamic]string, 0, len(infos), allocator)
	for info in infos {
		name, clone_err := strings.clone(info.name, allocator)
		if clone_err != nil {
			continue
		}
		append(&result, name)
	}
	return result[:]
}

storage_os_make_directory_all :: proc(path: string) -> bool {
	return os.make_directory_all(path) == nil
}

storage_os_remove :: proc(path: string) -> bool {
	if os.is_directory(path) {
		return os.remove_all(path) == nil
	}
	return os.remove(path) == nil
}

storage_os_read_file :: proc(path: string, allocator := context.allocator) -> []byte {
	data, err := os.read_entire_file(path, allocator)
	if err != nil {
		return nil
	}
	return data
}

storage_os_write_file :: proc(path: string, data: []byte) -> bool {
	return os.write_entire_file(path, data) == nil
}

storage_os_working_directory :: proc(allocator := context.allocator) -> string {
	dir, err := os.get_working_directory(allocator)
	if err != nil {
		return ""
	}
	return dir
}
