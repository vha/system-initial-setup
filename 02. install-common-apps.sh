#!/usr/bin/env bash

if [ "${STRICT:-0}" -eq 1 ]; then
  set -euo pipefail
else
  set +e
fi

log() {
  echo -e "\n==== $1 ===="
}

#############################################
# OS Detection
#############################################
if grep -q '^ID=fedora$' /etc/os-release 2>/dev/null; then
  OS="fedora"
  PKG_MGR="dnf"
elif grep -q '^ID=ubuntu$' /etc/os-release 2>/dev/null; then
  OS="ubuntu"
  PKG_MGR="apt"
else
  echo "ERROR: Unsupported distribution. Supported: Fedora, Ubuntu/Kubuntu"
  exit 1
fi

log "Detected OS: $OS (package manager: $PKG_MGR)"

#############################################
# Distro-agnostic package helpers
#############################################
pkg_cmd() {
  if [ "${STRICT:-0}" -eq 1 ]; then
    if [ "$PKG_MGR" = "dnf" ]; then
      sudo dnf "$@"
    else
      sudo apt-get "$@"
    fi
  else
    if [ "$PKG_MGR" = "dnf" ]; then
      sudo dnf "$@" || true
    else
      sudo apt-get "$@" || true
    fi
  fi
}

sudo_run() {
  if [ "${STRICT:-0}" -eq 1 ]; then
    sudo "$@"
  else
    sudo "$@" || true
  fi
}

#############################################
# Flatpak apps (preferred for GUI)
#############################################
log "Installing common Flatpak applications"

flatpak_safe() {
  if [ "${STRICT:-0}" -eq 1 ]; then
    flatpak install -y flathub "$1"
  else
    flatpak install -y flathub "$1" || true
  fi
}

flatpak_safe com.brave.Browser
flatpak_safe com.visualstudio.code
flatpak_safe com.discordapp.Discord
flatpak_safe com.spotify.Client
flatpak_safe com.ktechpit.torrhunt
flatpak_safe com.transmissionbt.Transmission
flatpak_safe org.kde.krita
flatpak_safe org.libreoffice.LibreOffice
flatpak_safe com.getmailspring.Mailspring
flatpak_safe com.usebottles.bottles

#############################################
# CLI / system tools (distro-specific)
#############################################
log "Installing CLI and system utilities"

# Common packages across distros
COMMON_TOOLS="git htop vim unzip fzf openssh-client ffmpeg mpv"

if [ "$PKG_MGR" = "dnf" ]; then
  # Fedora-specific
  pkg_cmd install -y $COMMON_TOOLS p7zip p7zip-plugins vim vlc steam
else
  # Ubuntu/Kubuntu-specific
  pkg_cmd install -y $COMMON_TOOLS p7zip p7zip-rar vlc plasma-framework
fi


#############################################
# Optional: remove KDE clutter
#############################################
log "Removing optional KDE apps (email, calendar, player)"

if [ "$PKG_MGR" = "dnf" ]; then
  pkg_cmd remove -y \
    korganizer \
    kontact \
    kmail \
    akregator \
    dragonplayer
else
  # Ubuntu/Kubuntu
  pkg_cmd remove -y \
    korganizer \
    kontact \
    kmail \
    akregator \
    dragonplayer || true
fi

#############################################
# Done
#############################################
log "Common applications installed"

echo "You can now use Discover or Flatpak for additional apps."
