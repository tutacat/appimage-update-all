#!/bin/bash
shopt -s dotglob
# disable graphics
DISPLAY=""
WAYLAND_DISPLAY=""

cd "$HOME/Applications"
if [ "$?" -gt 0 ]; then
    echo "No ~/Applications directory." >&2
    exit 1;
fi;

updater="$(ls $HOME/Applications/appimageupdatetool*.AppImage | head)";

if [ ! -f "$updater" ]; then
    echo "Warning, missing file appimageupdatetool*.Appimage" >&2
    updater="./"*?"pdate"*".AppImage";
fi;
if [ ! -f "$updater" ]; then
    echo "And no AppImage called '*pdate*' found." >&2
    exit 254
fi;
echo "Found AppImage update tool."

"$updater" --self-update

for app in ./*.AppImage; do
    if ! [[ "$(basename "$updater")" = "$(basename "$app")" -o "$(basename "$app")" =~ '\bold\b' ]]; then
        "$updater" "$app";
    fi;
done;

