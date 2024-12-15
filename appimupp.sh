#!/bin/bash
shopt -s dotglob
# disable graphics
QT_QPA_PLATFORM=offscreen
unset DISPLAY WAYLAND_DISPLAY

echo >&2 "- AppImUpp -

* --   loading +"

# options
Files=()
Opts=()
Done=
while "$1"; do
    if [ -z "$Done" ]; then
        case "$1" in
          --)
            Done=y;
            shift;
            ;;
          --updater-path=*)
            updater="${1#*=}";
            ;;
          --*)
            (
              case "$1" in
                --help)
                  HelpMe;
                  exit 0;
                  ;;
                --updater-path)
                  updater="$2";
                  shift;
                  ;;
                --overwrite)
                  Overwrite=y;
                  ;;
                *)
                  echo >&2 -e "AppImUpp.sh: unrecognized option '$1'.\\nTry --help for more information."
                  exit 0
                  ;;
              esac
            )
            ;;
          -)
            Files+=("/dev/fd/0")
            shift
            ;;
          -*)
            case "$1" in
                -*O*)
                Overwrite=y
            ;;
          *)
            Files+=("$1")
            ;;
        esac
    else
        Files+=("$1");
    fi
    shift
done

if ! [ "${#Files[@]}" -eq 0 ]; then
  cd "$HOME/Applications";
  set -- $(find . -maxdepth 1 -iname "*.appimage")
fi;
if [ "$?" -gt 0 ]; then
    echo >&2 "No ~/Applications directory."
    exit 1;
fi;

updater="$(ls $HOME/Applications/appimageupdatetool*.AppImage | head)";

if [ ! -f "$updater" ]; then
  echo "AppImUpp: warning: missing file AppImageUpdate*.Appimage" >&2
  updater="./"*?"pdate"*".AppImage";
fi;
if [ ! -f "$updater" ]; then
  echo "And no AppImage called '*pdate*' found." >&2
  exit 254
fi;
echo "Found AppImage update tool."

"$updater" --self-update || echo "Error updating self ($updater)." >&2

for app in "$@"; do
    if ! [[ "$(basename "$updater")" = "$(basename "$app")" ]] || [[ "$(basename "$app")" =~ '\bold\b' ]]; then
        "$updater" "$Overwrite" "$app";
    fi;
done;

