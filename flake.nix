# SPDX-FileCopyrightText: 2026 Ingo Ruhnke <grumbel@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Kurvenrausch website: static landing page + WASM from the game flake +
# GitHub Pages. Same shape as SuperTux-Origins.github.io.
#
#   nix build          # → result/ (index.html, images/, play/)
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
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        kurvenrausch-wasm = kurvenrausch.packages.${system}.kurvenrausch-wasm;

        site = pkgs.runCommand "kurvenrausch-site" { } ''
          mkdir -p $out
          cp -v ${./index.html} $out/index.html
          cp -rv ${./images} $out/images

          # Playable WASM build from the game flake (html/js/wasm + index.html).
          mkdir -p $out/play
          cp -rv ${kurvenrausch-wasm}/. $out/play/
          chmod -R u+w $out/play

          # Prefer a stable entry name if the package only ships index.html.
          if [ ! -f $out/play/kurvenrausch.html ] && [ -f $out/play/index.html ]; then
            cp -v $out/play/index.html $out/play/kurvenrausch.html
          fi
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
