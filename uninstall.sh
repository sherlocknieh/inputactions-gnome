#!/usr/bin/env bash
# 卸载 inputactions-gnome 安装的内容（不卸载 dnf 依赖）
set -euo pipefail

if [ -n "${SUDO_ASKPASS:-}" ]; then
    SUDO="sudo -A"
else
    SUDO="sudo"
fi

gnome-extensions disable inputactions-overlay@local 2>/dev/null || true
"$HOME/.local/bin/inputactions-service" stop 2>/dev/null || true
pkill -f '^/usr/bin/inputactions-client$' 2>/dev/null || true
$SUDO systemctl disable --now inputactionsd 2>/dev/null || true

$SUDO rm -f /usr/bin/inputactions /usr/bin/inputactions-client /usr/bin/inputactionsd
$SUDO rm -f /usr/local/bin/inputactions-overlay
$SUDO rm -rf /usr/share/inputactions

rm -rf "$HOME/.local/share/inputactions-installer"
rm -rf "$HOME/.config/inputactions"
rm -f "$HOME/.config/autostart/inputactions-client.desktop" \
      "$HOME/.config/autostart/inputactions-tray.desktop"
rm -f "$HOME/.local/share/applications/inputactions.desktop"
rm -rf "$HOME/.local/share/gnome-shell/extensions/inputactions-overlay@local"
# 辅助扩展可能是软链（旧版安装）或真实副本（注入 shell-version 后），两种都移除
HELPER="$HOME/.local/share/gnome-shell/extensions/inputactions@inputactions.org"
if [ -e "$HELPER" ] || [ -L "$HELPER" ]; then
    rm -rf "$HELPER"
fi
rm -f "$HOME/.local/bin/inputactions-tray" "$HOME/.local/bin/inputactions-service"
rm -rf "$HOME/.local/state/inputactions-tray"
rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/inputactions-tray-"*.svg

echo "已卸载。建议注销并重新登录。"
