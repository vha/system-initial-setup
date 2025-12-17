#!/usr/bin/env bash

#############################################
# KDE Plasma Post Install Script
# Supports: Fedora, Kubuntu
# Safe for new Linux users
#############################################

if [ "${STRICT:-0}" -eq 1 ]; then
  set -euo pipefail
else
  set +e   # NEVER abort on error (default)
fi

log() {
  echo -e "\n==== $1 ====\n"
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
pkg_install() {
  if [ "${STRICT:-0}" -eq 1 ]; then
    if [ "$PKG_MGR" = "dnf" ]; then
      sudo dnf install -y "$@"
    else
      sudo apt-get install -y "$@"
    fi
  else
    if [ "$PKG_MGR" = "dnf" ]; then
      sudo dnf install -y "$@" || true
    else
      sudo apt-get install -y "$@" || true
    fi
  fi
}

pkg_group_install() {
  # Groups are dnf-only; apt uses task selection
  if [ "$PKG_MGR" = "dnf" ]; then
    if [ "${STRICT:-0}" -eq 1 ]; then
      sudo dnf group install -y "$@"
    else
    sudo dnf group install -y "$@" || true
    fi
  else
    log "Skipping group install (not supported on apt); groups: $@"
  fi
}

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
# 1. System update
#############################################
log "Updating system"
if [ "$PKG_MGR" = "dnf" ]; then
  pkg_cmd upgrade --refresh -y
else
  pkg_cmd update && pkg_cmd upgrade -y
fi

#############################################
# 2. Enable third-party repositories
#############################################
if [ "$PKG_MGR" = "dnf" ]; then
  log "Enabling Fedora third-party repositories"
  pkg_install fedora-workstation-repositories
  sudo_run dnf config-manager setopt google-chrome.enabled=1
  sudo_run dnf config-manager setopt rpmfusion-free.enabled=1
  sudo_run dnf config-manager setopt rpmfusion-nonfree.enabled=1
else
  log "Adding Ubuntu third-party repositories"
  sudo_run add-apt-repository -y universe multiverse restricted
  sudo_run add-apt-repository -y ppa:mozillateam/ppa
fi

#############################################
# 3. Enable additional multimedia repositories
#############################################
if [ "$PKG_MGR" = "dnf" ]; then
  log "Enabling RPM Fusion repositories"
  FEDORA_VER=$(rpm -E %fedora)
  pkg_cmd install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm
else
  log "Ubuntu multimedia repositories already included in universe/multiverse"
fi

#############################################
# 4. AppStream metadata for Discover
#############################################
if [ "$PKG_MGR" = "dnf" ]; then
  log "Installing AppStream metadata for Discover"
  pkg_install rpmfusion-free-appstream-data
  pkg_install rpmfusion-nonfree-appstream-data
fi

#############################################
# 5. Multimedia codecs
#############################################
log "Installing multimedia codecs"

if [ "$PKG_MGR" = "dnf" ]; then
  # FFmpeg full (safe swap)
  sudo_run dnf swap -y ffmpeg-free ffmpeg --allowerasing
  # Groups sometimes change names; ignore failures
  pkg_group_install multimedia
  pkg_group_install sound-and-video
  # Hardware acceleration
  pkg_install mesa-va-drivers mesa-vdpau-drivers libva-utils
else
  # Ubuntu/Kubuntu codecs
  pkg_install ubuntu-restricted-extras
  pkg_install libavcodec-extra libavformat-extra
fi

#############################################
# 6. Flatpak + Flathub
#############################################
log "Enabling Flatpak and Flathub"

pkg_install flatpak
sudo_run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

#############################################
# 7. KDE Discover fixes
#############################################
log "Installing KDE Discover backends"

pkg_install plasma-discover plasma-discover-flatpak 
if [ "$PKG_MGR" = "dnf" ]; then
  pkg_install plasma-discover-notifier PackageKit-Qt6
else
  pkg_install packagekit
fi

#############################################
# 8. KDE multimedia & utilities
#############################################
log "Installing KDE utilities"

pkg_install vlc kde-connect filelight ark gwenview kcalc spectacle
if [ "$PKG_MGR" = "dnf" ]; then
  pkg_install phonon-qt6-backend-vlc qt
else
  pkg_install phonon4qt6-backend-vlc qtchooser
fi

#############################################
# 9. Background updates
#############################################
log "Enabling background update notifications"

sudo_run systemctl enable --now plasma-discover-notifier.service

#############################################
# 10. NVIDIA detection (automatic, safe)
#############################################
log "Detecting NVIDIA GPU"

if lspci | grep -qi nvidia; then
  echo "NVIDIA GPU detected – installing drivers"
  if [ "$PKG_MGR" = "dnf" ]; then
    pkg_install akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda
    echo "NOTE: Secure Boot must be disabled or drivers will not load"
  else
    pkg_install nvidia-driver nvidia-utils
    echo "NOTE: Secure Boot or UEFI Secure Boot may need adjustment for driver loading"
  fi
else
  echo "No NVIDIA GPU detected – skipping"
fi

#############################################
# 11. QoL defaults
#############################################
log "Applying small quality-of-life defaults"

if [ "$PKG_MGR" = "dnf" ]; then
  # Faster dnf
  sudo_run sed -i '/^max_parallel_downloads=/d' /etc/dnf/dnf.conf
  echo "max_parallel_downloads=10" | sudo_run tee -a /etc/dnf/dnf.conf >/dev/null
else
  # Faster apt
  sudo_run sed -i '/APT::Acquire::Queue-Mode/d' /etc/apt/apt.conf.d/99custom || true
  echo 'APT::Acquire::Queue-Mode "host";' | sudo_run tee -a /etc/apt/apt.conf.d/99custom >/dev/null
fi

#############################################
# 12. Firewall (should already be enabled)
#############################################
log "Ensuring firewall is enabled"

sudo_run systemctl enable --now firewalld

#############################################
# 13. Backups
#############################################
log "Setting up backups"

if [ "$PKG_MGR" = "dnf" ]; then
  pkg_install snapper btrfs-assistant
  sudo_run snapper create-config /
else
  pkg_install timeshift
fi

#############################################
# 14. Restore x11 session support
#############################################
log "Restoring X11 session support"
if [ "$PKG_MGR" = "dnf" ]; then
  pkg_install kwin-x11 plasma-workspace-x11 xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-drv-libinput xorg-x11-xauth
else
  pkg_install kwin-x11 plasma-workspace-x11 plasma-session-x11
fi

#############################################
# 15. Copy user scripts
#############################################
log "Copying executables to ~/bin"
mkdir -p "$HOME/bin"
cp ./bin/* "$HOME/bin/"


#############################################
# Done
#############################################
log "Post-install setup complete"

echo "Recommended next steps:"
echo " - Reboot"
echo " - Open Discover and let it refresh"
echo " - Install apps via Flatpak when available"
echo " - Pair phone with KDE Connect"
