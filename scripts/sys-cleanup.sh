#!/usr/bin/env bash
# Clean package cache, journals, temp files, and orphaned packages.
set -uo pipefail

echo "[sys-cleanup] Cleaning package cache..."
yes | pacman -Sc >/dev/null 2>&1 || true

echo "[sys-cleanup] Vacuuming journals to 10M..."
journalctl --vacuum-size=10M >/dev/null 2>&1 || true

echo "[sys-cleanup] Removing temp files..."
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true

echo "[sys-cleanup] Removing orphaned packages..."
orphans="$(pacman -Qtdq 2>/dev/null || true)"
if [[ -n "$orphans" ]]; then
  pacman -Rns --noconfirm $orphans || true
fi

echo "[sys-cleanup] Done."