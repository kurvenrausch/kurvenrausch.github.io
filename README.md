# Kurvenrausch website

Static site and **WebAssembly** build for
[Kurvenrausch](https://github.com/Grumbel/kurvenrausch), structured like
[SuperTux-Origins.github.io](https://github.com/SuperTux-Origins/SuperTux-Origins.github.io):

- **Nix flake** builds the playable WASM package (Emscripten + static SDL2)
  and assembles `index.html`, screenshots, and `play/` into a single store path
- **GitHub Pages** deploys that path via `.github/workflows/pages.yml`
- **Local preview**: `nix run .#serve`

## Layout

```
.
├── flake.nix                 # site + kurvenrausch-wasm + sdl2-wasm
├── index.html                # landing page
├── images/                   # screenshots (from the game docs/)
├── scripts/serve.sh          # local HTTP server (no-cache headers)
├── mk/wasm/
│   ├── shell.html            # Emscripten HTML shell
│   └── scripts/
│       └── build-kurvenrausch.sh
└── .github/workflows/pages.yml
```

## Commands

```bash
# Build the full site (HTML + WASM under play/)
nix build
ls result/
# result/index.html  result/images/  result/play/kurvenrausch.{html,js,wasm}

# WASM package only
nix build .#kurvenrausch-wasm

# Serve and open a browser (port 8765 by default)
nix run .
# or:
KURVENRAUSCH_PORT=9000 nix run .#serve
```

## GitHub Pages

1. Push this repository to GitHub (e.g. `Grumbel/kurvenrausch-web` or a
   `*.github.io` repo).
2. Under **Settings → Pages**, set the source to **GitHub Actions**.
3. On every push to `master`, the workflow runs `nix build` and deploys
   `result/` with `actions/deploy-pages`.

The first build compiles SDL2 for wasm and the game; later builds reuse the
Nix / Actions cache.

## Notes on the WASM port

Kurvenrausch is pure software rendering into a 320×240 framebuffer with
procedural art and synthesised audio — no asset pack is preloaded. The flake:

1. Builds a **static SDL2** with Emscripten (`sdl2-wasm`)
2. Compiles every `src/*.cpp` with `em++`, linking against that SDL2
3. Enables **ASYNCIFY** so the existing blocking main loop can yield to the
   browser without rewriting the game loop yet

If the upstream game later exports a `packages.<system>.kurvenrausch-wasm`
output, this flake can be simplified to consume that package the same way
SuperTux-Origins.github.io consumes `supertux-*-wasm`.

## License

Site scaffolding: same spirit as the SuperTux Origins template (use freely).
Game binary/WASM: **GPL-3.0-or-later** (see [Grumbel/kurvenrausch](https://github.com/Grumbel/kurvenrausch)).
Screenshots under `images/` are from the game documentation.
