#!/bin/sh
# OFoster webtest - Web (js_wasm32) 构建(Linux/macOS)
# 产物: webtest/webtest.wasm (+ 拷贝 odin.js)
# 运行: 仓库根目录起本地服务(python3 -m http.server 8137),
#       浏览器打开 http://localhost:8137/webtest/
set -e
cd "$(dirname "$0")/.."
ODIN_BIN="${ODIN:-odin}"
ODIN_ROOT="$("$ODIN_BIN" root 2>/dev/null || true)"
ODIN_JS="$ODIN_ROOT/core/sys/wasm/js/odin.js"
$ODIN_BIN build webtest -collection:ofoster=. -target:js_wasm32 -o:speed -out:webtest/webtest.wasm
if [ ! -f webtest/odin.js ]; then
	if [ -f "$ODIN_JS" ]; then
		cp "$ODIN_JS" webtest/odin.js
	else
		echo "warn: 未找到 odin.js, 请手动从 Odin 安装的 core/sys/wasm/js/ 复制到 webtest/"
	fi
fi
echo "web build ok: webtest/webtest.wasm"
