#!/bin/zsh

set -euo pipefail

repo_root=${0:A:h:h}
kanata_source=${1:-$HOME/Downloads/macos-binaries-x64/kanata_macos_cmd_allowed_x64}
launchdaemon_source="$repo_root/.config/launchdaemon"
labels=(
  com.sung.karabiner-vhidmanager
  com.sung.karabiner-vhiddaemon
  com.sung.kanata
)

if [[ ! -x "$kanata_source" ]]; then
  print -u2 "Command-enabled kanata binary not found: $kanata_source"
  exit 1
fi

for label in $labels; do
  if [[ ! -f "$launchdaemon_source/$label.plist" ]]; then
    print -u2 "LaunchDaemon source not found: $launchdaemon_source/$label.plist"
    exit 1
  fi
done

sudo install -o root -g wheel -m 755 "$kanata_source" /usr/local/bin/kanata
sudo install -d -o root -g wheel -m 755 /Library/Logs/Kanata

for label in $labels; do
  sudo launchctl bootout "system/$label" 2>/dev/null || true
  sudo install -o root -g wheel -m 644 \
    "$launchdaemon_source/$label.plist" \
    "/Library/LaunchDaemons/$label.plist"
  sudo launchctl enable "system/$label"
  sudo launchctl bootstrap system "/Library/LaunchDaemons/$label.plist"
done

print "Installed kanata and enabled startup at boot."
sudo launchctl print system/com.sung.kanata | grep -E '^\s*(state|pid|last exit code) ='