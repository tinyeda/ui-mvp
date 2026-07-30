#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT_DIR="$ROOT_DIR/build/web"
ODIN_ROOT=$(odin root)

if ! command -v em++ >/dev/null 2>&1; then
	echo "error: em++ is not on PATH; activate emsdk before running this script" >&2
	exit 1
fi

mkdir -p "$OUT_DIR"
OBJECT="$OUT_DIR/tinyeda.wasm.obj"
trap 'rm -f "$OBJECT"' EXIT

odin build "$ROOT_DIR/code/web" \
	-target:js_wasm32 \
	-build-mode:obj \
	-define:RAYLIB_WASM_LIB=env.o \
	-define:IMGUI_WASM_LIB=env.o \
	-out:"$OBJECT"

cp "$ODIN_ROOT/core/sys/wasm/js/odin.js" "$OUT_DIR/odin.js"

em++ -o "$OUT_DIR/index.html" \
	"$OBJECT" \
	"$ODIN_ROOT/vendor/raylib/wasm/libraylib.web.a" \
	"$ROOT_DIR/third-party/imgui/lib/libtinyeda_imgui_wasm32.a" \
	-sUSE_GLFW=3 \
	-sWASM_BIGINT \
	-sALLOW_MEMORY_GROWTH=1 \
	-sASSERTIONS=1 \
	-sWARN_ON_UNDEFINED_SYMBOLS=0 \
	-sEXPORTED_RUNTIME_METHODS='["HEAPF32"]' \
	--shell-file "$ROOT_DIR/code/web/index_template.html"

echo "Web build created in $OUT_DIR"
