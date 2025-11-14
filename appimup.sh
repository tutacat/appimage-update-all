#!/usr/bin/bash
set -u
shopt -s nocaseglob
shopt -s dotglob

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
APP_NAME="AppImUp"
APP_CONFDIR="${XDG_CONFIG_HOME}/${APP_NAME}"
APP_SETTINGS="${APP_CONFDIR}/settings.conf"
APPS_DIR="${HOME}/Applications"
EXE="$(basename "$0")"
LS_ARGS='-t --time=mtime'
GITHUB_TOKEN="${GITHUB_TOKEN-}"

function Help() {
    echo >&2 -e "usage: '${EXE}' [option(s)] [file(s)]"
    echo >&2 "    ${APP_NAME} updates all the AppImages in your Applications directory, or the specified AppImage files."
    echo >&2 "Short options: only one option per arg supported (for forwarding options)."
    echo >&2 "^Forwarded args must use =, short options, or optionless."
    echo >&2 '  -h --help        Show this help.'
    echo >&2 '  -O --overwrite   Overwrite the original AppImage [Overwrite=y]'
    echo >&2 '  file(s)          Update this file or files.'
    echo >&2 '  --update-tool    Set the path for appimage update tool [Updater=...]'$'\n\n''  AppImageUpdate is provided by AppImage-Community and TheAssassin under the MIT License'
    echo >&2 '  --apps-dir       Set applications directory to search for AppImages.'
    echo >&2 '  --save           Save options to config.'
    echo >&2 '  https://github.com/AppImageCommunity/AppImageUpdate.git/'
    echo >&2 "Config is stored at (\$XDG_CONFIG_HOME or \$HOME/.config): ${APP_SETTINGS}"
    if [ -n "${Updater-}" ]; then
      "$Updater" --help | tail -n +10
    else
      echo >&2 "$0: Help: Updater not found.";
    fi
}
function Version() {
    if [ -n "${Updater-}" ]; then
      "$Updater" --version
    else
      echo >&2 "$0: Version: Updater not found.";
    fi
    exit 0
}


mkdir -p "${APP_CONFDIR}"
grep '=' "${APP_SETTINGS}" \
| grep -Ev '^ *^\[' \
| sed -E 's/ ?= ?/=/; s/#.*$//' \
| while read line; do
    set "${line-}";
done
export LC_COLLATE=C
if [ ! -e "${Updater-}" ]; then
  Updater="`ls $LS_ARGS "$HOME/Applications"/*appimageupdatetool*.AppImage | head -1`"
  if [ ! -e "${Updater-}" ]; then
    Updater="`ls $LS_ARGS "$HOME/Applications"/*AppImageUpdate*.AppImage | head -1`"
    if [ -e "${Updater-}" ]; then
        echo >&2 "$0: You have the graphical-only version of AppImageUpdate.AppImage"
        echo >&2 '$0: If you want silent/headless operation, please use (appimageupdatetool*.AppImage) instead.'
    fi
  fi
fi
Done=""

QueueAction=""

Files=()
OtherOpts=()
while [ -n "${1-}" ]; do
    if [ "${Done-}" != "y" ]; then
        case "${1-}" in
          --)
            Done=y
            ;;
          --*)
              case "$1" in
                --help) Help; exit 0;;
                --version) Version; exit 0;;
                --update-tool)
                  Updater="${2}"
                  shift
                  ;;
                --updater-path=*)
                  Updater="${1#*=}"
                  ;;

                --apps-dir)
                  APPS_DIR="${2}"
                  shift
                  ;;
	        *)
                  OtherOpts+=("$1")
                  ;;
              esac
            ;;
          -)
            Files+=("/dev/fd/0")
            shift
            ;;
          -*)
            case "$1" in
              -O) Overwrite=y;;
              -h) Help; exit 0;;
              -V) Version; exit 0;;
              -??*) echo >&2 "$0: option '$1': Short options are limited to 1 (to pass unknown options to updater)"
                exit 1
                ;;
              -?)
                OtherOpts+=("$1")
                ;;
              *)
                echo >&2 "$0: Unexpected error: This case should not be possible: short options, default case"
                exit 1;
                ;;
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
    echo "Updater=${Updater-}"
    echo "Overwrite=${Overwrite-}"
) > "${APP_SETTINGS}"

if ! [ "${#Files[@]}" -eq 0 ]; then
  cd "$HOME/Applications"
    FILES+=("$(find . -maxdepth 1 -iname '*.appimage')")
fi

if [ "$?" -gt 0 ]; then
    echo >&2 "$0: No ~/Applications directory."
    exit 1
fi

if [ ! -e "${Updater-}" ]; then
    Updater="$(
ls "$HOME/Applications/AppImageUpdate"*".AppImage" | head --lines=-1 -z
)"
fi
if [ ! -e "${Updater-}" ]; then
    echo >&2 "$0"': warning: missing file appimageupdatetool*.Appimage' >&2
    updater2="./"*"pdate"*".appimage"

    if [ ! -f "${updater2}" ]; then
        echo >&2 "$0: no AppImage called '*pdate*' found in ~/Applications." >&2
        exit 254
    fi
fi
echo >&2 "$0: Found AppImage update tool."

"$Updater" --self-update || echo >&2 "$0: Error self updating \($Updater\)." >&2

if [ "${Overwrite-}" = y ]; then
    Overwrite="--overwrite"
else
    Overwrite=""
fi

Delay=0.5
if [ "${@#}" >= 15 -a -z "$GITHUB_TOKEN" ]; then
    Delay="${@#}"
    if [[ "$Delay" < 0.5 ]]; then
        Delay=0.5
    fi
    if [[ "$Delay" > 60 ]]; then
        Delay=60
    fi
    echo >&2 """Warning: GitHub API without authentication only allows 60 requests per hour!
If you want to update more apps per hour, please set your GITHUB_TOKEN authentication in the env and for appimageupdatetool.
    Since you are updating 15 or more, I am setting local limit to $(echo "$((3600/Delay))" | bc)/hr to help try and avoid this."""
fi

for app in "$@"; do
    if ! [[ "$(basename "$Updater")" = "$(basename "$app")" ]] || [[ "$(basename "$app")" =~ \bold\b ]]; then
        let prev_time="$SECONDS"
        sleep "$Delay" &
        "$Updater" ${Overwrite} "$app" "${OtherOpts}"
        wait "$!"
    fi
done

sleep 5
