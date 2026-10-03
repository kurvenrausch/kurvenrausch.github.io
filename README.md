# Kurvenrausch website

Static site for [Kurvenrausch](https://github.com/Grumbel/kurvenrausch), structured
like [SuperTux-Origins.github.io](https://github.com/SuperTux-Origins/SuperTux-Origins.github.io):

- **Nix flake** pulls the playable **WASM** package and the downloadable
  ports (Windows 64/32-bit zips, the Android APK, the R36S PortMaster zip)
  from the game flake and assembles `index.html`, screenshots, `play/` and
  `downloads/` into a single store path; building the site builds them all
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
# result/downloads/kurvenrausch-win64.zip  kurvenrausch-win32.zip  kurvenrausch.apk
# result/downloads/r36s/kurvenrausch.zip

# Build against a local checkout of the game instead of GitHub:
nix build --override-input kurvenrausch git+file://$HOME/projects/kurvenrausch/kurvenrausch.git

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

The WASM build and the ports are built by the
[kurvenrausch](https://github.com/Grumbel/kurvenrausch) flake; this site only
packages them. The site follows the game revision in `flake.lock`: after
pushing the game, run `nix flake update kurvenrausch` here and push to
rebuild everything. The build runs on x86_64-linux only (the Android SDK).

## License

Site scaffolding: use freely.
Game binary/WASM: **GPL-3.0-or-later** (see [Grumbel/kurvenrausch](https://github.com/Grumbel/kurvenrausch)).
Screenshots under `images/` are from the game documentation.
