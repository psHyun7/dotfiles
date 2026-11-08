# kanata on macOS

How kanata runs on the Mac with my current setup, why it broke after the November 2026 migration, and what to check after the next move.

## Setup

- **kanata:** `/opt/homebrew/bin/kanata-cmd`, the cmd-enabled arm64 build from kanata's GitHub releases. The Apple Music shortcuts in `macbookpro.kbd` use `cmd` actions, and Homebrew's `kanata` is compiled without them, so Homebrew doesn't install or track this file. `~/.dotfiles/scripts/update_kanata.sh` installs and upgrades it.
- **Config:** `macbookpro.kbd` in this folder. It sets `danger-enable-cmd`, so it needs the cmd-enabled build.
- **Startup:** LaunchDaemon `org.kanata` (`/Library/LaunchDaemons/org.kanata.plist`) runs kanata-cmd as root at boot and restarts it whenever it exits.
- **Logs:** `/Library/Logs/Kanata/kanata.err.log` and `kanata.out.log`, readable only with `sudo`.
- **Virtual keyboard driver:** Karabiner-DriverKit-VirtualHIDDevice 6.14.0 (driver extension 1.8.0), installed at `/Applications/.Karabiner-VirtualHIDDevice-Manager.app`. Its daemon runs from LaunchDaemon `org.pqrs.Karabiner-VirtualHIDDevice-Daemon`.
- **Karabiner-Elements:** not installed and not needed; kanata only uses the driver. Don't reinstall it: it competes with kanata for the keyboard, and its updates can replace the driver with one kanata can't use. Its old settings remain in `../karabiner`.

## What broke on 2026-11-07

The migration to this Mac (M5 Pro, macOS 27.2) carried everything over, and the driver was still enabled afterward. Later, while old items were being cleaned out of Login Items & Extensions, the **Karabiner-DriverKit-VirtualHIDDevice** driver extension was switched off, most likely by accident. Without the virtual keyboard, kanata exited at startup (exit code 1) and launchd restarted it more than 80 times. Turning the driver back on fixed it immediately; no reinstall or restart was needed.

## After moving to a new Mac

When cleaning up **System Settings → General → Login Items & Extensions**, leave these on:

- Driver Extensions: **Karabiner-DriverKit-VirtualHIDDevice**
- Background items: **kanata-cmd** and **Karabiner-VirtualHIDDevice-Daemon**

Then run `~/.dotfiles/scripts/update_kanata.sh --check`, which reports versions and runs checks 1–3. To check by hand:

1. **Driver enabled:** `systemextensionsctl list | grep -i karabiner` shows `[activated enabled]`.
   - If it shows `[activated disabled]`, turn it on under Driver Extensions.
   - If it's missing, run `/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate`, then approve it under Driver Extensions.
2. **Virtual keyboard exists:** `hidutil list | grep -i karabiner` shows `Karabiner DriverKit VirtualHIDKeyboard`.
3. **kanata stays running:** `launchctl print system/org.kanata | grep -E 'state =|runs ='` shows `state = running`, and `runs` doesn't change when you rerun it a minute later. If `runs` keeps climbing, kanata is crash-looping: recheck step 1, then run `sudo tail -n 50 /Library/Logs/Kanata/kanata.err.log`.
4. **Right binary and permission:** `file /opt/homebrew/bin/kanata-cmd` shows `arm64`, and kanata-cmd is still allowed under Accessibility. The binary is ad-hoc signed, so replacing or updating it can make the old permission stop applying; if that happens, remove the entry and add it again.

## Upgrades and driver versions

Run `topgrade` to upgrade everything, including kanata (settings in `../topgrade.toml`). To upgrade only kanata and the driver, run `~/.dotfiles/scripts/update_kanata.sh`. It installs the latest stable kanata-cmd (set `KANATA_PRERELEASE=1` to include prereleases) and the newest driver that release supports, then restarts kanata and checks it.

Each kanata release names one supported driver version, and any driver with the same client protocol works. Through kanata 1.13.0-prerelease-1, that's protocol 5, whose newest driver is 6.14.0. Drivers 7.x and 8.x use newer protocols and won't work, so don't install them by hand.

Verified on 2026-11-07: kanata-cmd 1.12.0-prerelease-2 with driver 6.14.0 (driver extension 1.8.0) on macOS 27.2.

## Fresh setup (without Migration Assistant)

The Brewfile doesn't install kanata-cmd, the driver, or either LaunchDaemon. Run `~/.dotfiles/scripts/update_kanata.sh` to install kanata-cmd and the driver, and approve the driver under Driver Extensions. Then copy the two LaunchDaemons from the old Mac or recreate them:

- `/Library/LaunchDaemons/org.kanata.plist`: label `org.kanata`; runs `/opt/homebrew/bin/kanata-cmd -c /Users/sung_/.dotfiles/.config/kanata/macbookpro.kbd`; `RunAtLoad` and `KeepAlive` true; `ProcessType` Interactive; `StandardErrorPath` and `StandardOutPath` set to the log files above.
- `/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist`: label `org.pqrs.Karabiner-VirtualHIDDevice-Daemon`; runs `/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon`; `RunAtLoad` and `KeepAlive` true; `ProcessType` Interactive.

Load each with `sudo launchctl bootstrap system /Library/LaunchDaemons/<file>.plist`, then run the checks above.
