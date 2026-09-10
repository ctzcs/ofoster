#+build js wasm32, js wasm64p32

package foster_framework

// Web 平台的线程 ID: wasm 无并发(Phase 1 无线程), 恒为主线程

platform_current_thread_id :: proc() -> int {
	return 1
}
