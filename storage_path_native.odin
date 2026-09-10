#+build !js

package foster_framework

// 存储层本机路径后端(core:path/filepath 的 path.odin 无条件依赖 core:os,
// js 目标不可用, 故收口到本层; Web 对应实现在 storage_path_web.odin)。
// 行为与原先直接调用 core:path/filepath 完全一致(平台分隔符语义)。

import filepath "core:path/filepath"

storage_path_clean :: proc(path: string, allocator := context.temp_allocator) -> string {
	cleaned, _ := filepath.clean(path, allocator)
	return cleaned
}

storage_path_join :: proc(parts: []string, allocator := context.temp_allocator) -> string {
	joined, _ := filepath.join(parts, allocator)
	return joined
}

storage_path_split :: proc(path: string) -> (dir, file: string) {
	return filepath.split(path)
}
