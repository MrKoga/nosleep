#!/bin/bash
# uninstall.sh — removes everything install.sh put on this Mac.
set -uo pipefail

MY_UID="$(id -u)"
BIN="$HOME/.local/bin"
AGENT_LABEL="local.nosleep.lidlock"
PLIST="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
SUDOERS_DST="/etc/sudoers.d/nosleep"
MARKER="$HOME/.local/state/nosleep.on"

say() { printf '%s\n' "$*"; }
sleep_disabled() { pmset -g | awk '/SleepDisabled/{print $2}'; }

say "nosleep uninstaller"
say ""
say "This removes: $BIN/nosleep, $BIN/lidlock-watch, the $AGENT_LABEL LaunchAgent,"
say "and $SUDOERS_DST. It first restores normal sleep if nosleep is on."
say "You will be asked for your Mac password."
read -r -p "Continue? [y/N] " answer
case "$answer" in y|Y|yes|YES) ;; *) say "aborted"; exit 1 ;; esac
say ""

# 1. restore normal sleep (uses the passwordless rule while it still exists)
if [ "$(sleep_disabled)" = "1" ]; then
  say "1. restoring normal sleep"
  sudo /usr/bin/pmset -a disablesleep 0
else
  say "1. normal sleep is already in effect"
fi
rm -f "$MARKER"

# 2. the lid-close screen-lock helper
say "2. removing the lid-close screen-lock helper"
launchctl bootout "gui/$MY_UID/$AGENT_LABEL" 2>/dev/null || true
rm -f "$PLIST" "$BIN/lidlock-watch"

# 3. the command
say "3. removing $BIN/nosleep"
rm -f "$BIN/nosleep"

# 4. the sudo rule (last, because step 1 may have needed it)
say "4. removing $SUDOERS_DST"
sudo rm -f "$SUDOERS_DST"

say ""
say "done. SleepDisabled is now: $(sleep_disabled)"
say "If install.sh added a PATH line to your ~/.zshrc or ~/.bash_profile, it was left in place (harmless)."
