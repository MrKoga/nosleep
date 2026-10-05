#!/bin/bash
# install.sh — installs nosleep on this Mac. See README.md for what it does.
set -euo pipefail

usage() {
  cat <<USAGE
usage: ./install.sh [--no-lidlock] [--dry-run] [--yes]
  --no-lidlock   skip the lid-close screen-lock helper (not recommended; see README)
  --dry-run      show exactly what would be done and validate the generated files,
                 but change nothing
  --yes, -y      do not ask for confirmation
USAGE
}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ME="$(id -un)"
MY_UID="$(id -u)"
BIN="$HOME/.local/bin"
STATE_DIR="$HOME/.local/state"
AGENT_LABEL="local.nosleep.lidlock"
AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST="$AGENT_DIR/$AGENT_LABEL.plist"
SUDOERS_DST="/etc/sudoers.d/nosleep"
SUDOERS_RULE="$ME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset sleepnow"

LIDLOCK=1; DRY=0; YES=0
for arg in "$@"; do
  case "$arg" in
    --no-lidlock) LIDLOCK=0 ;;
    --dry-run)    DRY=1 ;;
    --yes|-y)     YES=1 ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "install.sh: unknown option '$arg'" >&2; usage >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }
run() { if [ "$DRY" = 1 ]; then say "   (dry run) $*"; else "$@"; fi; }

TMP_SUDOERS="$(mktemp)"; TMP_PLIST="$(mktemp)"
trap 'rm -f "$TMP_SUDOERS" "$TMP_PLIST"' EXIT

# ---- preflight --------------------------------------------------------------
[ "$(uname -s)" = Darwin ] || die "this is a macOS tool (uname says $(uname -s))"
[ -x /usr/bin/pmset ] || die "/usr/bin/pmset not found"
command -v visudo >/dev/null || die "visudo not found"
[ -f "$HERE/bin/nosleep" ] && [ -f "$HERE/bin/lidlock-watch" ] || die "run this from the unzipped nosleep folder (bin/nosleep is missing)"
groups "$ME" | tr ' ' '\n' | grep -qx admin || die "your account ($ME) is not an administrator; the installer needs sudo"

# ---- plan -------------------------------------------------------------------
say "nosleep installer"
say ""
say "This will:"
say "  1. copy bin/nosleep to $BIN/nosleep"
say "  2. add $SUDOERS_DST so that '$ME' can run these three commands"
say "     without a password (and nothing else):"
say "       /usr/bin/pmset -a disablesleep 1"
say "       /usr/bin/pmset -a disablesleep 0"
say "       /usr/bin/pmset sleepnow"
if [ "$LIDLOCK" = 1 ]; then
  say "  3. copy bin/lidlock-watch to $BIN/lidlock-watch and start it as the"
  say "     LaunchAgent $AGENT_LABEL (turns the screen off, which locks it,"
  say "     when you close the lid while nosleep is on)"
else
  say "  3. (skipped) the lid-close screen-lock helper (--no-lidlock)"
fi
say "  4. make sure $BIN is on your PATH"
say ""
say "You will be asked for your Mac password once, for step 2."
[ "$DRY" = 1 ] && say "DRY RUN: nothing will be changed."
if [ "$YES" = 0 ] && [ "$DRY" = 0 ]; then
  read -r -p "Continue? [y/N] " answer
  case "$answer" in y|Y|yes|YES) ;; *) say "aborted"; exit 1 ;; esac
fi
say ""

# ---- 1. the nosleep command -------------------------------------------------
say "1. installing $BIN/nosleep"
run mkdir -p "$BIN" "$STATE_DIR"
run install -m 0755 "$HERE/bin/nosleep" "$BIN/nosleep"
[ "$DRY" = 1 ] || xattr -d com.apple.quarantine "$BIN/nosleep" 2>/dev/null || true

# ---- 2. the passwordless sudo rule ------------------------------------------
say "2. installing $SUDOERS_DST"
{
  echo "# nosleep: let $ME flip the macOS sleep switch without a password."
  echo "# Installed by nosleep's install.sh; removed by its uninstall.sh."
  echo "$SUDOERS_RULE"
} > "$TMP_SUDOERS"
visudo -cf "$TMP_SUDOERS" >/dev/null || die "the generated sudoers rule failed validation (a bug in this installer; nothing was installed)"
if [ "$DRY" = 1 ]; then
  say "   (dry run) would install this file as root:wheel mode 0440:"
  sed 's/^/      | /' "$TMP_SUDOERS"
else
  sudo install -o root -g wheel -m 0440 "$TMP_SUDOERS" "$SUDOERS_DST"
  if ! sudo visudo -c >/dev/null 2>&1; then
    sudo rm -f "$SUDOERS_DST"
    die "sudo configuration failed validation after adding the rule, so the rule was removed again"
  fi
  sudo -K
  if sudo -n -l /usr/bin/pmset -a disablesleep 1 >/dev/null 2>&1; then
    say "   passwordless rule verified"
  else
    die "the rule was installed but 'sudo -n pmset' still asks for a password; check $SUDOERS_DST"
  fi
fi

# ---- 3. the lid-close screen-lock helper ------------------------------------
if [ "$LIDLOCK" = 1 ]; then
  say "3. installing the lid-close screen-lock helper"
  run install -m 0755 "$HERE/bin/lidlock-watch" "$BIN/lidlock-watch"
  [ "$DRY" = 1 ] || xattr -d com.apple.quarantine "$BIN/lidlock-watch" 2>/dev/null || true
  cat > "$TMP_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$AGENT_LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$BIN/lidlock-watch</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
EOF
  plutil -lint "$TMP_PLIST" >/dev/null || die "the generated LaunchAgent plist failed validation (a bug in this installer)"
  if [ "$DRY" = 1 ]; then
    say "   (dry run) would write $PLIST:"
    sed 's/^/      | /' "$TMP_PLIST"
    say "   (dry run) launchctl bootstrap gui/$MY_UID $PLIST"
  else
    mkdir -p "$AGENT_DIR"
    launchctl bootout "gui/$MY_UID/$AGENT_LABEL" 2>/dev/null || true
    install -m 0644 "$TMP_PLIST" "$PLIST"
    launchctl bootstrap "gui/$MY_UID" "$PLIST"
    sleep 1
    if pgrep -f "$BIN/lidlock-watch" >/dev/null; then
      say "   lidlock-watch is running"
    else
      die "lidlock-watch did not start; check: launchctl print gui/$MY_UID/$AGENT_LABEL"
    fi
  fi
fi

# ---- 4. PATH ----------------------------------------------------------------
say "4. checking PATH"
case ":$PATH:" in
  *":$BIN:"*) say "   $BIN is already on your PATH" ;;
  *)
    case "$(basename "${SHELL:-/bin/zsh}")" in
      bash) RC="$HOME/.bash_profile" ;;
      *)    RC="$HOME/.zshrc" ;;
    esac
    LINE='export PATH="$HOME/.local/bin:$PATH"'
    if [ -f "$RC" ] && grep -qF "$LINE" "$RC"; then
      say "   $RC already has the PATH line"
    elif [ "$DRY" = 1 ]; then
      say "   (dry run) would append to $RC: $LINE"
    else
      printf '\n# added by nosleep install.sh\n%s\n' "$LINE" >> "$RC"
      say "   added to $RC: $LINE"
    fi
    say "   open a new terminal window (or run: source $RC) before typing 'nosleep'"
    ;;
esac

say ""
if [ "$DRY" = 1 ]; then
  say "dry run complete; nothing was changed."
else
  say "done. Try it:"
  say "  nosleep          show status"
  say "  nosleep -on      keep the Mac running with the lid closed"
  say "  nosleep -off     back to normal"
  say ""
  "$BIN/nosleep"
fi
