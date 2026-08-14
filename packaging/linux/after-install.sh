#!/bin/sh
# Runs as root after the .deb is installed (electron-builder deb.afterInstall).
set -e

# Chromium's SUID sandbox requires a root-owned setuid chrome-sandbox on
# systems where unprivileged user namespaces are restricted (Ubuntu 24.04+
# apparmor_restrict_unprivileged_userns=1). Without it the app aborts at
# startup with "SUID sandbox helper ... not configured correctly".
for dir in "/opt/DSH Desktop" "/opt/dsh-desktop"; do
  sandbox="$dir/chrome-sandbox"
  if [ -x "$sandbox" ]; then
    chown root:root "$sandbox" 2>/dev/null || true
    chmod 4755 "$sandbox" 2>/dev/null || true
    break
  fi
done

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

# Belt-and-suspenders: guarantee the desktop entry also disables the sandbox
# (see electron/main.cjs), in case the install path keeps a space.
desktop="/usr/share/applications/dsh-desktop.desktop"
if [ -f "$desktop" ] && ! grep -q -- "--no-sandbox" "$desktop"; then
  sed -i 's/^Exec=\(.*\)/Exec=\1 --no-sandbox/' "$desktop" 2>/dev/null || true
fi

exit 0
