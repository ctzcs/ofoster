#+build js wasm32, js wasm64p32

package foster_framework

// 存储层 Web 路径后端: 用 core:path/slashpath 的纯斜杠实现。
// Web 侧根路径都是虚拟路径("/foster/<app>/"), 斜杠语义正确。

import slashpath "core:path/slashpath"

storage_path_clean :: proc(path: string, allocator := context.temp_allocator) -> string {
	return slashpath.clean(path, allocator)
}

storage_path_join :: proc(parts: []string, allocator := context.temp_allocator) -> string {
	return slashpath.join(parts, allocator)
}

storage_path_split :: proc(path: string) -> (dir, file: string) {
	return slashpath.split(path)
}
