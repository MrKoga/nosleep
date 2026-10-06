# nosleep menu bar item

A menu bar indicator for `nosleep`, the terminal command (in the folder this one is inside) that keeps a MacBook running with the lid closed. It puts a small box at the top of the screen: an outlined "nosleep OFF", or an orange "nosleep ON". Click it to turn nosleep on or off without opening a terminal.

![the two states, OFF and ON](docs/menubar.png)

## What you need

- **nosleep installed.** Run the installer in the folder above this one (the `nosleep` folder) first. Without it, the menu bar item shows "nosleep ?".
- **SwiftBar.** A free, open-source app that shows the output of small scripts in the menu bar (https://github.com/swiftbar/SwiftBar). The installer offers to install it with Homebrew if you have Homebrew; otherwise download it from https://github.com/swiftbar/SwiftBar/releases and move it to Applications before you start.
- macOS 11 or newer.

## Install

1. Get the files if you have not already. They are in the `menubar` folder of https://github.com/mrkoga/nosleep: download the zip from the green "Code" button there, or run `git clone https://github.com/mrkoga/nosleep.git`.
2. Open Terminal.
3. Move into this folder: type `cd` followed by a space, drag this `menubar` folder onto the Terminal window, and press Return.
4. Optional: see what the installer would do without changing anything: `./install.sh --dry-run`
5. Run the installer: `./install.sh`
6. Answer its questions: whether to install SwiftBar with Homebrew (if it is missing), and whether SwiftBar should start when you log in.
7. If SwiftBar was just installed, macOS may ask whether to open an app downloaded from the internet. Click Open.
8. Look at the top right of your screen for the "nosleep OFF" box.

Do not point SwiftBar at this unzipped folder as its plugin folder. SwiftBar runs every file in its plugin folder, so the installer copies only the one plugin file into it.

## Use

- Click the box. The dropdown shows one plain-words status line, the raw `pmset SleepDisabled` value, a "Turn nosleep ON" or "Turn nosleep OFF" button, and Refresh.
- Turning it on or off from the terminal (`nosleep -on`, `nosleep -off`) updates the box right away; anything else that changes the setting shows up within 10 seconds.
- The dropdown buttons run the `nosleep` command directly, with no terminal window and no password prompt, because nosleep's installer added a `sudo` rule for exactly those calls.

## How it works

SwiftBar runs `nosleep.10s.sh` every 10 seconds (the `.10s` in the file name sets the interval) and shows whatever it prints. The script reads the one number that matters, `SleepDisabled` in the output of `pmset -g` (1 means the Mac will not sleep, 0 means normal), and prints the matching image and dropdown. The two box images are pre-drawn PNGs embedded in the script as base64, so nothing else needs to be installed. The OFF image is a "template image" (black on clear), which macOS recolors to match a light or dark menu bar; the ON image is orange with dark text.

## Settings

Two lines near the top of the plugin file (in SwiftBar's plugin folder, not this folder) can be edited; SwiftBar reloads the file when it changes:

- `STYLE="box"` draws the image labels shown above. `STYLE="text"` uses plain text with an icon instead ("nosleep ON" with an eye, "nosleep OFF" with a moon).
- `NOSLEEP="$HOME/.local/bin/nosleep"` is where the nosleep command lives. Change it only if you installed nosleep somewhere else.

## Troubleshooting

- **Nothing appears.** Is SwiftBar running (its icon or any plugin in the menu bar)? Check the plugin folder it uses with `defaults read com.ameba.SwiftBar PluginDirectory` and confirm `nosleep.10s.sh` is in it.
- **A box with a question mark.** The plugin hit an error. Click the box and choose "Show Error".
- **"nosleep ?".** The nosleep command is not at `~/.local/bin/nosleep`. Install it from the folder above this one, or edit the `NOSLEEP` line.
- **Two nosleep items.** Another `nosleep.*` file is in the plugin folder. Remove one.
- **Clicking "Turn nosleep ON" does nothing.** The `sudo` rule from nosleep's installer is missing, so the command is silently asking for a password. Run nosleep's `install.sh` again.
- **The lid helper and an external monitor.** See the nosleep README; the menu bar item has no part in that.

## Uninstall

Run `./uninstall.sh` from this folder. It removes the plugin file from SwiftBar's plugin folder and leaves SwiftBar installed. By hand: delete `nosleep.10s.sh` from the folder shown by `defaults read com.ameba.SwiftBar PluginDirectory`.

## License

MIT. See `LICENSE`.
