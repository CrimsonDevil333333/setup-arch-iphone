#!/usr/bin/env bash
# Update code-server to the latest (or specified) release.
set -euo pipefail

TAG="${1:-latest}"
if [[ "$TAG" == "latest" ]]; then
  TAG="$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)"
  [[ -z "$TAG" ]] && TAG="v4.146.0"
fi
VER="${TAG#v}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[code-server-update] Downloading $TAG..."
curl -L -o "$WORK/code-server.tar.gz" \
  "https://github.com/coder/code-server/releases/download/${TAG}/code-server-${VER}-linux-arm64.tar.gz"

mkdir -p "$WORK/extract"
tar -xzf "$WORK/code-server.tar.gz" -C "$WORK/extract" --strip-components=1

echo "[code-server-update] Replacing installation..."
systemctl stop code-server 2>/dev/null || true
if [[ -d /opt/code-server ]]; then
  mv /opt/code-server "/opt/code-server.bak.$(date +%s)"
fi
mv "$WORK/extract" /opt/code-server
ln -sf /opt/code-server/bin/code-server /usr/local/bin/code-server

# remove old backups
rm -rf /opt/code-server.bak.* 2>/dev/null || true

echo "[code-server-update] Restarting service..."
systemctl daemon-reload 2>/dev/null || true
systemctl start code-server 2>/dev/null || true

echo "[code-server-update] Done: $(code-server --version 2>/dev/null | head -1)"