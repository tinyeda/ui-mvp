#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MODE=${1:-debug}
PLATFORM=${2:-host}
ARCH=${3:-native}
ACTION=${4:-build}

error() { printf 'error: %s\n' "$1" >&2; exit 1; }
require() { command -v "$1" >/dev/null 2>&1 || error "$1 is required"; }

build_web() {
	local out="$ROOT/build/web" object="$ROOT/build/web/tinyeda.wasm.obj" odin_root
	require odin
	require em++
	require node
	odin_root=$(odin root)
	mkdir -p "$out"
	odin build "$ROOT/code/web" -target:js_wasm32 -build-mode:obj -o:size \
		-define:RAYLIB_WASM_LIB=env.o -define:IMGUI_WASM_LIB=env.o "-out:$object"
	cp "$odin_root/core/sys/wasm/js/odin.js" "$out/odin.js"
	em++ -o "$out/index.html" "$object" \
		"$odin_root/vendor/raylib/wasm/libraylib.web.a" \
		"$ROOT/third-party/imgui/lib/libtinyeda_imgui_wasm32.a" \
		-sUSE_GLFW=3 -sWASM_BIGINT -sALLOW_MEMORY_GROWTH=1 -sASSERTIONS=1 \
		-sWARN_ON_UNDEFINED_SYMBOLS=0 -sEXPORTED_RUNTIME_METHODS='["HEAPF32"]' \
		--shell-file "$ROOT/code/web/index_template.html"
	mkdir -p "$out/licenses"
	cp "$ROOT/third-party/fonts/atkinson-hyperlegible-next/OFL.txt" \
		"$out/licenses/Atkinson-Hyperlegible-Next-OFL.txt"
	node - "$out/index.wasm" <<'NODE'
const fs = require("fs");
const wasmModule = new WebAssembly.Module(fs.readFileSync(process.argv[2]));
const invalid = WebAssembly.Module.imports(wasmModule).find(({module}) => module.endsWith(".a"));
if (invalid) throw new Error(`static library emitted as WASM import: ${invalid.module}`);
NODE
	rm -f -- "$object"
	BINARY="$out/index.html"
}

case "$(uname -s)" in
Darwin) HOST_PLATFORM=macos ;;
Linux) HOST_PLATFORM=linux ;;
MINGW*|MSYS*|CYGWIN*) HOST_PLATFORM=windows ;;
*) error "unsupported host: $(uname -s)" ;;
esac
case "$(uname -m)" in
x86_64|amd64) HOST_ARCH=x64 ;;
arm64|aarch64) HOST_ARCH=arm64 ;;
*) error "unsupported architecture: $(uname -m)" ;;
esac

[ "$PLATFORM" = host ] && PLATFORM=$HOST_PLATFORM
[ "$ARCH" = native ] && ARCH=$HOST_ARCH
case "$MODE" in debug|release) ;; *) error "mode must be debug or release" ;; esac
case "$PLATFORM" in macos|windows|linux|web) ;; *) error "unknown platform: $PLATFORM" ;; esac
case "$ACTION" in build|package|run) ;; *) error "action must be build, package, or run" ;; esac

if [ "$PLATFORM" = web ]; then
	[ "$ACTION" != run ] || error "serve build/web to run the web build"
	build_web
	printf '%s\n' "$BINARY"
	exit
fi

[ "$PLATFORM" = "$HOST_PLATFORM" ] || error "$PLATFORM builds require a $PLATFORM host"
[ "$ARCH" != universal ] || [ "$PLATFORM" = macos ] || error "universal is only supported on macOS"
[ "$PLATFORM" != windows ] || [ "$ARCH" = x64 ] || error "Windows currently supports x64"
[ "$PLATFORM" = macos ] || [ "$ARCH" = "$HOST_ARCH" ] || error "$PLATFORM $ARCH requires a matching runner"
require odin

ODIN_FLAGS=(-debug)
[ "$MODE" != release ] || ODIN_FLAGS=(-o:speed)

build_one() {
	local arch=$1 target library suffix='' out
	case "$PLATFORM:$arch" in
	macos:x64) target=darwin_amd64; library=libtinyeda_imgui_macos_x64.a ;;
	macos:arm64) target=darwin_arm64; library=libtinyeda_imgui_macos_arm64.a ;;
	linux:x64) target=linux_amd64; library=libtinyeda_imgui_linux_x64.a ;;
	linux:arm64) target=linux_arm64; library=libtinyeda_imgui_linux_arm64.a ;;
	windows:x64) target=windows_amd64; library=tinyeda_imgui_windows_x64.lib; suffix=.exe ;;
	*) error "unsupported target: $PLATFORM $arch" ;;
	esac
	[ -f "$ROOT/third-party/imgui/lib/$library" ] || error "missing static library: third-party/imgui/lib/$library"

	out="$ROOT/build/$MODE/$PLATFORM-$arch"
	mkdir -p "$out"
	BINARY="$out/TinyEDA$suffix"
	odin build "$ROOT/code" "-target:$target" "${ODIN_FLAGS[@]}" "-out:$BINARY"
}

package_macos() {
	local out app executable zip arm_binary
	out="$ROOT/build/$MODE/macos-$ARCH"
	app="$out/TinyEDA.app"
	executable="$app/Contents/MacOS/TinyEDA"
	zip="$out/TinyEDA-macos-$ARCH.zip"
	rm -rf -- "$app"
	mkdir -p "$app/Contents/MacOS"
	cp "$ROOT/packaging/macos/Info.plist" "$app/Contents/Info.plist"

	if [ "$ARCH" = universal ]; then
		build_one arm64; arm_binary=$BINARY
		build_one x64
		lipo -create "$arm_binary" "$BINARY" -output "$executable"
	else
		build_one "$ARCH"
		cp "$BINARY" "$executable"
	fi

	chmod +x "$executable"
	codesign --force --sign "${MACOS_SIGN_IDENTITY:--}" "$app"
	codesign --verify --deep --strict "$app"
	rm -f -- "$zip"
	ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
	BINARY=$zip
}

package_linux() {
	local out appdir tool appimage_arch
	build_one "$ARCH"
	out="$ROOT/build/$MODE/linux-$ARCH"
	appdir="$out/TinyEDA.AppDir"
	appimage_arch=$([ "$ARCH" = x64 ] && printf x86_64 || printf aarch64)
	tool=${APPIMAGETOOL:-$(command -v appimagetool || true)}
	[ -n "$tool" ] || error "set APPIMAGETOOL or install appimagetool"
	rm -rf -- "$appdir"
	mkdir -p "$appdir/usr/bin" "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/scalable/apps"
	cp "$BINARY" "$appdir/usr/bin/TinyEDA"
	cp "$ROOT/packaging/linux/tinyeda.desktop" "$appdir/"
	cp "$ROOT/packaging/linux/tinyeda.desktop" "$appdir/usr/share/applications/"
	cp "$ROOT/packaging/linux/tinyeda.svg" "$appdir/tinyeda.svg"
	cp "$ROOT/packaging/linux/tinyeda.svg" "$appdir/usr/share/icons/hicolor/scalable/apps/"
	ln -s usr/bin/TinyEDA "$appdir/AppRun"
	BINARY="$out/TinyEDA-linux-$appimage_arch.AppImage"
	rm -f -- "$BINARY"
	ARCH=$appimage_arch APPIMAGE_EXTRACT_AND_RUN=1 "$tool" "$appdir" "$BINARY"
}

package_windows() {
	local out package
	build_one "$ARCH"
	out="$ROOT/build/$MODE/windows-$ARCH"
	package="$out/TinyEDA-windows-$ARCH.exe"
	cp "$BINARY" "$package"
	BINARY=$package
}

case "$ACTION:$PLATFORM" in
package:macos) package_macos ;;
package:linux) package_linux ;;
package:windows) package_windows ;;
*) [ "$ARCH" != universal ] || error "universal requires the package action"; build_one "$ARCH" ;;
esac

printf '%s\n' "$BINARY"
[ "$ACTION" != run ] || "$BINARY"
