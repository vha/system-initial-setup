#!/usr/bin/env bash

if [ "${STRICT:-0}" -eq 1 ]; then
  set -euo pipefail
else
  set +e   # never abort
fi

log() {
  echo -e "\n==> $1"
}

KWRITE=kwriteconfig6

# Helper to run commands in strict or non-strict mode
run_cmd() {
  if [ "${STRICT:-0}" -eq 1 ]; then
    "$@"
  else
    "$@" || true
  fi
}


set_kglobal_shortcut() {
  local component="$1"
  local action="$2"
  local new_shortcut="$3"

  if [[ -z "$component" || -z "$action" || -z "$new_shortcut" ]]; then
    echo "Usage: set_kglobal_shortcut <component> <action> <shortcut>"
    return 1
  fi

  local config="$HOME/.config/kglobalshortcutsrc"

  # Read existing entry
  local current
  current=$(kreadconfig6 \
    --file "$config" \
    --group "$component" \
    --key "$action")

  # If key does not exist, abort safely
  if [[ -z "$current" ]]; then
    echo "Warning: shortcut '$action' not found in group '$component'"
    return 0
  fi

  # Split existing value into fields
  IFS=',' read -r _ alt desc <<< "$current"

  # Rebuild entry preserving other fields
  local new_value
  new_value="${new_shortcut},${alt:-},${desc:-}"

  # Write updated value
  run_cmd "$KWRITE" \
    --file "$config" \
    --group "$component" \
    --key "$action" \
    "$new_value"
}

#############################################
# Workspace behavior – sane defaults
#############################################
log "Configuring workspace behavior"

run_cmd "$KWRITE" --file kwinrc --group Windows --key FocusPolicy ClickToFocus
run_cmd "$KWRITE" --file kwinrc --group Windows --key AutoRaise false
run_cmd "$KWRITE" --file kwinrc --group Windows --key DelayFocusInterval 0

#############################################
# Disable Activities (confusing for new users)
#############################################
# log "Disabling KDE Activities"

# run_cmd "$KWRITE" --file kactivitymanagerdrc --group activities --key enabled false

#############################################
# File manager behavior (Dolphin)
#############################################
log "Configuring Dolphin defaults"

# Double-click to open
run_cmd "$KWRITE" --file kdeglobals --group KDE --key SingleClick false

# Show full path in title bar
run_cmd "$KWRITE" --file dolphinrc --group General --key ShowFullPath true

# Disable preview popups (performance & clarity)
# $KWRITE --file dolphinrc --group General --key ShowPreview false

#############################################
# Task Manager behavior
#############################################
log "Configuring task manager behavior"

run_cmd "$KWRITE" --file plasmarc --group TaskManager --key GroupingStrategy 1
run_cmd "$KWRITE" --file plasmarc --group TaskManager --key MiddleClickAction Close
run_cmd "$KWRITE" --file plasmarc --group TaskManager --key OnlyGroupWhenFull false

#############################################
# Virtual desktops – simple setup
#############################################
log "Configuring virtual desktops"

run_cmd "$KWRITE" --file kwinrc --group Desktops --key Number 2
run_cmd "$KWRITE" --file kwinrc --group Desktops --key Rows 1

#############################################
# Fonts & rendering (safe defaults)
#############################################
log "Configuring font rendering"
run_cmd "$KWRITE" --file kdeglobals --group KDE --key XftAntialias true
run_cmd "$KWRITE" --file kdeglobals --group KDE --key XftHinting true
run_cmd "$KWRITE" --file kdeglobals --group KDE --key XftHintStyle hintslight
run_cmd "$KWRITE" --file kdeglobals --group KDE --key XftSubPixel rgb

#############################################
# Power button behavior (prevent accidents)
#############################################
log "Configuring power button behavior"
run_cmd "$KWRITE" --file powerdevilrc --group General --key HandleButtonEvents true
run_cmd "$KWRITE" --file powerdevilrc --group ButtonEvents --key powerButtonAction 16

#############################################
# Notifications – less noisy
#############################################
log "Reducing notification noise"
run_cmd "$KWRITE" --file plasmanotifyrc --group Notifications --key PopupTimeout 5000
run_cmd "$KWRITE" --file plasmanotifyrc --group Notifications --key LowPriorityHistory true

#############################################
# Disable screen edge activation
#############################################
# log "Disabling screen edge actions"
# $KWRITE --file kwinrc --group ElectricBorders --key Top None
# $KWRITE --file kwinrc --group ElectricBorders --key Bottom None
# $KWRITE --file kwinrc --group ElectricBorders --key Left None
# $KWRITE --file kwinrc --group ElectricBorders --key Right None

#############################################
# Keyboard repeat rate
#############################################
log "Setting keyboard repeat rate"
run_cmd "$KWRITE" --file kcminputrc --group Keyboard --key RepeatDelay 250
run_cmd "$KWRITE" --file kcminputrc --group Keyboard --key RepeatRate 30


#############################################
# Global shortcuts
#############################################
log "Configuring global keyboard shortcuts"
set_kglobal_shortcut "kwin" "Window Fullscreen" "Meta+F"

#############################################
# Plasma extensions
#############################################
log "Installing Plasma extensions"
run_cmd kpackagetool6 --type Plasma/Wallpaper --install ./extensions/plasma-smart-video-wallpaper-reborn-v2.8.0.zip


#############################################
# Apply changes
#############################################
# log "Reloading KDE components"

# run_cmd qdbus org.kde.KWin /KWin reconfigure
# run_cmd qdbus org.kde.plasmashell /PlasmaShell refreshCurrentShell

#############################################
# Done
#############################################
log "First-login KDE configuration applied"

echo "Log out and back in to ensure all settings take effect."
