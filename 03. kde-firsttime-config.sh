#!/usr/bin/env bash

source helpers.sh

KWRITE=kwriteconfig6


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
  "$KWRITE" \
    --file "$config" \
    --group "$component" \
    --key "$action" \
    "$new_value"
}


#############################################
# Restore x11 session support
#############################################
log "Restoring X11 session support"
if [ "$PKG_MGR" = "dnf" ]; then
  pkg_install kwin-x11 plasma-workspace-x11 xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-drv-libinput xorg-x11-xauth
else
  pkg_install kwin-x11 plasma-session-x11
fi

#############################################
# KDE Discover fixes
#############################################
log "Installing KDE Discover backends"

pkg_install plasma-discover 
if [ "$PKG_MGR" = "dnf" ]; then
  pkg_install PackageKit-Qt6 plasma-discover-flatpak 
else
  pkg_install packagekit
fi

#############################################
# KDE multimedia & utilities
#############################################
log "Installing KDE utilities"

pkg_install filelight ark gwenview
if [ "$PKG_MGR" = "dnf" ]; then
  pkg_install phonon-qt6-backend-vlc qt kde-connect
else
  pkg_install phonon4qt6-backend-vlc qtchooser kdeconnect
fi

#############################################
# KDE configuration tweaks
#############################################
log "Applying KDE configuration tweaks"

log "Configuring workspace behavior"
"$KWRITE" --file kwinrc --group Windows --key FocusPolicy ClickToFocus
"$KWRITE" --file kwinrc --group Windows --key AutoRaise false
"$KWRITE" --file kwinrc --group Windows --key DelayFocusInterval 0

# log "Disabling KDE Activities"
# "$KWRITE" --file kactivitymanagerdrc --group activities --key enabled false

log "Configuring Dolphin defaults"
"$KWRITE" --file kdeglobals --group KDE --key SingleClick false
"$KWRITE" --file dolphinrc --group General --key ShowFullPath true

# Disable preview popups (performance & clarity)
# $KWRITE --file dolphinrc --group General --key ShowPreview false

log "Configuring task manager behavior"
"$KWRITE" --file plasmarc --group TaskManager --key GroupingStrategy 1
"$KWRITE" --file plasmarc --group TaskManager --key MiddleClickAction Close
"$KWRITE" --file plasmarc --group TaskManager --key OnlyGroupWhenFull false

log "Configuring virtual desktops"
"$KWRITE" --file kwinrc --group Desktops --key Number 2
"$KWRITE" --file kwinrc --group Desktops --key Rows 1

log "Configuring font rendering"
"$KWRITE" --file kdeglobals --group KDE --key XftAntialias true
"$KWRITE" --file kdeglobals --group KDE --key XftHinting true
"$KWRITE" --file kdeglobals --group KDE --key XftHintStyle hintslight
"$KWRITE" --file kdeglobals --group KDE --key XftSubPixel rgb

log "Configuring power button behavior"
"$KWRITE" --file powerdevilrc --group General --key HandleButtonEvents true
"$KWRITE" --file powerdevilrc --group ButtonEvents --key powerButtonAction 16

log "Reducing notification noise"
"$KWRITE" --file plasmanotifyrc --group Notifications --key PopupTimeout 5000
"$KWRITE" --file plasmanotifyrc --group Notifications --key LowPriorityHistory true

# log "Disabling screen edge actions"
# $KWRITE --file kwinrc --group ElectricBorders --key Top None
# $KWRITE --file kwinrc --group ElectricBorders --key Bottom None
# $KWRITE --file kwinrc --group ElectricBorders --key Left None
# $KWRITE --file kwinrc --group ElectricBorders --key Right None

log "Setting keyboard repeat rate"
"$KWRITE" --file kcminputrc --group Keyboard --key RepeatDelay 250
"$KWRITE" --file kcminputrc --group Keyboard --key RepeatRate 30

log "Configuring global keyboard shortcuts"
set_kglobal_shortcut "kwin" "Window Fullscreen" "Meta+F"

log "Installing Plasma extensions"
kpackagetool6 --type Plasma/Wallpaper --install ./extensions/plasma-smart-video-wallpaper-reborn-v2.8.0.zip

log "Applying Plasma and SDDM themes"
sudo_run mkdir -p "/usr/share/plasma/look-and-feel/"
sudo_run mkdir -p "/usr/share/plasma/desktoptheme/"
sudo_run mkdir -p "/usr/share/sddm/themes/"
sudo_run mkdir -p "/etc/sddm.conf.d/"

sudo_run cp -r configs/usr/share/plasma/look-and-feel/* /usr/share/plasma/look-and-feel/
sudo_run cp -r configs/usr/share/sddm/themes/* /usr/share/sddm/themes/
sudo_run cp -r configs/usr/share/plasma/desktoptheme/* /usr/share/plasma/desktoptheme/
sudo_run cp -r configs/usr/share/wallpapers/* /usr/share/wallpapers/
sudo_run cp -r configs/etc/sddm.conf.d/kde_settings.conf /etc/sddm.conf.d/kde_settings.conf

lookandfeeltool -a org.manjaro.breath-light.desktop
# kwriteconfig6 --file ksplashrc --group KSplash --key Theme Fedora-Minimalistic
# Apply SDDM theme
# sudo_run sed -i 's/^Current=.*$/Current=breath/g' /etc/sddm.conf.d/kde_settings.conf

# log "Reloading KDE components"

# qdbus org.kde.KWin /KWin reconfigure
# qdbus org.kde.plasmashell /PlasmaShell refreshCurrentShell

#############################################
# Done
#############################################
log "First-login KDE configuration applied"

echo "Log out and back in to ensure all settings take effect."
