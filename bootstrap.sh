#!/usr/bin/env bash
# Master bootstrap script to run post-install steps in strict mode

set -euo pipefail

STRICT=0

here="$(cd "$(dirname "$0")" && pwd)"

echo "Running Fedora post-install bootstrap (STRICT=${STRICT})"

echo "-> Running 01. post-install.sh"
STRICT=${STRICT} bash "${here}/01. post-install.sh"

echo "-> Running 02. install-common-apps.sh"
STRICT=${STRICT} bash "${here}/02. install-common-apps.sh"

echo "-> Running 03. kde-firsttime-config.sh"
STRICT=${STRICT} bash "${here}/03. kde-firsttime-config.sh"

echo "-> Running 04. install-hyprland-ii.sh"
STRICT=${STRICT} bash "${here}/04. install-hyprland-ii.sh"

echo "Bootstrap complete. Review output above for any errors."

echo "Tip: run with STRICT=1 to stop on errors."
