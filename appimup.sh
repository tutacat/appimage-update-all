#!/usr/bin/bash
# AppImUp.sh

set -u
shopt -s nocaseglob

shopt -s dotglob

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
APP_NAME="AppImUp"
APP_CONFDIR="${XDG_CONFIG_HOME}/${APP_NAME}"
APP_SETTINGS="${APP_CONFDIR}/settings.conf"
APPS_DIR="${HOME}/Applications"
EXE="$(basename "$0")"

function Help() {
  echo >&2 -e "usage: '${EXE}' [option(s)] [file(s)]"
  echo "    ${APP_NAME} updates all the AppImages in your Applications directory, or the specified AppImage files."
  echo '  -h --help        Show this help.'
  echo '  -O --overwrite   Overwrite the original AppImage [Overwrite=y]'
  echo '  file(s)          Update this file or files.'
  echo '  --update-tool    Set the path for appimage update tool [Updater=...]'$'\n\n''  AppImageUpdate is provided by AppImage-Community and TheAssassin under the MIT License'
  echo '  --apps-dir       Set applications directory to search for AppImages.'
  echo '  --save           Save options to config.' 
  echo '  https://github.com/AppImageCommunity/AppImageUpdate.git/'
  echo "Config is stored at \$XDG_CONFIG_HOME or \$HOME: ${APP_SETTINGS}"
}


mkdir -p "${APP_CONFDIR}"
grep "=" "${APP_SETTINGS}" | sed -E 's/ ?= ?/=/' | while read line; do
  set "$line"
done
export LC_COLLATE=C
if [ -z "$Updater" ]; then
    Updater="`ls "$HOME/Applications"/*{appimageupdatetool,AppImageUpdate}*.appimage | head -1`"
fi
Done=""

Files=()
while [ -n "$1" ]; do
    if [ "$Done" != "y" ]; then
        case "$1" in
          --)
            Done=y
            
          --*)
              case "$1" in
                --help)
                  Help
                  exit 0
            
                --update-tool)
                  Updater="$2"
                  shift
                  ;;
                --updater-path=*)
                  Updater="${1#*=}"
                  ;;
	        *)
	          echo >&2 -e "${EXE}: unrecognized option '$1'.\\nTry --help for more information."
	          exit 1
            
          -)
            Files+=("/dev/fd/0")
            shift
            
          -*)
            case "$1" in
              -*O*) Overwrite=y
            
              -*h*) Help; exit 0
            
             *) echo >&2 "Unrecognized short option ."
                exit 1
            
            esac
          ;;
          *)
            Files+=("$1")
            ;;
        esac
    else
        Files+=("$1")
    fi
    shift
done

(
  echo "Updater=$Updater"
  echo "Overwrite=$Overwrite"
) > "${APP_SETTINGS}"
if ! [ "${#Files[@]}" -eq 0 ]; then
  cd "$HOME/Applications"
    FILES+=("$(find . -maxdepth 1 -iname '*.appimage')")
fi
if [ "$?" -gt 0 ]; then
    echo >&2 "No ~/Applications directory."
    exit 1
fi

if [ ! -e "$Updater" ]; then
    Updater="$(
ls "$HOME/Applications/AppImageUpdate"*".AppImage" | head --lines=-1 -z
)"
    if [ -f "$Updater" ]; then
        echo "You have the graphical-only version of AppImageUpdate.AppImage"
        echo 'If you want silent/headless operation, please use (appimageupdatetool*.AppImage) instead.'
    fi
fi
if [ ! -e "$Updater" ]; then
  echo 'AppImUp: warning: missing file appimageupdatetool*.Appimage' >&2
  updater2="./"*?"pdate"*".?pp?mage"
fi
if [ ! -f "$updater2" ]; then
  echo "And no AppImage called '*pdate*' found." >&2

exit 254
fi
echo "Found AppImage update tool."

"$Updater" --self-update || echo "Error updating self ($Updater)." >&2

for app in "$@"; do
    if ! [[ "$(basename "$Updater")" = "$(basename "$app")" ]] || [[ "$(basename "$app")" =~ \bold\b ]]; then
        "$Updater" ${Overwrite:+--overwrite} "$app"
    fi
done
