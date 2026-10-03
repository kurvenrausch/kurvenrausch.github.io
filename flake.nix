# SPDX-FileCopyrightText: 2026 Ingo Ruhnke <grumbel@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Kurvenrausch web site: static landing page + WASM playable build +
# GitHub Pages packaging, modeled on SuperTux-Origins.github.io.
#
#   nix build          # → result/ (index.html, images/, play/)
#   nix run .#serve    # local preview
#
{
  description = "Kurvenrausch website (WASM + GitHub Pages), Nix-first";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Game sources + native package. WASM is built here from the same tree.
    kurvenrausch.url = "github:Grumbel/kurvenrausch";
    kurvenrausch.inputs.nixpkgs.follows = "nixpkgs";

    # Official SDL2 release used for the Emscripten static library.
    sdl2-src = {
      url = "https://github.com/libsdl-org/SDL/releases/download/release-2.30.9/SDL2-2.30.9.tar.gz";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, kurvenrausch, sdl2-src }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = nixpkgs.lib;

        # ---- SDL2 static library for wasm32-unknown-emscripten ----
        sdl2Wasm = pkgs.stdenv.mkDerivation {
          pname = "sdl2-wasm";
          version = "2.30.9";
          dontUnpack = true;
          dontConfigure = true;
          dontUseCmakeConfigure = true;
          nativeBuildInputs = [ pkgs.emscripten pkgs.cmake pkgs.python3 ];
          env.SDL_SRC = "${sdl2-src}";
          buildPhase = ''
            runHook preBuild
            export EM_CACHE="$TMPDIR/emcache"
            mkdir -p "$EM_CACHE"
            PREFIX="$PWD/prefix"
            mkdir -p "$PREFIX"
            cp -a "$SDL_SRC" SDL2-src
            chmod -R u+w SDL2-src
            mkdir -p build-sdl2
            cd build-sdl2
            emcmake cmake ../SDL2-src \
              -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX="$PREFIX" \
              -DSDL_SHARED=OFF \
              -DSDL_STATIC=ON \
              -DSDL_TEST=OFF \
              -DSDL_STATIC_PIC=ON
            emmake make -j''${NIX_BUILD_CORES:-$(nproc)}
            emmake make install
            cd ..
            if [ ! -f "$PREFIX/lib/libSDL2.a" ]; then
              find build-sdl2 -name 'libSDL2.a' -exec cp {} "$PREFIX/lib/" \; || true
            fi
            mkdir -p "$PREFIX/include"
            if [ ! -d "$PREFIX/include/SDL2" ] && [ -d SDL2-src/include ]; then
              cp -a SDL2-src/include/. "$PREFIX/include/" || true
            fi
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -a prefix/. $out/
            if [ ! -f $out/lib/libSDL2.a ]; then
              echo "error: libSDL2.a missing after wasm SDL2 build" >&2
              exit 1
            fi
            mkdir -p $out/lib/pkgconfig
            cat > $out/lib/pkgconfig/sdl2.pc <<EOF
            prefix=$out
            exec_prefix=\''${prefix}
            libdir=\''${exec_prefix}/lib
            includedir=\''${prefix}/include
            Name: sdl2
            Description: Simple DirectMedia Layer
            Version: 2.30.9
            Libs: -L\''${libdir} -lSDL2
            Cflags: -I\''${includedir} -I\''${includedir}/SDL2
            EOF
            runHook postInstall
          '';
        };

        # ---- Kurvenrausch → HTML/JS/WASM via Emscripten ----
        # Software-rendered 320x240 framebuffer; no image/mixer codecs.
        # The game main loop is patched at build time for emscripten_set_main_loop.
        kurvenrauschWasm = pkgs.stdenv.mkDerivation {
          pname = "kurvenrausch-wasm";
          version = kurvenrausch.packages.${system}.default.version or "0.1.0-dev";
          dontUnpack = true;
          dontConfigure = true;
          dontUseCmakeConfigure = true;
          nativeBuildInputs = [ pkgs.emscripten pkgs.cmake pkgs.python3 pkgs.pkg-config ];
          env = {
            SRC_DIR = "${kurvenrausch}";
            SDL_WASM_LIBS = "${sdl2Wasm}";
            WASM_SHELL = "${./mk/wasm/shell.html}";
            APP_NAME = "kurvenrausch";
          };
          buildPhase = ''
            runHook preBuild
            export EM_CACHE="$TMPDIR/emcache"
            mkdir -p "$EM_CACHE"
            bash ${./mk/wasm/scripts/build-kurvenrausch.sh}
            runHook postBuild
          '';
          installPhase = ''
            set -euo pipefail
            mkdir -p $out
            for f in kurvenrausch.html kurvenrausch.js kurvenrausch.wasm kurvenrausch.data; do
              if [ -f "$f" ]; then cp -v "$f" $out/; fi
            done
            # Emscripten sometimes writes into a build/ subdir
            for f in build/kurvenrausch.html build/kurvenrausch.js build/kurvenrausch.wasm build/kurvenrausch.data; do
              if [ -f "$f" ] && [ ! -f $out/$(basename "$f") ]; then
                cp -v "$f" $out/
              fi
            done
            if [ ! -f $out/kurvenrausch.html ]; then
              echo "error: kurvenrausch.html missing after wasm build" >&2
              find . -maxdepth 3 -type f \( -name '*.html' -o -name '*.js' -o -name '*.wasm' \) -print || true
              exit 1
            fi
            # Stable name used by index.html
            if [ ! -f $out/index.html ]; then
              cp $out/kurvenrausch.html $out/index.html
            fi
            ls -la $out
          '';
          meta = with lib; {
            description = "Kurvenrausch (WebAssembly / Emscripten)";
            license = licenses.gpl3Plus;
            platforms = platforms.linux;
          };
        };

        # ---- Static site assembled for GitHub Pages ----
        site = pkgs.runCommand "kurvenrausch-site" { } ''
          mkdir -p $out
          cp -v ${./index.html} $out/index.html
          cp -rv ${./images} $out/images
          mkdir -p $out/play
          cp -rv ${kurvenrauschWasm}/. $out/play/
          chmod -R u+w $out
        '';

        serveApp = {
          type = "app";
          program = toString (pkgs.writeShellScript "serve-kurvenrausch-site" ''
            set -euo pipefail
            export PKG="${site}"
            export KURVENRAUSCH_PORT="''${KURVENRAUSCH_PORT:-8765}"
            exec ${./scripts/serve.sh}
          '');
        };
      in {
        packages = {
          default = site;
          site = site;
          kurvenrausch-wasm = kurvenrauschWasm;
          sdl2-wasm = sdl2Wasm;
        };

        apps = {
          default = serveApp;
          serve = serveApp;
        };

        # Convenience: native game from the upstream flake
        checks.native = kurvenrausch.packages.${system}.default;
      });
}
