# Kanata macOS Setup

This directory contains a shared kanata config for MacBook keyboards. The installer detects the kanata binary available on each machine and writes that path into the installed LaunchDaemon.

## Requirements

- The shared `macbook.kbd` config
- A local `macbook.secret.kbd` file
- The command-enabled kanata binary because the configs use `danger-enable-cmd yes`
- Karabiner VirtualHIDDevice installed, activated, and approved in macOS Privacy & Security settings

Files matching `*.secret.kbd` are ignored by Git. Transfer them securely between machines or recreate them locally; do not commit them.

If a machine already has `macbook12.secret.kbd` or `macbookpro.secret.kbd`, rename it locally:

```sh
mv ~/.dotfiles/.config/kanata/macbook12.secret.kbd ~/.dotfiles/.config/kanata/macbook.secret.kbd
```

Use `macbookpro.secret.kbd` as the source name on the other Mac.

## First-Time Setup

Clone or pull this repository, then place the matching secret file beside its profile:

```text
.config/kanata/macbook.kbd
.config/kanata/macbook.secret.kbd
```

Install and activate Karabiner VirtualHIDDevice. The expected manager application is:

```text
/Applications/.Karabiner-VirtualHIDDevice-Manager.app
```

Run the installer. It checks `/opt/homebrew/bin/kanata`, `/usr/local/bin/kanata`, and the downloaded Intel binary location, in that order. You can also pass a binary path explicitly.

MacBook 12 using the downloaded Intel binary:

```sh
~/.dotfiles/scripts/install_kanata_launchd.zsh \
  ~/Downloads/macos-binaries-x64/kanata_macos_cmd_allowed_x64
```

MacBook Pro using a Homebrew-installed binary:

```sh
~/.dotfiles/scripts/install_kanata_launchd.zsh \
  /opt/homebrew/bin/kanata
```

If kanata is in one of the detected locations, omit the argument:

```sh
~/.dotfiles/scripts/install_kanata_launchd.zsh
```

The installer requests an administrator password, validates the config, and installs:

```text
/Library/Application Support/Kanata/macbook.kbd
/Library/LaunchDaemons/com.sung.*.plist
/Library/Logs/Kanata/
```

An existing binary under `/opt/homebrew/bin` or `/usr/local/bin` is used in place. A binary from another location is copied to `/usr/local/bin/kanata`. The installer replaces `KANATA_BINARY_PATH` in the installed plist with the resolved path.

The LaunchDaemons start VirtualHIDDevice and kanata automatically at boot.

## Verify

Check the kanata service:

```sh
sudo launchctl print system/com.sung.kanata
pgrep -afil kanata
```

Read its logs:

```sh
tail -50 /Library/Logs/Kanata/kanata.out.log
tail -50 /Library/Logs/Kanata/kanata.err.log
```

Confirm the VirtualHID extension is active:

```sh
systemextensionsctl list | grep -i Karabiner
```

## Updating

After pulling config or LaunchDaemon changes, rerun the installer. The running service uses the root-owned installed copy, not the file directly inside the Git repository:

```sh
~/.dotfiles/scripts/install_kanata_launchd.zsh
```

## Troubleshooting

Validate a profile without starting kanata:

```sh
/path/to/kanata --check -c ~/.dotfiles/.config/kanata/macbook.kbd
```

If the service is missing, rerun the installer. If the logs report that the keyboard device cannot be opened, verify that Karabiner VirtualHIDDevice is activated and approved, then restart macOS.

### Accessibility / Input Monitoring permission errors

macOS's TCC permission store cannot be granted programmatically; each Mac needs a one-time manual approval. If you moved, renamed, or upgraded the kanata binary, macOS pins the *old* path as a separate (broken) entry, which causes `IOHIDDeviceOpen error: (iokit/common) not permitted` even though an entry appears to exist:

1. System Settings → Privacy & Security → **Accessibility**: remove any stale `kanata` entry, then add `/usr/local/bin/kanata` (`Cmd+Shift+G` to type the path) and enable it.
2. Same pane → **Input Monitoring**: repeat the remove-then-readd step for `/usr/local/bin/kanata`.
3. Restart the daemon so it picks up the new grants:

```sh
sudo launchctl kickstart -k system/com.sung.kanata
```