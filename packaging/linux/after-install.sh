#!/bin/sh
# Runs as root after the .deb is installed (electron-builder deb.afterInstall).
set -e

APP_BIN="/opt/DSH Desktop/dsh-desktop"
WRAPPER="/usr/bin/dsh-desktop"

# Chromium's SUID sandbox helper cannot exec a path containing a space (the
# app installs under "/opt/DSH Desktop"), so the zygote fatally aborts at
# startup. Install a wrapper that passes --no-sandbox, and point the desktop
# entry at it, so both the app menu and `dsh-desktop` work.
if [ -x "$APP_BIN" ]; then
  cat > "$WRAPPER" <<'EOF'
#!/bin/sh
exec "/opt/DSH Desktop/dsh-desktop" --no-sandbox "$@"
EOF
  chmod 0755 "$WRAPPER"
fi

desktop="/usr/share/applications/dsh-desktop.desktop"
if [ -f "$desktop" ]; then
  sed -i 's|^Exec=.*|Exec=/usr/bin/dsh-desktop %U|' "$desktop"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

exit 0
