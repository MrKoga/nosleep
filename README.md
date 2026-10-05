# nosleep

Keep a MacBook running with the lid closed, from the terminal, and put it back to normal (or straight to sleep) with one command.

```
nosleep -on       keep running through every lid close until you run -off
nosleep -off      back to normal: closing the lid sleeps the Mac
nosleep -sleep    back to normal, then put the Mac to sleep right now
nosleep           show whether nosleep is on or off
```

## Why

Closing a MacBook's lid puts it to sleep, and there is no checkbox in System Settings to stop that on battery. Sometimes you want the machine to keep going with the lid shut: a long download, a build, a backup, a server you are connected to over SSH, a terminal session you want to come back to. macOS does have a switch for this (`pmset disablesleep`), but it needs `sudo`, it is easy to forget to turn back off, and once it is on, closing the lid leaves the screen lit and unlocked inside the closed lid. `nosleep` wraps the switch in a short command, keeps track of whether it is on, and adds a small helper so the screen still turns off and locks when you close the lid.

## How it works, in plain words

1. **The switch.** `nosleep -on` runs `pmset -a disablesleep 1`, the one macOS setting that keeps a MacBook awake with the lid shut. While it is set the Mac does not sleep at all: not when idle, not from the Apple menu, not on battery. `nosleep -off` runs `pmset -a disablesleep 0`, which restores stock behavior.
2. **No password every time.** Those `pmset` calls need root. The installer adds one file, `/etc/sudoers.d/nosleep`, that lets your account run exactly three commands without a password: `pmset -a disablesleep 1`, `pmset -a disablesleep 0`, and `pmset sleepnow`. Nothing else gets elevated.
3. **The lid-close lock.** With sleep disabled, closing the lid no longer turns off the display, so the normal "require password after the display turns off" lock never engages. `lidlock-watch` is a tiny background loop (a LaunchAgent) that checks the lid every 2 seconds and turns the display off the moment it closes. The Mac keeps running; the screen goes dark and locks as usual. When nosleep is off, the helper is harmless, because the display was about to turn off anyway.
4. **Status.** `nosleep -on` leaves a marker file at `~/.local/state/nosleep.on`, so plain `nosleep` can tell you whether it turned sleep off. The real source of truth is always `pmset -g | grep SleepDisabled` (1 = will not sleep, 0 = normal).

## Requirements

- A Mac laptop. Used daily since August 2026 on an Apple Silicon MacBook Air, currently on macOS 27; it only uses `pmset`, `ioreg`, `launchctl`, and `sudo`, all of which ship with macOS.
- An administrator account. You will type your password once, during install.
- Basic comfort with Terminal.

## Install

1. Get the files. Either download https://github.com/mrkoga/nosleep/archive/refs/heads/main.zip and unzip it (the folder is called `nosleep-main`), or run `git clone https://github.com/mrkoga/nosleep.git` in Terminal. On the GitHub page, the green "Code" button also has a "Download ZIP" option.
2. Open Terminal.
3. Move into the folder: `cd` followed by a space, then drag the folder onto the Terminal window and press Return.
4. Optional: see what the installer would do without changing anything: `./install.sh --dry-run`
5. Run the installer: `./install.sh`
6. Type `y` when it asks to continue, then your Mac password when `sudo` asks.
7. Open a new Terminal window, so the PATH change is picked up.
8. Type `nosleep` to see the status line. You are done.

`./install.sh --no-lidlock` installs the command without the lid-close screen-lock helper. Not recommended: with nosleep on, a closed lid would then leave the screen lit and unlocked.

## Use

```
nosleep -on        # about to close the lid; keep working
nosleep            # status: on (SleepDisabled=1)
nosleep -off       # done; back to normal
nosleep -sleep     # back to normal and go to sleep right now
```

Over SSH, `nosleep -sleep` is a one-way door: waking the Mac again needs a physical lid-open or key press.

## Things to know

- **While nosleep is on, the Mac never sleeps.** The battery drains, and it gets warm. Do not put it, closed and on, into a bag or under a pillow. Turn it off when you are done.
- **The setting survives a restart.** `pmset` settings persist. If you restart with nosleep on, it is still on afterwards. Plain `nosleep` tells you.
- **The lid-close lock depends on your lock-screen setting.** In System Settings, go to Lock Screen and set "Require password after screen saver begins or display is turned off" to "Immediately" (or a short delay). The helper only turns the display off; macOS does the locking.
- **External monitor in clamshell mode.** The helper also blanks an external display when the lid closes. To use the Mac closed with a monitor, pause the helper with the first command below and resume it with the second:

```
launchctl bootout gui/$(id -u)/local.nosleep.lidlock
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.nosleep.lidlock.plist
```

## Troubleshooting

- `command not found: nosleep`: open a new Terminal window. If it still fails, add `export PATH="$HOME/.local/bin:$PATH"` to your `~/.zshrc`.
- `operation not permitted` when running `./install.sh`: macOS quarantines downloaded files. In the folder, run `xattr -dr com.apple.quarantine .` and try again.
- `status: SleepDisabled=1 but nosleep did not set it`: something else disabled sleep (or the marker file was deleted). `nosleep -off` clears it either way.
- Is the lid helper running? `pgrep -fl lidlock-watch` should print one line.

## Uninstall

Run `./uninstall.sh` from the folder. It restores normal sleep if nosleep is on, stops and removes the LaunchAgent, deletes the two commands, and removes the `sudo` rule. By hand, the same thing is:

```
nosleep -off
launchctl bootout gui/$(id -u)/local.nosleep.lidlock
rm ~/Library/LaunchAgents/local.nosleep.lidlock.plist ~/.local/bin/lidlock-watch ~/.local/bin/nosleep ~/.local/state/nosleep.on
sudo rm /etc/sudoers.d/nosleep
```

## What gets installed where

| File | Purpose |
|---|---|
| `~/.local/bin/nosleep` | the command |
| `~/.local/bin/lidlock-watch` | the lid-close screen-lock helper |
| `~/Library/LaunchAgents/local.nosleep.lidlock.plist` | starts the helper at login and keeps it running |
| `/etc/sudoers.d/nosleep` | lets your account run the three `pmset` commands without a password |
| `~/.local/state/nosleep.on` | marker file, present only while nosleep is on |

## License

MIT. See `LICENSE`.
