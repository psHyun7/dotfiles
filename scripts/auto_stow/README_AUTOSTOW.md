# the auto-stow watcher

- Compiles to a single binary for lower runtime overhead.
- Ignores `.DS_Store` and removes any `.DS_Store` files inside a package before running `stow` to avoid `stow` failures.

Build

```bash
cd ~/.dotfiles/scripts/auto_stow
go build -o bin/auto_stow_watch auto_stow_watch.go
```

Run

```bash
# dry-run scan
~/.dotfiles/scripts/auto_stow/bin/auto_stow_watch --scan --dry-run

# actual import
~/.dotfiles/scripts/auto_stow/bin/auto_stow_watch --scan

# run watcher
~/.dotfiles/scripts/auto_stow/bin/auto_stow_watch
```

Dependencies

```bash
# install Go and then:
cd ~/.dotfiles/scripts/auto_stow
go mod tidy

LaunchAgents

cp ~/.dotfiles/scripts/auto_stow/launch_agents/com.autostow.plist ~/Library/LaunchAgents/
# bootstrap for current GUI session (preferred on newer macOS)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.autostow.plist
# or, unload then load to restart
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.autostow.plist || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.autostow.plist

Notes

- The watcher watches your home directory non-recursively and reacts to Create/Rename events for top-level dotfiles.
- It will not move files that are already symlinks.
- It backs up existing copies inside a package into `~/.dotfiles/backups/<timestamp>/` if collisions occur.

If you want, I can:

- Add a small `Makefile` or `brew`/Homebrew packaging for the binary.
- Add grouping options (e.g., put everything under `.config` package) or customize which tops map to which package names.
