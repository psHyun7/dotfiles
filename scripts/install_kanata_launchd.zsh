#!/bin/zsh
# Sets up kanata to start at boot on any MacBook and replaces services from older setups. Safe to rerun.
set -euo pipefail

repo_root=${0:A:h:h}
kanata_bin='/Library/Application Support/Kanata/kanata'
config="$repo_root/.config/kanata/macbook.kbd"
secret="$repo_root/.config/kanata/macbook.secret.kbd"
templates="$repo_root/.config/launchdaemon"
labels=(com.sung.karabiner-vhiddaemon com.sung.kanata)
old_labels=(org.kanata org.pqrs.Karabiner-VirtualHIDDevice-Daemon com.sung.karabiner-vhidmanager)

for f in "$config" "$secret" "$templates/${^labels}.plist"; do
  [[ -f $f ]] || { print -u2 "Missing: $f"; exit 1; }
done

"$repo_root/scripts/update_kanata.sh"
"$kanata_bin" --check -c "$config" >/dev/null

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
sudo install -d -o root -g wheel -m 755 /Library/Logs/Kanata

for label in $old_labels $labels; do
  sudo launchctl bootout "system/$label" 2>/dev/null || true
done
for label in $old_labels; do
  sudo rm -f "/Library/LaunchDaemons/$label.plist"
done

for label in $labels; do
  cp "$templates/$label.plist" "$work/$label.plist"
  if [[ $label == com.sung.kanata ]]; then
    plutil -replace ProgramArguments.0 -string "$kanata_bin" "$work/$label.plist"
    plutil -replace ProgramArguments.2 -string "$config" "$work/$label.plist"
  fi
  sudo install -o root -g wheel -m 644 "$work/$label.plist" "/Library/LaunchDaemons/$label.plist"
  sudo launchctl enable "system/$label"
  sudo launchctl bootstrap system "/Library/LaunchDaemons/$label.plist"
done

# Binaries and config copies left by older setups
if [[ -f /opt/homebrew/bin/kanata-cmd && ! -L /opt/homebrew/bin/kanata-cmd ]]; then
  rm -f /opt/homebrew/bin/kanata-cmd
fi
if [[ -f /usr/local/bin/kanata && ! -L /usr/local/bin/kanata && $(stat -f %Su /usr/local/bin/kanata) == root ]]; then
  sudo rm -f /usr/local/bin/kanata
fi
sudo rm -f '/Library/Application Support/Kanata/macbook.kbd' '/Library/Application Support/Kanata/macbook.secret.kbd'

sleep 3
"$repo_root/scripts/update_kanata.sh" --check