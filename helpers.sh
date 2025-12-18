#!/usr/bin/env bash

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

flatpak_safe() {
  if [ "${STRICT:-0}" -eq 1 ]; then
    flatpak install -y flathub "$1"
  else
    flatpak install -y flathub "$1" || true
  fi
}