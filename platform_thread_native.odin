#+build !js

package foster_framework

// 桌面/本机平台的线程 ID(core:os 在 js 目标不可用, 见 platform_thread_web.odin)

import os "core:os"

platform_current_thread_id :: proc() -> int {
	return os.get_current_thread_id()
}
