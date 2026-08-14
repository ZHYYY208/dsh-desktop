# DSH Desktop

Windows desktop app for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`).
It bundles a standalone Node.js runtime + the published `@deepseek-ai/dsh` CLI, boots the `dsh web`
server locally, and shows it in an Electron window.

## Build locally

Requirements: Node.js 22+ on PATH (used to run the build tooling only).

```powershell
npm install          # installs electron + electron-builder
npm run dist         # prepares runtime + builds the NSIS installer
```

Output installer: `dist/DSH Desktop-Setup-1.0.0.exe`

Steps that `npm run dist` runs:

1. `scripts/setup-node-runtime.cjs` — downloads and extracts the standalone Node 24.19.0 (if missing) into `node-runtime/`.
2. `scripts/prepare-runtime.cjs` — runs `npm install @deepseek-ai/dsh` inside `runtime/` using the bundled Node.
3. `electron-builder --win nsis` — packages the Electron shell + both runtimes into a `.exe` installer.

At runtime the app spawns `<resources>/node-runtime/node.exe <resources>/runtime/node_modules/@deepseek-ai/dsh/lib/bin.js web --port 0`,
parses the printed URL, and loads it in the Electron window.

## Publish to GitHub Releases

1. Create a GitHub repo and push:

   ```powershell
   git init
   git add .
   git commit -m "DSH Desktop app"
   git branch -M main
   git remote add origin https://github.com/<you>/dsh-desktop.git
   git push -u origin main
   ```

2. The included workflow `.github/workflows/build.yml` builds the installer on Windows:
   - manually via **Actions → build-installer → Run workflow**, or
   - automatically on a version tag: `git tag v1.0.0 && git push origin v1.0.0`

   The `.exe` is uploaded as an artifact, and attached to the Release for tagged builds.

## Notes

- `runtime/` and `node-runtime/` are regenerated and not committed to git.
- The app is unsigned; Windows SmartScreen may show a warning on first run (choose "More info → Run anyway").
