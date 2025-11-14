#!/usr/bin/bash
set -u
shopt -s nocaseglob
shopt -s dotglob

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
APP_NAME="AppImUp"
APP_CONFDIR="${XDG_CONFIG_HOME}/${APP_NAME}"
APP_SETTINGS="${APP_CONFDIR}/settings.conf"
AppsDir="${HOME}/Applications"
EXE="$(basename "$0")"
LS_ARGS='-t --time=mtime'
GITHUB_TOKEN="${GITHUB_TOKEN-}"

function Help() {
    cat >&2 <<EOF_HELP
usage: '${EXE}' [option(s)] [file(s)]
    ${APP_NAME} updates all the AppImages in your Applications directory, or the specified AppImage files.
Short options: only one option per arg supported (for forwarding options).
^Forwarded args must use =, short options, or optionless.
  -h --help        Show this help.
  -O --overwrite   Overwrite the original AppImage [Overwrite=y]
  file(s)          Update this file or files.
  --update-tool    Set the path for appimage update tool [Updater=...]
  --apps-dir       Set applications directory to search for AppImages.
  --save           Save options to config.
  --is-pie-exe     Assume the updater is a PIE executable even if \`file\` doesn't

* appimageupdatetool is provided by AppImage-Community and TheAssassin under the MIT License
  * https://github.com/AppImageCommunity/AppImageUpdate/#readme
    Config is stored at (\$XDG_CONFIG_HOME or \$HOME/.config): ${APP_SETTINGS}
EOF_HELP
    if [[ -n "${Updater-}" ]]; then
      if [[ "${Updater}" ~= ^AppImageUpdate\b ]]; then
        echo >&2 "$0: Help: Graphical updater doesn't provide CLI help."
      "$Updater" --help | tail -n +10
    else
      echo >&2 "$0: Help: couldn't show updater CLI help, as exe was not found.";
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

function text_exe() {
  if [ -n "$1" ]; then
    if [ -e "$1" ]; then
      if [ -x "$1" ]; then
        if [ -n "${IsPie}" -o "$(file -b --mime-type)" == "application/x-pie-executable" ]; then
          return 0
        else
          echo >&2 "$0: Search: Updater is not of a known executable type."
        fi
      else
        echo >&2 "$0: Search: Updater is not executable.";
    else
      echo >&2 "$0: Search: Updater found but path doesn't exist.";
      >&2 readlink -fv "${Updater-}"
    fi
  else
    echo >&2 "$0: Search: Updater not found.";
  fi
  return 1
}


mkdir -p "${APP_CONFDIR}"
grep '=' "${APP_SETTINGS}" \
| grep -Ev '^ *^\[' \
| sed -E 's/ ?= ?/=/; s/#.*$//' \
| while read line; do
    set "${line-}";
done
export LC_COLLATE=C
if [ ! -x "${Updater-}" ]; then
  Updater="`ls $LS_ARGS "${AppsDir}"/*appimageupdatetool*.AppImage | head -1`"
  if [ ! -x "${Updater-}" ]; then
    Updater="`ls $LS_ARGS "${AppsDir}"/*AppImageUpdate*.AppImage | head -1`"
    if [ -x "${Updater-}" ]; then
        echo >&2 "$0: Search: You only have the graphical version of AppImageUpdate"
        echo >&2 '    If you want silent/headless operation, please use (appimageupdatetool*.AppImage) instead.'
    else
  fi
fi
Done=""

QueueAction=""

IsPie=""

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
                  AppsDir="${2}"
                  shift
                  ;;
                --is-pie-exe)
                  IsPie=y
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
    echo "AppsDir=${AppsDir-}"
    echo "IsPie=${IsPie-}"
) > "${APP_SETTINGS}"

if ! [ "${#Files[@]}" -eq 0 ]; then
  cd "${AppsDir}"
    FILES+=("$(find . -maxdepth 1 -iname '*.appimage')")
fi

if [ "$?" -gt 0 ]; then
    echo >&2 "$0: No ${AppsDir} directory."
    exit 1
fi

if [ ! -e "${Updater-}" ]; then
    Updater="$(
ls "${AppsDir}/AppImageUpdate"*".AppImage" | head --lines=-1 -z
)"
fi
if [ ! -e "${Updater-}" ]; then
    echo >&2 "$0"': warning: missing file appimageupdatetool*.Appimage' >&2
    updater2="./"*"pdate"*".appimage"

    if [ ! -f "${updater2}" ]; then
        echo >&2 "$0: no AppImage called '*pdate*' found in \~/Applications." >&2
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
