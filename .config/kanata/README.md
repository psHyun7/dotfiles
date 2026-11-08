# kanata on macOS

One kanata setup for every MacBook with a physical function-key row (Touch Bar models aren't covered), on Apple silicon or Intel.

## How it works

- **Config:** `macbook.kbd` in this folder, which includes a private `macbook.secret.kbd`. Git ignores `*.secret.kbd`, so copy it to each Mac securely and never commit it. kanata reads both files from here, so edits take effect when you press the `lrld` (live reload) key; no reinstall needed.
- **kanata:** the standard build from kanata's GitHub releases, at `/Library/Application Support/Kanata/kanata`. It runs as root, so it lives in a root-owned folder that other programs can't modify. The config has no `cmd` actions, so the cmd-enabled build isn't needed, and Homebrew's `kanata` isn't used.
- **Startup:** LaunchDaemons `com.sung.kanata` and `com.sung.karabiner-vhiddaemon`, made from the templates in `../launchdaemon`, start kanata and the driver's daemon at boot and restart them if they exit.
- **Logs:** `/Library/Logs/Kanata/kanata.err.log` and `kanata.out.log`, readable only with `sudo`.
- **Virtual keyboard driver:** the standalone Karabiner-DriverKit-VirtualHIDDevice package, which installs `/Applications/.Karabiner-VirtualHIDDevice-Manager.app`.
- **Karabiner-Elements:** don't install it, including the Homebrew cask. It bundles the same driver, and the two installs can replace each other's driver version, leaving kanata unable to open the virtual keyboard.

## Setting up a Mac

1. Pull this repo and copy `macbook.secret.kbd` into this folder.
2. Run `~/.dotfiles/scripts/install_kanata_launchd.zsh` and enter your password when asked. It installs kanata and the driver, installs the LaunchDaemons, removes services from older setups, and checks the result. It's safe to rerun.
3. If macOS asks, approve the driver under **System Settings → General → Login Items & Extensions → Driver Extensions**, then restart. A new driver version fully takes over only after a restart.
4. Run `~/.dotfiles/scripts/update_kanata.sh --check` to confirm everything works.

Rerun the installer after editing the LaunchDaemon templates. Config edits don't need it.

## Upgrades and driver versions

`topgrade` upgrades everything, including kanata (settings in `../topgrade.toml`). To upgrade only kanata and the driver, run `~/.dotfiles/scripts/update_kanata.sh`. It installs the latest stable kanata (set `KANATA_PRERELEASE=1` to include prereleases) and the newest driver that release supports, then restarts kanata and checks it.

Don't install the newest driver by hand. Each kanata release names one supported driver version, and only drivers with the same client protocol work. Through kanata 1.13.0-prerelease-1 that's protocol 5, whose newest driver is 6.14.0; drivers 7.x and 8.x break kanata.

Last verified 2026-11-07: kanata 1.12.0-prerelease-2 with driver 6.14.0 (driver extension 1.8.0) on macOS 27.2.

## After moving to a new Mac

Migration Assistant copies this setup. When cleaning up **Login Items & Extensions** afterward, leave these on:

- Driver Extensions: **Karabiner-DriverKit-VirtualHIDDevice**
- Background items: **kanata** and **Karabiner-VirtualHIDDevice-Daemon**

Then run `~/.dotfiles/scripts/update_kanata.sh --check`.

On 2026-11-07, after migrating to an M5 Pro MacBook Pro, the driver extension was switched off by accident during that cleanup. Without the virtual keyboard, kanata exited at startup and launchd restarted it more than 80 times. Turning the driver back on fixed it immediately.

## Troubleshooting

- **Driver off:** `systemextensionsctl list | grep -i karabiner` should show `[activated enabled]`. If it shows `[activated disabled]`, turn it on under Driver Extensions. If it's missing, run `/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate` and approve it. If the running version still doesn't match the manager app's version after an update and a restart, run the same command with `forceActivate` and restart again.
- **No virtual keyboard:** `hidutil list | grep -i karabiner` should show `Karabiner DriverKit VirtualHIDKeyboard`.
- **kanata keeps restarting:** in `launchctl print system/com.sung.kanata | grep -E 'state =|runs ='`, a `runs` count that keeps climbing means kanata is crashing. Check the driver first, then run `sudo tail -n 50 /Library/Logs/Kanata/kanata.err.log`.
- **Config errors:** `'/Library/Application Support/Kanata/kanata' --check -c ~/.dotfiles/.config/kanata/macbook.kbd`.
- **`IOHIDDeviceOpen error: (iokit/common) not permitted`:** macOS hasn't given kanata keyboard access. In System Settings, remove any stale kanata entries under Accessibility and Input Monitoring, add `/Library/Application Support/Kanata/kanata` to both (press Cmd-Shift-G to type the path), then run `sudo launchctl kickstart -k system/com.sung.kanata`. The MacBook 12 needed this once.
