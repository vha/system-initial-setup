#!/usr/bin/env bash
set -euo pipefail

IMAGE_DESKTOP="org.kde.gwenview.desktop"
VIDEO_DESKTOP="vlc.desktop"

get_mime_types() {
  local desktop_file="$1"

  # Resolve desktop file path via XDG spec
  local file
  file="$(grep -Rl "^Name=.*" \
    /usr/share/applications \
    ~/.local/share/applications \
    | grep "/$desktop_file$" \
    | head -n1)"

  if [[ -z "$file" ]]; then
    echo "Error: $desktop_file not found" >&2
    exit 1
  fi

  grep -E '^MimeType=' "$file" \
    | cut -d= -f2 \
    | tr ';' '\n' \
    | sed '/^$/d'
}

echo "Mapping Gwenview supported image MIME types..."
get_mime_types "$IMAGE_DESKTOP" \
  | grep '^image/' \
  | while read -r mime; do
      xdg-mime default "$IMAGE_DESKTOP" "$mime"
    done

echo "Mapping VLC supported video MIME types..."
get_mime_types "$VIDEO_DESKTOP" \
  | grep '^video/' \
  | while read -r mime; do
      xdg-mime default "$VIDEO_DESKTOP" "$mime"
    done

echo "Done."
