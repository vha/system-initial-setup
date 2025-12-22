#!/usr/bin/env bash

source helpers.sh

PIHOLE_DIR=/opt/pihole


setup_pyenv() {
  log "Setting up pyenv"
  if [ ! -d "$HOME/.pyenv" ]; then
    curl -fsSL https://pyenv.run | bash
  fi

  # Add to bash
  echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bash_profile
  echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bash_profile
  echo 'eval "$(pyenv init - bash)"' >> ~/.bash_profile

  # Add to fish
  fish -c "set -Ux PYENV_ROOT $HOME/.pyenv"
  fish -c "test -d $HOME/.pyenv/bin; and fish_add_path $HOME/.pyenv/bin"
  if [ ! -f ~/.config/fish/config.fish ] || ! grep -q 'pyenv init - fish' ~/.config/fish/config.fish; then
    echo 'pyenv init - fish | source' >> ~/.config/fish/config.fish
  fi
}

setup_docker() {
  if [ "$PKG_MGR" = "dnf" ]; then
    yes | sudo_run dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
  else
    # Get Docker's official GPG key 
    sudo_run install -m 0755 -d /etc/apt/keyrings
    sudo_run curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo_run chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    sudo_run tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo_run apt update
  fi
  log "Installing Docker"
  pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  sudo getent group docker >/dev/null || sudo_run groupadd docker  # create docker group if it doesn't exist, don't sudo_run getent so it actually fails if group doesn't exist
  sudo_run usermod -aG docker $USER # group membership applies after reboot
  sudo_run install -D -m 644 configs/etc/docker/daemon.json /etc/docker/daemon.json
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
  

  sudo_run systemctl try-restart NetworkManager

  # Stop and disable systemd-resolved to free up port 53
  sudo_run systemctl stop systemd-resolved
  sudo_run systemctl disable --now systemd-resolved
  # Hide to prevent it from being started by other services like NetworkManager
  sudo_run systemctl mask systemd-resolved

  sudo_run chcon -Rt container_file_t $PIHOLE_DIR # SELinux context

  sudo_run docker compose -f $PIHOLE_DIR/docker-compose.yml up -d --remove-orphans
  sudo_run systemctl restart NetworkManager

  # Verify Pi-hole setup
  log "Verifying Pi-hole setup"
  resolvectl status
  ss -tulpn | grep :53
  sudo_run docker ps --filter name=pihole
}

#############################################
# Flatpak apps
#############################################
log "Installing Flatpak applications"

flatpak_safe com.brave.Browser
# flatpak_safe com.discordapp.Discord
# flatpak_safe com.spotify.Client
# flatpak_safe com.ktechpit.torrhunt
# flatpak_safe com.transmissionbt.Transmission
# flatpak_safe org.kde.krita
# flatpak_safe org.libreoffice.LibreOffice
# flatpak_safe com.getmailspring.Mailspring
# flatpak_safe com.usebottles.bottles
# flatpak_safe com.rustdesk.RustDesk
# flatpak_safe org.localsend.localsend_app

#############################################
# Regular packages
#############################################
log "Installing packages via $PKG_MGR"

# Common packages across distros
PACKAGES="git htop unzip fzf ffmpeg mpv vlc fish openrgb steam"

if [ "$PKG_MGR" = "dnf" ]; then
  # Fedora-specific
  pkg_install $PACKAGES p7zip p7zip-plugins dnf-plugins-core rEFInd vim-enhanced tldr

  # Visual Studio Code
  sudo_run rpm --import https://packages.microsoft.com/keys/microsoft.asc   
  echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null   
  pkg_install code

  # Tailscale
  yes | sudo_run dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
  pkg_install tailscale


  # System services
  sudo_run systemctl enable --now openrgb

else
    # Visual Studio Code
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg &&
  sudo install -D -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg &&
  rm -f microsoft.gpg

  sudo_run install -D -m 644 configs/etc/apt/sources.list.d/vscode.sources /etc/apt/sources.list.d/vscode.sources

  sudo apt update &&
  pkg_install $PACKAGES ca-certificates curl wget gpg apt-transport-https p7zip p7zip-rar vlc vim plasma-framework refind code
fi


setup_pyenv
setup_docker
# setup_pihole

#############################################
# Optional: remove KDE clutter
#############################################
log "Removing optional KDE apps (email, calendar, player)"
pkg_cmd remove -y korganizer kontact kmail akregator dragon

#############################################
# Done
#############################################
log "Common applications installed"

echo "You can now use Discover or Flatpak for additional apps."
