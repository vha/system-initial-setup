#!/usr/bin/env bash

if [ "${STRICT:-0}" -eq 1 ]; then
  set -euo pipefail
else
  set +e   # never abort
fi

log() {
  echo -e "\n==> $1"
}


# Helper to run commands in strict or non-strict mode
run_cmd() {
  if [ "${STRICT:-0}" -eq 1 ]; then
    "$@"
  else
    "$@" || true
  fi
}

REPO_URL="https://github.com/end-4/dots-hyprland.git"
CLONE_DIR="$HOME/src/dots-hyprland"

#############################################
# 1. Clone repo
#############################################
log "Cloning end-4 Hyprland dotfiles repository"

run_cmd git clone $REPO_URL "$CLONE_DIR"

#############################################
# 2. Run installation script
#############################################
log "Running end-4 Hyprland dotfiles installation script" 
run_cmd bash -c "yes | $CLONE_DIR/setup install"

sudo cp configs/opt/wrapped-hyprland /opt/wrapped-hyprland
sudo sed --in-place 's/^Exec\=Hyprland/Exec=\/opt\/wrapped-hyprland/g' /usr/share/wayland-sessions/hyprland.desktop
