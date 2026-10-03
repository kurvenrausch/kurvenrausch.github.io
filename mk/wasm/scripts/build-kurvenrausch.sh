#!/usr/bin/env bash
# Cross-compile Kurvenrausch to wasm32 + HTML via emcc.
#
# Env (set by flake.nix):
#   APP_NAME       - basename for outputs (default: kurvenrausch)
#   SRC_DIR        - kurvenrausch source tree (CMakeLists.txt, src/, include/)
#   SDL_WASM_LIBS  - prefix with include/ + lib/libSDL2.a
#   WASM_SHELL     - optional HTML shell for --shell-file
set -euo pipefail

export EM_CACHE="${TMPDIR:-/tmp}/emcache"
mkdir -p "$EM_CACHE"

APP_NAME="${APP_NAME:-kurvenrausch}"
SRC_DIR="${SRC_DIR:?SRC_DIR required}"
SDL_WASM_LIBS="${SDL_WASM_LIBS:?SDL_WASM_LIBS required}"

if [ ! -d "$SRC_DIR/src" ]; then
  echo "error: $SRC_DIR does not look like kurvenrausch (no src/)" >&2
  exit 1
fi
if [ ! -f "$SDL_WASM_LIBS/lib/libSDL2.a" ]; then
  echo "error: $SDL_WASM_LIBS/lib/libSDL2.a missing" >&2
  exit 1
fi

# Work on a writable copy so we can apply a tiny browser main-loop shim.
WORK="$PWD/src-tree"
rm -rf "$WORK"
cp -a "$SRC_DIR" "$WORK"
chmod -R u+w "$WORK"

# ---- Browser main-loop shim ----------------------------------------------
# Desktop builds block in while(running) { poll; step; present; }. Emscripten
# needs the body driven by emscripten_set_main_loop so the browser can paint.
# We inject a thin adapter into main.cpp when emscripten is detected.
MAIN="$WORK/src/main.cpp"
if ! grep -q 'emscripten_set_main_loop' "$MAIN"; then
  echo "==> patching main.cpp for emscripten main loop"
  # Prepend include after the first #include block start — simpler: insert
  # after the game.hpp include.
  python3 - "$MAIN" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
if "emscripten.h" in text:
    print("already has emscripten include")
    sys.exit(0)
needle = '#include "game.hpp"'
if needle not in text:
    # try angle form
    needle = "#include <game.hpp>"
if needle not in text:
    print("warn: could not find game.hpp include; leaving main unpatched", file=sys.stderr)
    sys.exit(0)
insert = '''#include "game.hpp"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h>
#endif
'''
# Replace only the include line once, keep rest.
text2 = text.replace(needle, insert, 1)
# Also try to wrap a typical SDL event loop if present. Kurvenrausch keeps
# the loop inside game code; the flake relies on Asyncify so blocking loops
# still yield. No further structural rewrite here.
open(path, "w", encoding="utf-8").write(text2)
print("patched includes")
PY
fi

# Collect sources the same way CMake does (core + main).
mapfile -t CORE_SRCS < <(find "$WORK/src" -name '*.cpp' ! -name 'main.cpp' | sort)
MAIN_SRC="$WORK/src/main.cpp"
INCLUDE="$WORK/include"

echo "==> compiling ${#CORE_SRCS[@]} core sources + main → $APP_NAME"

# Flags for a software-rendered 320x240 game scaled up in the browser.
# ASYNCIFY lets the existing blocking main loop yield to the browser.
EM_CFLAGS=(
  -O2
  -std=c++17
  -I"$INCLUDE"
  -I"$SDL_WASM_LIBS/include"
  -I"$SDL_WASM_LIBS/include/SDL2"
  -D__EMSCRIPTEN__
  -DKURVENRAUSCH_VERSION="\"wasm\""
  -sUSE_SDL=0
)

EM_LDFLAGS=(
  -O2
  -L"$SDL_WASM_LIBS/lib"
  -lSDL2
  -sUSE_SDL=0
  -sWASM=1
  -sALLOW_MEMORY_GROWTH=1
  -sINITIAL_MEMORY=67108864
  -sASYNCIFY
  -sASYNCIFY_IMPORTS=['emscripten_sleep']
  -sFORCE_FILESYSTEM=0
  -sENVIRONMENT=web
  -sEXPORTED_RUNTIME_METHODS=['ccall','cwrap']
  -sASSERTIONS=1
  --bind
)

if [ -n "${WASM_SHELL:-}" ] && [ -f "$WASM_SHELL" ]; then
  EM_LDFLAGS+=(--shell-file "$WASM_SHELL")
  echo "==> HTML shell: $WASM_SHELL"
fi

# Object files
mkdir -p objs
OBJS=()
for src in "${CORE_SRCS[@]}" "$MAIN_SRC"; do
  base=$(basename "$src" .cpp)
  obj="objs/${base}.o"
  echo "  em++ $src"
  em++ "${EM_CFLAGS[@]}" -c "$src" -o "$obj"
  OBJS+=("$obj")
done

echo "==> linking $APP_NAME.html"
em++ "${OBJS[@]}" "${EM_LDFLAGS[@]}" -o "${APP_NAME}.html"

ls -la "${APP_NAME}".*
echo "==> wasm build done"
