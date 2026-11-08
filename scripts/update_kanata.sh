#!/bin/zsh
# Upgrades kanata-cmd and the Karabiner VirtualHIDDevice driver to the newest versions that work together.
# Usage: update_kanata.sh [--check]    --check only reports versions and health.
# Set KANATA_PRERELEASE=1 to also accept kanata prereleases.
set -euo pipefail
autoload -Uz is-at-least

kanata_bin=/opt/homebrew/bin/kanata-cmd
manager_app=/Applications/.Karabiner-VirtualHIDDevice-Manager.app
driver_repo=pqrs-org/Karabiner-DriverKit-VirtualHIDDevice
driver_team=G43BCU2T37
check_only=0; [[ ${1:-} == --check ]] && check_only=1
restart_kanata=0

case $(uname -m) in
  arm64) arch=arm64 ;;
  x86_64) arch=x64 ;;
  *) print -u2 "Unsupported CPU: $(uname -m)"; exit 1 ;;
esac

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

github() { curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$1"; }
field() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }
core() { print -r -- "${1%%-*}"; }

if [[ ${KANATA_PRERELEASE:-0} == 1 ]]; then
  github 'jtroo/kanata/releases?per_page=1' | plutil -extract 0 json -o "$work/kanata.json" -
else
  github jtroo/kanata/releases/latest > "$work/kanata.json"
fi
tag=$(field "$work/kanata.json" tag_name)
want=${tag#v}
have=$("$kanata_bin" --version 2>/dev/null | awk '{print $2}' || true)

# kanata's release notes name one supported driver version; any driver release with the
# same client protocol works, so pick the newest of those.
supported=$(field "$work/kanata.json" body | grep -oE 'supported Karabiner driver version in this release is `v[0-9.]+`' | grep -oE 'v[0-9.]+' | head -1 || true)
driver_have=$(defaults read "$manager_app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || true)
driver_tag=''
if [[ -n $supported ]]; then
  protocol=$(curl -fsSL "https://raw.githubusercontent.com/$driver_repo/$supported/version.json" | plutil -extract client_protocol_version raw -o - -)
  github "$driver_repo/releases?per_page=50" > "$work/drivers.json"
  for (( i = 0; ; i++ )); do
    t=$(field "$work/drivers.json" "$i.tag_name") || break
    [[ $(field "$work/drivers.json" "$i.prerelease") == false ]] || continue
    p=$(curl -fsSL "https://raw.githubusercontent.com/$driver_repo/$t/version.json" | plutil -extract client_protocol_version raw -o - - 2>/dev/null || true)
    if [[ $p == $protocol ]]; then driver_tag=$t; break; fi
  done
fi
driver_want=${driver_tag#v}

print -r -- "kanata-cmd: ${have:-not installed} (latest ${want})"
print -r -- "Karabiner driver: ${driver_have:-not installed} (newest that kanata ${tag} supports: ${driver_want:-unknown})"

if (( ! check_only )); then
  if [[ -z $driver_want ]]; then
    print -u2 "No driver release matches kanata ${tag}'s supported protocol; leaving the driver alone."
  elif [[ $driver_have == $driver_want ]]; then
    :
  elif [[ -n $driver_have ]] && is-at-least "$driver_want" "$driver_have"; then
    print -u2 "Driver $driver_have is newer than $driver_want, the newest kanata supports; kanata may fail."
  else
    pkg="$work/driver.pkg"
    curl -fsSL -o "$pkg" "https://github.com/$driver_repo/releases/download/$driver_tag/Karabiner-DriverKit-VirtualHIDDevice-$driver_want.pkg"
    sig=$(pkgutil --check-signature "$pkg" || true)
    [[ $sig == *"Developer ID Installer: "*"($driver_team)"* ]] || { print -u2 'Driver package signature check failed.'; exit 1; }
    print -r -- "Installing Karabiner driver $driver_want..."
    sudo installer -pkg "$pkg" -target /
    "$manager_app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager" activate || print -u2 'If macOS asks, approve the driver under Driver Extensions.'
    launchctl print system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon >/dev/null 2>&1 && sudo launchctl kickstart -k system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon
    restart_kanata=1
  fi

  if [[ $have == $want ]]; then
    :
  elif [[ -n $have && $(core $have) != $(core $want) ]] && is-at-least "$(core $want)" "$(core $have)"; then
    print -u2 "kanata-cmd $have is newer than the latest release $want; leaving it."
  else
    zip=macos-binaries-$arch.zip
    url=https://github.com/jtroo/kanata/releases/download/$tag
    curl -fsSL -o "$work/$zip" "$url/$zip"
    curl -fsSL -o "$work/sha256sums" "$url/sha256sums"
    [[ $(awk -v f="$zip" '$2 == f {print $1}' "$work/sha256sums") == $(shasum -a 256 "$work/$zip" | awk '{print $1}') ]] || { print -u2 "Checksum mismatch for $zip."; exit 1; }
    unzip -q -o "$work/$zip" "kanata_macos_cmd_allowed_$arch" -d "$work"
    install -m 755 "$work/kanata_macos_cmd_allowed_$arch" "$kanata_bin"
    print -r -- "Installed kanata-cmd $want."
    restart_kanata=1
  fi

  if (( restart_kanata )) && launchctl print system/org.kanata >/dev/null 2>&1; then
    sudo launchctl kickstart -k system/org.kanata
    sleep 3
  fi
fi

problems=()
ext=$(systemextensionsctl list 2>/dev/null | grep 'Karabiner-DriverKit-VirtualHIDDevice' || true)
[[ $ext == *'[activated enabled]'* ]] || problems+=('Driver extension is off: System Settings > General > Login Items & Extensions > Driver Extensions')
[[ $(hidutil list 2>/dev/null) == *'Karabiner DriverKit VirtualHIDKeyboard'* ]] || problems+=('Karabiner virtual keyboard is missing')
[[ $(launchctl print system/org.kanata 2>/dev/null) == *'state = running'* ]] || problems+=('kanata service (org.kanata) is not running')
if (( ${#problems} )); then
  print -u2 -l -- 'kanata is not healthy:' "  ${^problems}"
  exit 1
fi
print -r -- 'kanata is running with the Karabiner virtual keyboard.'
if (( restart_kanata )); then
  print -r -- 'kanata-cmd changed. If a shortcut stops working, allow kanata-cmd under Accessibility again.'
fi
