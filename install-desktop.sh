#!/usr/bin/env bash
#
# install-desktop.sh - install BeamMP .desktop entries for the current user.
#
# Creates an application-menu entry and (if a Desktop folder exists) a Desktop
# shortcut, both pointing at $HOME/beammp-launcher/BeamMP-Launcher. Safe to
# re-run.
#
# Override the install directory with BEAMMP_DIR=/path/to/dir.

set -euo pipefail

INSTALL_DIR="${BEAMMP_DIR:-$HOME/beammp-launcher}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/desktop/beammp.desktop.in"

if [ ! -x "$INSTALL_DIR/BeamMP-Launcher" ]; then
    echo "warning: $INSTALL_DIR/BeamMP-Launcher not found - run update-beammp.sh first" >&2
fi

tmp="$(mktemp)"
sed "s|__INSTALL_DIR__|$INSTALL_DIR|g" "$TEMPLATE" > "$tmp"

# Application menu entry.
apps="$HOME/.local/share/applications"
mkdir -p "$apps"
install -m 0644 "$tmp" "$apps/BeamMP.desktop"

# Desktop shortcut.
desk="$HOME/Desktop"
if [ -d "$desk" ]; then
    install -m 0755 "$tmp" "$desk/BeamMP.desktop"
    # Mark as trusted on GNOME so it launches with a single click.
    if command -v gio >/dev/null 2>&1; then
        gio set "$desk/BeamMP.desktop" metadata::trusted true 2>/dev/null || true
    fi
fi

rm -f "$tmp"
command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "$apps" 2>/dev/null || true

echo "Installed BeamMP desktop entries for $INSTALL_DIR"
