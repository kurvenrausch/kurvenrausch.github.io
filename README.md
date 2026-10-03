# Kurvenrausch website

Static site for [Kurvenrausch](https://github.com/Grumbel/kurvenrausch), structured
like [SuperTux-Origins.github.io](https://github.com/SuperTux-Origins/SuperTux-Origins.github.io):

- **Nix flake** pulls the playable **WASM** package from the game flake
  (`kurvenrausch.packages.*.kurvenrausch-wasm`) and assembles `index.html`,
  screenshots, and `play/` into a single store path
- **GitHub Pages** deploys that path via `.github/workflows/pages.yml`
- **Local preview**: `nix run .#serve`

## Layout

```
.
├── flake.nix                 # site only (WASM comes from Grumbel/kurvenrausch)
├── index.html                # landing page
├── images/                   # screenshots (from the game docs/)
├── scripts/serve.sh          # local HTTP server (no-cache headers)
└── .github/workflows/pages.yml
```

## Commands

```bash
# Build the full site (HTML + WASM under play/)
nix build
ls result/
# result/index.html  result/images/  result/play/kurvenrausch.{html,js,wasm}

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

WASM is built by the [kurvenrausch](https://github.com/Grumbel/kurvenrausch)
flake (`nix build .#kurvenrausch-wasm` there). This site only packages it.

## License

Site scaffolding: use freely.
Game binary/WASM: **GPL-3.0-or-later** (see [Grumbel/kurvenrausch](https://github.com/Grumbel/kurvenrausch)).
Screenshots under `images/` are from the game documentation.
