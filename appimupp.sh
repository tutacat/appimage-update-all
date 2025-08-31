#!/usr/bin/bash

function Help() {
  echo >&2 -e 'usage: "$1" [option(s)] [file(s)]'
  echo '  -h --help        Show this help.'
  echo '  -O --overwrite   Overwrite the original AppImage [overwrite=y]'
  echo '  file(s)          Update this file or files.'
  echo '  --updater-path   Set the path for appimage update tool [updater=...]'$'\n\n''  AppImageUpdate is provided by AppImage-Community and TheAssassin under the MIT License'
  echo '  https://github.com/AppImageCommunity/AppImageUpdate.git/'
}

shopt -s nocaseglob
shopt -s dotglob
SOURCED="$(echo "$BASH_SOURCE"|grep -o '^.*/')""
source "$SOURCED/appimup.conf"
export LC_COLLATE=C
if [ -z "$updater" ]; then
    updater="`ls "$HOME/Applications"/*{appimageupdatetool,AppImageUpdate}*.appimage | head -1`"
fi
Done=""

while "$1"; do
    if [ "$Done" != "y" ]; then
        case "$1" in
          --)
            Done=y;;
          --*)
              ###
              case "$1" in
                --help)
                  Help;
                  exit 0;;
                --updater-path=*)
                  updater="${1#*=}";;
                --updater-path)
                  updater="$2";
                  shift;;
                --overwrite)
                  Overwrite=y;;
                *)
                  echo >&2 -e "AppImUpp.sh: unrecognized option '$1'.\\nTry --help for more information."
                  exit 0
              esac
              ###
              ;;
          -)
            Files+=("/dev/fd/0")
            shift;;
          -*)
            case "$1" in
              -*O*) Overwrite=y;;
              -*h*) Help;exit 0;;
              *) echo >&2 "Unsupported option.";;
            esac
            ;;
          *)
            Files+=("$1");
            ;;
        esac
    else
        Files+=("$1");
    fi
    shift
done
export updater Overwrite > "$SOURCED/appimup.conf"

if ! [ "${#Files[@]}" -eq 0 ]; then
  cd "$HOME/Applications";
  set -- "$(find . -maxdepth 1 -iname '*.appimage')"
fi;
if [ "$?" -gt 0 ]; then
    echo >&2 "No ~/Applications directory."
    exit 1;
fi;

if [ ! -e "$updater" ]; then
    updater="$(
ls "$HOME/Applications"/AppImageUpdate*.AppImage | head -z -1
)";
    if [ -f "$updater" ]; then
        echo "You have the graphical-only version of AppImageUpdate.AppImage"
        echo 'If you want silent/headless operation, please use (appimageupdatetool*.AppImage) instead.'
    fi
fi

if [ ! -e "$updater" ]; then
  echo 'AppImUpp: warning: missing file appimageupdatetool*.Appimage' >&2
  updater="./"*?"pdate"*".*pp*mage";
fi;
if [ ! -f "$updater" ]; then
  echo "And no AppImage called '*pdate*' found." >&2
  exit 254
fi;
echo "Found AppImage update tool."

"$updater" --self-update || echo "Error updating self ($updater)." >&2

for app in "$@"; do
    if ! [[ "$(basename "$updater")" = "$(basename "$app")" ]] || [[ "$(basename "$app")" =~ '\bold\b' ]]; then
        "$updater" ${Overwrite:+--overwrite} "$app";
    fi;
done;

