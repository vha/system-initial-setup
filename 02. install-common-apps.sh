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
flatpak_safe com.discordapp.Discord
flatpak_safe com.spotify.Client
flatpak_safe com.ktechpit.torrhunt
flatpak_safe com.transmissionbt.Transmission
flatpak_safe org.kde.krita
flatpak_safe org.libreoffice.LibreOffice
flatpak_safe com.getmailspring.Mailspring
flatpak_safe com.usebottles.bottles
flatpak_safe com.rustdesk.RustDesk
flatpak_safe org.localsend.localsend_app

#############################################
# Regular packages
#############################################
log "Installing common packages via $PKG_MGR"

# Common packages across distros
COMMON_TOOLS="git htop vim unzip fzf openssh-client ffmpeg mpv"

if [ "$PKG_MGR" = "dnf" ]; then
  # Fedora-specific
  pkg_cmd install -y $COMMON_TOOLS p7zip p7zip-plugins vim tldr vlc steam openrgb

  # Visual Studio Code
  sudo_run rpm --import https://packages.microsoft.com/keys/microsoft.asc   
  echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null   
  pkg_cmd install code

  # Tailscale
  sudo_run dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
  pkg_cmd install tailscale

  # Docker
  sudo_run dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
  sudo_run dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo_run groupadd docker
  sudo_run usermod -aG docker $USER
  sudo_run cp configs/etc/docker/daemon.json /etc/docker/daemon.json

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
    dragon
else
  # Ubuntu/Kubuntu
  pkg_cmd remove -y \
    korganizer \
    kontact \
    kmail \
    akregator \
    dragon || true
fi

#############################################
# Done
#############################################
log "Common applications installed"

echo "You can now use Discover or Flatpak for additional apps."
