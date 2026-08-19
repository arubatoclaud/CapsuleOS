#!/usr/bin/env bash
set -euo pipefail

THEME_NAME="capsule"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_DIR="/usr/share/sddm/themes/${THEME_NAME}"
CONF_DIR="/etc/sddm.conf.d"

echo ":: Installing SDDM theme '${THEME_NAME}'"
echo "   source : ${SRC_DIR}"
echo "   target : ${DEST_DIR}"

echo ":: Copying theme files (sudo)"
sudo install -d -m 0755 "${DEST_DIR}/current"
sudo install -m 0644 "${SRC_DIR}/Main.qml" "${SRC_DIR}/GlyphIcon.qml" \
    "${SRC_DIR}/metadata.desktop" "${SRC_DIR}/theme.conf" "${DEST_DIR}/"

echo ":: Installing X11 setup script (portrait-native panel rotation)"
sudo install -D -m 0755 "${SRC_DIR}/capsule-xsetup.sh" /usr/share/sddm/scripts/capsule-xsetup.sh

echo ":: Selecting theme (sudo)"
sudo install -d -m 0755 "${CONF_DIR}"
sudo tee "${CONF_DIR}/capsule.conf" >/dev/null <<EOF
[Theme]
Current=${THEME_NAME}

[X11]
DisplaySetupScript=/usr/share/sddm/scripts/capsule-xsetup.sh
EOF

echo ":: Done. Theme installed and selected."
echo "   The live wallpaper + palette land in ${DEST_DIR}/current on the next"
echo "   wallpaper change (sddm_sync in hypr/scripts/wallpaper.sh); until then"
echo "   the greeter uses the static fallback colors from theme.conf."
echo "   Test without logging out:"
echo "   sddm-greeter-qt6 --test-mode --theme ${DEST_DIR}"
