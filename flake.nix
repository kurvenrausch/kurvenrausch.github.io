# SPDX-FileCopyrightText: 2026 Ingo Ruhnke <grumbel@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Kurvenrausch website: static landing page + WASM and the downloadable
# ports (Windows, Android, R36S) from the game flake + GitHub Pages. Same
# shape as SuperTux-Origins.github.io.
#
#   nix build          # → result/ (index.html, images/, play/, downloads/)
#   nix run .#serve    # local preview
#
{
  description = "Kurvenrausch website (WASM + GitHub Pages), Nix-first";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    kurvenrausch.url = "github:Grumbel/kurvenrausch";
    kurvenrausch.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, kurvenrausch }:
    # x86_64-linux only: the Android SDK and NDK the game's Android build
    # needs are not packaged for other hosts.
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        game = kurvenrausch.packages.${system};
        version = game.kurvenrausch.version;

        site = pkgs.runCommand "kurvenrausch-site" { } ''
          mkdir -p $out
          substitute ${./index.html} $out/index.html --subst-var-by version ${version}
          cp -rv ${./images} $out/images

          # Playable WASM build from the game flake (html/js/wasm + index.html).
          mkdir -p $out/play
          cp -rv ${game.kurvenrausch-wasm}/. $out/play/
          chmod -R u+w $out/play

          # The ports, built from the same revision, under stable names so
          # the page's links never change (the version is on the page).
          mkdir -p $out/downloads/r36s
          cp -v ${game.kurvenrausch-win64-zip}/*.zip $out/downloads/kurvenrausch-win64.zip
          cp -v ${game.kurvenrausch-win32-zip}/*.zip $out/downloads/kurvenrausch-win32.zip
          cp -v ${game.kurvenrausch-android}/*.apk $out/downloads/kurvenrausch.apk
          # PortMaster expects the zip under the name its port.json gives.
          cp -v ${game.kurvenrausch-r36s-portmaster-zip}/kurvenrausch.zip $out/downloads/r36s/kurvenrausch.zip
          chmod -R u+w $out/downloads
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
        };

        apps = {
          default = serveApp;
          serve = serveApp;
        };
      });
}
