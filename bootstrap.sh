#!/usr/bin/env bash
# 一键安装入口：下载仓库 tarball 后执行 install.sh
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/sherlocknieh/inputactions-gnome}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $REPO_URL ..."
curl -fsSL "$REPO_URL/archive/refs/heads/main.tar.gz" |
    tar -xz -C "$TMP" --strip-components=1
bash "$TMP/install.sh"
