#!/bin/zsh

set -euo pipefail

repo_root=${0:A:h:h}
config_source="$repo_root/.config/kanata/macbook.kbd"
secret_source="$repo_root/.config/kanata/macbook.secret.kbd"
kanata_source=${1:-}
launchdaemon_source="$repo_root/.config/launchdaemon"
config_destination="/Library/Application Support/Kanata"
labels=(
  com.sung.karabiner-vhidmanager
  com.sung.karabiner-vhiddaemon
  com.sung.kanata
)

if [[ ! -f "$config_source" ]]; then
  print -u2 "Kanata config not found: $config_source"
  exit 1
fi

if [[ ! -f "$secret_source" ]]; then
  print -u2 "Kanata secret not found: $secret_source"
  exit 1
fi

if [[ -z "$kanata_source" ]]; then
  for candidate in \
    /opt/homebrew/bin/kanata \
    /usr/local/bin/kanata \
    "$HOME/Downloads/macos-binaries-x64/kanata_macos_cmd_allowed_x64"; do
    if [[ -x "$candidate" ]]; then
      kanata_source=$candidate
      break
    fi
  done
fi

if [[ ! -x "$kanata_source" ]]; then
  print -u2 "Command-enabled kanata binary not found. Pass its path as the first argument."
  exit 1
fi

for label in $labels; do
  if [[ ! -f "$launchdaemon_source/$label.plist" ]]; then
    print -u2 "LaunchDaemon source not found: $launchdaemon_source/$label.plist"
    exit 1
  fi
done

"$kanata_source" --check -c "$config_source"

if [[ "$kanata_source" == /opt/homebrew/bin/kanata || "$kanata_source" == /usr/local/bin/kanata ]]; then
  kanata_runtime=$kanata_source
else
  kanata_runtime=/usr/local/bin/kanata
  sudo install -o root -g wheel -m 755 "$kanata_source" "$kanata_runtime"
fi

sudo install -d -o root -g wheel -m 755 "$config_destination"
sudo install -o root -g wheel -m 644 "$config_source" "$config_destination/macbook.kbd"
sudo install -o root -g wheel -m 600 "$secret_source" "$config_destination/${secret_source:t}"
sudo install -d -o root -g wheel -m 755 /Library/Logs/Kanata

for label in $labels; do
  sudo launchctl bootout "system/$label" 2>/dev/null || true
  sudo install -o root -g wheel -m 644 \
    "$launchdaemon_source/$label.plist" \
    "/Library/LaunchDaemons/$label.plist"
  if [[ "$label" == com.sung.kanata ]]; then
    sudo /usr/libexec/PlistBuddy -c \
      "Set :ProgramArguments:0 $kanata_runtime" \
      "/Library/LaunchDaemons/$label.plist"
  fi
  sudo launchctl enable "system/$label"
  sudo launchctl bootstrap system "/Library/LaunchDaemons/$label.plist"
done

print "Installed kanata from '$kanata_runtime' and enabled startup at boot."
sudo launchctl print system/com.sung.kanata | grep -E '^\s*(state|pid|last exit code) ='