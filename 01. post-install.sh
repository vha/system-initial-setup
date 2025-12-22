#!/usr/bin/env bash

source helpers.sh

#############################################
# KDE Plasma Post Install Script
# Supports: Fedora, Kubuntu
#############################################

# Disable wifi power save
log "Disabling WiFi power save"
sudo install -D -m 644 configs/etc/NetworkManager/conf.d/wifi-powersave-off.conf /etc/NetworkManager/conf.d/wifi-powersave-off.conf
sudo systemctl restart NetworkManager
while ! systemctl is-active --quiet NetworkManager.service; do
    sleep 1
done
echo "NetworkManager has restarted successfully."   

#############################################
# System update
#############################################
log "Updating system"
if [ "$PKG_MGR" = "dnf" ]; then
  pkg_cmd upgrade --refresh -y
else
  pkg_cmd update && pkg_cmd upgrade -y
fi

#############################################
# Enable additional repositories
#############################################
if [ "$PKG_MGR" = "dnf" ]; then
  log "Enabling RPM Fusion and third party repositories"
  # pkg_install fedora-workstation-repositories
  
  FEDORA_VER=$(rpm -E %fedora)
  pkg_install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm

  sudo_run dnf config-manager setopt google-chrome.enabled=1
  sudo_run dnf config-manager setopt rpmfusion-free.enabled=1
  sudo_run dnf config-manager setopt rpmfusion-nonfree.enabled=1
  sudo_run dnf config-manager setopt rpmfusion-nonfree-steam.enabled=1
else
  log "Adding Ubuntu third-party repositories"
  sudo_run add-apt-repository -y universe multiverse restricted
  sudo_run add-apt-repository -y ppa:mozillateam/ppa
fi

#############################################
# AppStream metadata for Discover
#############################################
if [ "$PKG_MGR" = "dnf" ]; then
  log "Installing AppStream metadata for Discover"
  pkg_install rpmfusion-free-appstream-data
  pkg_install rpmfusion-nonfree-appstream-data
fi

#############################################
# Multimedia codecs
#############################################
log "Installing multimedia codecs"

if [ "$PKG_MGR" = "dnf" ]; then
  # FFmpeg full (safe swap)
  sudo_run dnf swap -y ffmpeg-free ffmpeg --allowerasing
  # Groups sometimes change names; ignore failures
  pkg_group_install multimedia
  pkg_group_install sound-and-video
  # Hardware acceleration
  pkg_install ffmpegthumbnailer gnome-desktop4 mesa-va-drivers mesa-vdpau-drivers libva-utils
else
  # Ubuntu/Kubuntu codecs
  pkg_install ubuntu-restricted-extras
  pkg_install libavcodec-extra libavformat-extra
fi

#############################################
# Flatpak + Flathub
#############################################
log "Enabling Flatpak and Flathub"

pkg_install flatpak
sudo_run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

#############################################
# NVIDIA detection (automatic, safe)
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
# QoL defaults
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
# Firewall (should already be enabled)
#############################################
log "Ensuring firewall is enabled"

sudo_run systemctl enable --now firewalld
sudo_run ufw enable

#############################################
# Backups
#############################################
log "Setting up backups"

if [ "$PKG_MGR" = "dnf" ]; then
  pkg_install snapper btrfs-assistant
  sudo_run snapper create-config /
else
  pkg_install timeshift
fi


#############################################
# Copy configs
#############################################
log "Copying configurations and scripts"
mkdir -p "$HOME/.local/bin"
cp -r configs/.local/bin/* "$HOME/.local/bin/"
cp -r configs/.config/* "$HOME/.config/"

#############################################
# Done
#############################################
log "Post-install setup complete"