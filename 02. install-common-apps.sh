#!/usr/bin/env bash

source helpers.sh

PIHOLE_DIR=/opt/pihole


setup_docker() {
  yes | sudo_run dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
  pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo getent group docker >/dev/null || sudo_run groupadd docker  # create docker group if it doesn't exist, don't sudo_run getent so it actually fails if group doesn't exist
  sudo_run usermod -aG docker $USER # group membership applies after reboot
  sudo_run install -m 644 configs/etc/docker/daemon.json /etc/docker/daemon.json
  sudo_run systemctl enable --now docker
}

setup_pihole() {
  log "Setting up Pi-hole via Docker"
  sudo_run mkdir -p $PIHOLE_DIR #/{etc-pihole,etc-dnsmasq.d}
  sudo_run chown -R 1000:1000 $PIHOLE_DIR
  cp configs/opt/pihole/docker-compose.yml $PIHOLE_DIR/docker-compose.yml

  sudo_run install -d /etc/systemd/resolved.conf.d #  ensure dir exists
  sudo_run install -d /etc/NetworkManager/conf.d
  sudo_run install -m 644 configs/etc/systemd/resolved.conf.d/* /etc/systemd/resolved.conf.d/
  sudo_run install -m 644 configs/etc/NetworkManager/conf.d/* /etc/NetworkManager/conf.d/
  sudo_run ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf # point resolv.conf to systemd-resolved


  sudo_run systemctl try-restart NetworkManager
  sudo_run systemctl try-restart systemd-resolved
  sudo_run chcon -Rt container_file_t $PIHOLE_DIR # SELinux context

  sudo_run docker compose -f $PIHOLE_DIR/docker-compose.yml up -d --remove-orphans
}

#############################################
# Flatpak apps (preferred for GUI)
#############################################
log "Installing common Flatpak applications"

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
  pkg_install $COMMON_TOOLS p7zip p7zip-plugins dnf-plugins-core vim-enhanced tldr vlc steam openrgb

  # Visual Studio Code
  sudo_run rpm --import https://packages.microsoft.com/keys/microsoft.asc   
  echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null   
  pkg_install code

  # Tailscale
  yes | sudo_run dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
  pkg_install tailscale

  # Docker
  setup_docker

  # Pi-hole
  setup_pihole

  # Verify Pi-hole setup
  log "Verifying Pi-hole setup"
  resolvectl status
  ss -tulpn | grep :53
  docker ps --filter name=pihole

else
  # Ubuntu/Kubuntu-specific
  pkg_install $COMMON_TOOLS p7zip p7zip-rar vlc plasma-framework
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
