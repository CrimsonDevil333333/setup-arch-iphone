#!/usr/bin/env bash
# setup-arch-iphone: one-shot developer environment setup for Arch Linux ARM
# (tested on Swipterm / iPhone). Run as root.
set -euo pipefail

# ---------- Config ----------
GIT_NAME="${GIT_NAME:-Developer}"
GIT_EMAIL="${GIT_EMAIL:-dev@arch.local}"
HOSTNAME="${HOSTNAME:-devbox}"
SWAP_SIZE="${SWAP_SIZE:-0}"          # GB; 0 disables swap
CODE_SERVER_AUTH="${CODE_SERVER_AUTH:-none}"  # none | password
CODE_SERVER_VERSION="${CODE_SERVER_VERSION:-latest}"
INSTALL_CODE_SERVER="${INSTALL_CODE_SERVER:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/configs"

# ---------- Options ----------
MODE="install"
DRY_RUN=0
INTERACTIVE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --update) MODE="update"; shift ;;
    --cleanup) MODE="cleanup"; shift ;;
    --update-code) MODE="update-code"; shift ;;
    --validate) MODE="validate"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --interactive) INTERACTIVE=1; shift ;;
    --help|-h)
      cat <<'EOF'
Usage: ./install.sh [options]
  (no args)        Full installation
  --update         Show available updates and upgrade the system
  --cleanup        Clean caches, journals, temp files, orphans
  --update-code    Update code-server to latest release
  --validate       Validate installation (tools, configs, services)
  --dry-run        Print actions without executing
  --interactive    Prompt before major steps
  --help           Show this help
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '\033[0;36m[dry-run]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

ask() {
  # ask "question" -> returns 0 (yes) unless interactive and user says no
  if [[ $INTERACTIVE -eq 1 ]]; then
    read -r -p "$1 [Y/n] " ans
    [[ -z "$ans" || "$ans" =~ ^[Yy] ]] 
  else
    return 0
  fi
}

do_update() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] pacman -Sy"
    echo "[dry-run] pacman -Qu"
    echo "[dry-run] pacman -Syu --noconfirm"
    return 0
  fi
  pacman -Sy
  echo "Available updates:"; pacman -Qu || true
  pacman -Syu --noconfirm
}
do_cleanup() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] pacman -Sc"
    echo "[dry-run] journalctl --vacuum-size=10M"
    echo "[dry-run] rm -rf /tmp/* /var/tmp/*"
    echo "[dry-run] pacman -Rns (orphans)"
    return 0
  fi
  yes | pacman -Sc >/dev/null 2>&1 || true
  journalctl --vacuum-size=10M >/dev/null 2>&1 || true
  rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
  orphans="$(pacman -Qtdq 2>/dev/null || true)"
  [[ -n "$orphans" ]] && pacman -Rns --noconfirm $orphans || true
}
do_code_update() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] bash $SCRIPT_DIR/scripts/code-server-update.sh ${2:-latest}"
    return 0
  fi
  bash "$SCRIPT_DIR/scripts/code-server-update.sh" "${2:-latest}"
}

do_validate() {
  local fail=0
  echo "=== Validation ==="
  for cmd in git node python3 zsh tmux nvim docker code-server starship; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '  [OK] %-14s %s\n' "$cmd" "$(command -v $cmd)"
    else
      printf '  [MISSING] %s\n' "$cmd"; fail=1
    fi
  done
  for f in /root/.zshrc /root/.bashrc /root/.vimrc /root/.tmux.conf /root/.config/starship.toml /root/.config/fastfetch/config.jsonc; do
    if [[ -f "$f" ]]; then printf '  [OK] %s\n' "$f"; else printf '  [MISSING] %s\n' "$f"; fail=1; fi
  done
  if systemctl is-active code-server >/dev/null 2>&1; then echo '  [OK] code-server service active'; else echo '  [WARN] code-server service not active'; fi
  if systemctl is-active docker >/dev/null 2>&1; then echo '  [OK] docker service active'; else echo '  [WARN] docker service not active'; fi
  # alias check
  if zsh -i -c 'whence -w tips 2>/dev/null | grep -q function && echo ok' 2>/dev/null | grep -q ok; then echo '  [OK] zsh functions loaded'; else echo '  [WARN] zsh functions not loaded'; fi
  if [[ $fail -eq 0 ]]; then echo "=== All core checks passed ==="; else echo "=== Some checks failed ==="; fi
  return $fail
}

if [[ "$MODE" == "update" ]]; then do_update; exit 0; fi
if [[ "$MODE" == "cleanup" ]]; then do_cleanup; exit 0; fi
if [[ "$MODE" == "update-code" ]]; then do_code_update; exit 0; fi
if [[ "$MODE" == "validate" ]]; then do_validate; exit $?; fi

log() { printf '\033[1;32m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }

banner() {
  echo -e "\033[1;36m"
  echo "  +----------------------------------+"
  echo "  |       setup-arch-iphone          |"
  echo "  |   Arch Linux ARM dev setup       |"
  echo "  +----------------------------------+"
  echo -e "\033[0m"
}
banner

if [[ $DRY_RUN -ne 1 && $EUID -ne 0 ]]; then
  err "Please run as root (sudo ./install.sh)"
  exit 1
fi

if [[ $DRY_RUN -ne 1 ]] && ! command -v pacman >/dev/null 2>&1; then
  err "pacman not found - this script targets Arch Linux"
  exit 1
fi

# ---------- Packages ----------
PACKAGES=(
  git base-devel nodejs npm python python-pip
  tmux zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions
  fzf ripgrep fd bat eza zoxide starship neovim vim nano
  jq yq unzip zip rsync wget curl
  lazygit docker podman htop btop pacman-contrib
  tree ncdu duf dust procs tldr man-db man-pages
  7zip git-delta shfmt xh gping hyperfine tokei cloc
  sudo less openssh tar
)

if [[ $DRY_RUN -eq 1 ]]; then
  echo "[dry-run] Would perform full installation:"
  echo "  - pacman -Sy"
  echo "  - install ${#PACKAGES[@]} packages: ${PACKAGES[*]}"
  echo "  - configure locale en_US.UTF-8"
  echo "  - set hostname to $HOSTNAME"
  echo "  - swap: ${SWAP_SIZE}G (0 = disabled)"
  echo "  - install shell/editor configs"
  echo "  - git identity: $GIT_NAME <$GIT_EMAIL>"
  echo "  - install code-server (if enabled) and configure auth: $CODE_SERVER_AUTH"
  echo "  - enable docker, install helper scripts"
  echo "  - generate SSH key if missing"
  echo "  - sync configs to alarm user"
  echo "  - makepkg MAKEFLAGS=-j$(nproc)"
  echo "  - clean package cache"
  exit 0
fi

log "Syncing package databases..."
pacman -Sy --noconfirm

ask "Install ${#PACKAGES[@]} packages?" || { echo "Aborted."; exit 0; }
log "Installing packages (${#PACKAGES[@]})..."
pacman -S --noconfirm --needed "${PACKAGES[@]}"

# ---------- Locale ----------
log "Configuring locale (en_US.UTF-8)..."
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
cat > /etc/locale.conf <<'EOF'
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF

# ---------- Hostname ----------
log "Setting hostname to $HOSTNAME..."
echo "$HOSTNAME" > /etc/hostname
hostname "$HOSTNAME" 2>/dev/null || true

# ---------- Swap (optional) ----------
if [[ "$SWAP_SIZE" -gt 0 ]]; then
  if [[ ! -f /swapfile ]]; then
    log "Creating ${SWAP_SIZE}G swap file..."
    fallocate -l "${SWAP_SIZE}G" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
  fi
  swapon /swapfile 2>/dev/null || true
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap defaults 0 0' >> /etc/fstab
else
  log "Swap disabled (SWAP_SIZE=0)."
  if swapon --show | grep -q /swapfile; then
    swapoff /swapfile 2>/dev/null || true
  fi
  rm -f /swapfile
  sed -i '\|/swapfile|d' /etc/fstab
fi

# ---------- Directories ----------
log "Creating developer directories..."
mkdir -p /root/dev /root/projects /root/scripts /root/.local/bin
mkdir -p /root/.config/fastfetch /root/.config/nvim /root/.config/code-server

# ---------- Shell configs ----------
log "Installing shell/editor configs..."
cp "$CONFIG_DIR/zshrc" /root/.zshrc
cp "$CONFIG_DIR/bashrc" /root/.bashrc
cp "$CONFIG_DIR/vimrc" /root/.vimrc
cp "$CONFIG_DIR/nvim_init.lua" /root/.config/nvim/init.lua
cp "$CONFIG_DIR/tmux.conf" /root/.tmux.conf
cp "$CONFIG_DIR/starship.toml" /root/.config/starship.toml
cp "$CONFIG_DIR/fastfetch_config.jsonc" /root/.config/fastfetch/config.jsonc

# gitconfig with identity
cp "$CONFIG_DIR/gitconfig" /root/.gitconfig
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

# ---------- code-server ----------
if [[ "$INSTALL_CODE_SERVER" == "1" ]] && ! ask "Install code-server (VS Code in browser)?"; then
  INSTALL_CODE_SERVER=0
fi

if [[ "$INSTALL_CODE_SERVER" == "1" ]]; then
  if [[ ! -x /opt/code-server/bin/code-server ]]; then
    log "Installing code-server (arm64)..."
    mkdir -p /opt/code-server
    if [[ "$CODE_SERVER_VERSION" == "latest" ]]; then
      TAG="$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)"
      [[ -z "$TAG" ]] && TAG="v4.146.0"
    else
      TAG="$CODE_SERVER_VERSION"
    fi
    VER="${TAG#v}"
    cd /tmp
    curl -L -o code-server.tar.gz "https://github.com/coder/code-server/releases/download/${TAG}/code-server-${VER}-linux-arm64.tar.gz"
    tar -xzf code-server.tar.gz -C /opt/code-server --strip-components=1
    rm -f code-server.tar.gz
    cd - >/dev/null
  else
    log "code-server already installed, skipping download."
  fi

  ln -sf /opt/code-server/bin/code-server /usr/local/bin/code-server

  # auth config
  if [[ "$CODE_SERVER_AUTH" == "password" ]]; then
    PW="$(openssl rand -hex 12 2>/dev/null || tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 24)"
    cat > /root/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $PW
cert: false
EOF
    log "code-server password: $PW"
  else
    cat > /root/.config/code-server/config.yaml <<'EOF'
bind-addr: 0.0.0.0:8080
auth: none
cert: false
EOF
    warn "code-server auth DISABLED (no password). Re-enable with CODE_SERVER_AUTH=password."
  fi

  cp "$CONFIG_DIR/code-server.service" /etc/systemd/system/code-server.service
  systemctl daemon-reload 2>/dev/null || true
  systemctl enable --now code-server 2>/dev/null || true
fi

# ---------- Services ----------
log "Enabling docker..."
systemctl enable --now docker 2>/dev/null || true
id alarm >/dev/null 2>&1 && usermod -aG docker alarm 2>/dev/null || true
systemctl disable pacman-init.service 2>/dev/null || true

# ---------- SSH key ----------
if [[ ! -f /root/.ssh/id_ed25519 ]]; then
  log "Generating SSH key..."
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f /root/.ssh/id_ed25519 -N "" >/dev/null
fi

# ---------- Shell for users ----------
log "Setting zsh as default shell..."
chsh -s /usr/bin/zsh root 2>/dev/null || true
if id alarm >/dev/null 2>&1; then
  chsh -s /usr/bin/zsh alarm 2>/dev/null || true
  # sync configs to alarm user
  mkdir -p /home/alarm/.config/fastfetch /home/alarm/.config/nvim
  cp /root/.zshrc /root/.bashrc /root/.vimrc /root/.tmux.conf /root/.gitconfig /home/alarm/ 2>/dev/null || true
  cp /root/.config/starship.toml /home/alarm/.config/ 2>/dev/null || true
  cp /root/.config/fastfetch/config.jsonc /home/alarm/.config/fastfetch/ 2>/dev/null || true
  cp /root/.config/nvim/init.lua /home/alarm/.config/nvim/ 2>/dev/null || true
  chown -R alarm:alarm /home/alarm 2>/dev/null || true
fi

# ---------- makepkg parallel builds ----------
if grep -q '^#MAKEFLAGS=' /etc/makepkg.conf; then
  sed -i 's/^#MAKEFLAGS=.*/MAKEFLAGS="-j'"$(nproc)"'"/' /etc/makepkg.conf
fi

# ---------- Helper scripts ----------
log "Installing helper scripts..."
install -m 0755 "$SCRIPT_DIR/scripts/sys-update.sh" /usr/local/bin/sys-update
install -m 0755 "$SCRIPT_DIR/scripts/sys-cleanup.sh" /usr/local/bin/sys-cleanup
install -m 0755 "$SCRIPT_DIR/scripts/code-server-update.sh" /usr/local/bin/code-server-update

# ---------- Cleanup ----------
log "Cleaning package cache..."
yes | pacman -Scc >/dev/null 2>&1 || true

# ---------- Summary ----------
cat <<EOF

====================================================
  Setup complete!
====================================================
  Hostname : $HOSTNAME
  Shell    : zsh (autosuggestions, syntax highlighting, starship)
  Editor   : neovim / vim
  Git      : $GIT_NAME <$GIT_EMAIL>
  code-server: http://<your-ip>:8080  (auth: $CODE_SERVER_AUTH)
  Swap     : ${SWAP_SIZE}G
  SSH key  : /root/.ssh/id_ed25519.pub

  Open a new shell to see the greeting.
  Type 'tips' (or 'help') for shortcuts.
====================================================
EOF