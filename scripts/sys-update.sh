#!/usr/bin/env bash
# Show available updates and upgrade the system automatically.
set -euo pipefail

echo "[sys-update] Syncing package databases..."
pacman -Sy

echo "[sys-update] Available updates:"
pacman -Qu || true

echo "[sys-update] Upgrading..."
pacman -Syu --noconfirm

echo "[sys-update] Done."