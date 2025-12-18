#!/usr/bin/env bash

source helpers.sh

REPO_URL="https://github.com/vha/dots-hyprland.git"
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
