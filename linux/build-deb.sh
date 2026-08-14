#!/usr/bin/env bash
#
# Build a Debian (.deb) package of the DSH Desktop app for Ubuntu Linux.
#
# Mirrors the Windows build: the dsh CLI is installed from the npm registry
# (`@deepseek-ai/dsh`) using a bundled standalone Node.js runtime, so end users
# need nothing installed (no Node.js, no pnpm).
#
# Prerequisites: curl, tar, xz, python3, dpkg-deb.
#
# Usage:
#   linux/build-deb.sh [options]
#
# Options:
#   --version V         dsh npm version (default: 0.1.0-rc.6)
#   --node-version V    bundled Node.js version (default: 24.19.0)
#   --node-tarball FILE use a pre-downloaded node-v*-linux-<arch>.tar.xz
#   --arch ARCH         Debian arch: amd64|arm64 (default: dpkg --print-architecture)
#   --maintainer STRING Debian Maintainer field
#   --out DIR           output directory (default: linux/dist)
#
# Output: <out>/dsh-desktop_<version>_<arch>.deb

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DSH_VERSION="0.1.0-rc.6"
NODE_VERSION="24.19.0"
ARCH=""
MAINTAINER="DSH Desktop Maintainers <maintainers@dsh-desktop>"
OUT_DIR=""
NODE_TARBALL=""

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# //; s/^#$//' >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) DSH_VERSION="$2"; shift ;;
    --node-version) NODE_VERSION="$2"; shift ;;
    --node-tarball) NODE_TARBALL="$2"; shift ;;
    --arch) ARCH="$2"; shift ;;
    --maintainer) MAINTAINER="$2"; shift ;;
    --out) OUT_DIR="$2"; shift ;;
    -h|--help) usage ;;
    *) echo "build-deb: unknown option: $1" >&2; usage ;;
  esac
  shift
done

log() { printf 'build-deb: %s\n' "$*"; }
die() { printf 'build-deb: error: %s\n' "$*" >&2; exit 1; }

for tool in curl tar xz dpkg-deb python3; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done

cd "$ROOT"

# --- version / architecture ----------------------------------------------------
DEB_VERSION="$(printf '%s' "$DSH_VERSION" | sed 's/-rc\./~rc./g; s/-/~/g')"
[ -n "$DEB_VERSION" ] || die "could not derive a Debian version from $DSH_VERSION"

if [ -z "$ARCH" ]; then
  ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
fi
if [ -z "$ARCH" ]; then
  case "$(uname -m)" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) die "unable to determine architecture (uname -m = $(uname -m)); pass --arch" ;;
  esac
fi
case "$ARCH" in
  amd64) NODE_ARCH="x64" ;;
  arm64) NODE_ARCH="arm64" ;;
  *) die "unsupported Debian architecture for the Node.js bundle: $ARCH" ;;
esac

[ -n "$OUT_DIR" ] || OUT_DIR="linux/dist"
mkdir -p "$(dirname "$OUT_DIR")"
OUT_DIR="$(cd "$(dirname "$OUT_DIR")" && pwd)/$(basename "$OUT_DIR")"
mkdir -p "$OUT_DIR"
CACHE_DIR="$OUT_DIR/.cache"
mkdir -p "$CACHE_DIR"

NODE_RUNTIME_DIR="$SCRIPT_DIR/node-runtime"
RUNTIME_DIR="$SCRIPT_DIR/runtime"
NODE_BINARY="$NODE_RUNTIME_DIR/bin/node"

log "building dsh-desktop_${DEB_VERSION}_${ARCH}.deb (dsh ${DSH_VERSION})"

# --- bundled Node.js -------------------------------------------------------------
if [ -n "$NODE_TARBALL" ]; then
  log "extracting Node.js from $NODE_TARBALL"
  rm -rf "$NODE_RUNTIME_DIR"
  mkdir -p "$NODE_RUNTIME_DIR"
  tar -xJf "$NODE_TARBALL" -C "$NODE_RUNTIME_DIR" --strip-components=1
else
  NODE_TARBALL="$CACHE_DIR/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
  NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
  if [ ! -f "$NODE_TARBALL" ]; then
    log "downloading $NODE_URL"
    curl -fsSL --retry 3 -o "$NODE_TARBALL" "$NODE_URL" || {
      rm -f "$NODE_TARBALL"
      die "failed to download Node.js from $NODE_URL"
    }
  else
    log "using cached Node.js tarball $NODE_TARBALL"
  fi
  rm -rf "$NODE_RUNTIME_DIR"
  mkdir -p "$NODE_RUNTIME_DIR"
  tar -xJf "$NODE_TARBALL" -C "$NODE_RUNTIME_DIR" --strip-components=1
fi
[ -x "$NODE_BINARY" ] || die "bundled Node.js missing node binary after extraction"
BUNDLED_NPM="$NODE_RUNTIME_DIR/lib/node_modules/npm/bin/npm-cli.js"
[ -f "$BUNDLED_NPM" ] || die "bundled Node.js missing npm at $BUNDLED_NPM"
log "bundled Node.js $("$NODE_BINARY" --version)"

# --- install dsh from the npm registry -------------------------------------------
log "installing @deepseek-ai/dsh@${DSH_VERSION} with the bundled npm"
rm -rf "$RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR"

python3 - "$RUNTIME_DIR/package.json" "$DSH_VERSION" <<'PYEOF'
import json, sys

out, version = sys.argv[1], sys.argv[2]
payload = {
    "name": "dsh-desktop-runtime",
    "version": version,
    "private": True,
    "type": "commonjs",
    "dependencies": {
        "@deepseek-ai/dsh": version,
    },
    "allowScripts": {
        "@deepseek-ai/dsh-subprocess-local@0.1.0-rc.6": True,
        "koffi@3.1.5": True,
        "node-pty@1.1.0": True,
        "protobufjs@7.6.5": True,
        "@google/genai@1.52.0": True,
    },
}
with open(out, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PYEOF

(
  cd "$RUNTIME_DIR"
  # The bundled node's bin goes on PATH so dependency install scripts
  # (`node ...`) resolve. Optional dependencies stay enabled: koffi's native
  # module and node-pty's prebuilds ship as optional platform packages and are
  # required at runtime.
  export PATH="$NODE_RUNTIME_DIR/bin:$PATH"
  mkdir -p "$ROOT/linux/.home"
  HOME="$ROOT/linux/.home" NPM_CONFIG_CACHE="$CACHE_DIR/npm-cache" \
    env -u NODE_OPTIONS -u NODE_PATH -u npm_config_user_agent -u NPM_CONFIG_USER_AGENT \
    "$NODE_BINARY" "$BUNDLED_NPM" install \
    --no-audit --no-fund --package-lock=false \
    >/dev/null
)

CLI_ENTRY="$RUNTIME_DIR/node_modules/@deepseek-ai/dsh/lib/bin.js"
[ -f "$CLI_ENTRY" ] || die "dsh binary not found after npm install"
log "installed dsh reports version: $("$NODE_BINARY" "$CLI_ENTRY" --version)"

# --- assemble the package root ---------------------------------------------------
STAGE_DIR="$OUT_DIR/.stage"
rm -rf "$STAGE_DIR"
APP_ROOT="$STAGE_DIR/opt/dsh-desktop"
mkdir -p "$APP_ROOT/node" "$APP_ROOT/app"
cp -a "$NODE_RUNTIME_DIR"/. "$APP_ROOT/node/"
cp -a "$RUNTIME_DIR/node_modules" "$APP_ROOT/app/node_modules"
cp -a "$RUNTIME_DIR/package.json" "$APP_ROOT/app/package.json"

INSTALLED_SIZE="$(du -sk "$STAGE_DIR" | awk '{print $1}')"

# --- binaries and desktop integration ---------------------------------------------
install -d "$STAGE_DIR/usr/bin"
install -m 0755 "$SCRIPT_DIR/dsh" "$STAGE_DIR/usr/bin/dsh"
install -m 0755 "$SCRIPT_DIR/dsh-desktop" "$STAGE_DIR/usr/bin/dsh-desktop"

install -d "$STAGE_DIR/usr/share/applications"
install -m 0644 "$SCRIPT_DIR/dsh-desktop.desktop" \
  "$STAGE_DIR/usr/share/applications/dsh-desktop.desktop"

if [ -d "$ROOT/build/icons" ]; then
  for size in 512 256 128 64 48 32; do
    icon="$ROOT/build/icons/${size}.png"
    [ -f "$icon" ] || continue
    install -d "$STAGE_DIR/usr/share/icons/hicolor/${size}x${size}/apps"
    install -m 0644 "$icon" \
      "$STAGE_DIR/usr/share/icons/hicolor/${size}x${size}/apps/dsh-desktop.png"
  done
elif [ -f "$ROOT/build/icon.png" ]; then
  install -d "$STAGE_DIR/usr/share/icons/hicolor/512x512/apps"
  install -m 0644 "$ROOT/build/icon.png" \
    "$STAGE_DIR/usr/share/icons/hicolor/512x512/apps/dsh-desktop.png"
fi

install -d "$STAGE_DIR/usr/share/doc/dsh-desktop"
cat > "$STAGE_DIR/usr/share/doc/dsh-desktop/copyright" <<EOF
Upstream-Name: dsh-desktop
Source: https://github.com/ZHYYY208/dsh-desktop

Files: *
Copyright: 2026 dsh-desktop contributors
License: MIT

License: MIT
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

DeepSeek Harness (dsh) is Copyright DeepSeek AI and licensed under MIT.
EOF

if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$ROOT" log --oneline --no-decorate -100 | gzip -9 -c > \
    "$STAGE_DIR/usr/share/doc/dsh-desktop/changelog.gz"
else
  printf 'dsh-desktop %s\n' "$DSH_VERSION" | gzip -9 -c > \
    "$STAGE_DIR/usr/share/doc/dsh-desktop/changelog.gz"
fi

# --- Debian control files -----------------------------------------------------------
install -d "$STAGE_DIR/DEBIAN"
cat > "$STAGE_DIR/DEBIAN/control" <<EOF
Package: dsh-desktop
Version: ${DEB_VERSION}
Section: devel
Priority: optional
Architecture: ${ARCH}
Maintainer: ${MAINTAINER}
Installed-Size: ${INSTALLED_SIZE}
Depends: libc6 (>= 2.31)
Homepage: https://github.com/ZHYYY208/dsh-desktop
Description: DSH Desktop - DeepSeek Harness desktop application
 An out-of-the-box local AI assistant desktop app for Ubuntu Linux.
 Bundles the DeepSeek Harness (dsh) CLI with its own Node.js runtime and
 ships a desktop launcher that boots the Web UI and opens it in the default
 browser (served at http://127.0.0.1:3080).
EOF

install -m 0755 "$SCRIPT_DIR/postinst" "$STAGE_DIR/DEBIAN/postinst"

# --- build the .deb ------------------------------------------------------------------
DEB_FILE="$OUT_DIR/dsh-desktop_${DEB_VERSION}_${ARCH}.deb"
rm -f "$DEB_FILE"
dpkg-deb --build --root-owner-group "$STAGE_DIR" "$DEB_FILE"
rm -rf "$STAGE_DIR"

log "done: $DEB_FILE ($(du -h "$DEB_FILE" | awk '{print $1}'))"
