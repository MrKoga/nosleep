#!/bin/bash
# install.sh — installs the nosleep menu bar item (a SwiftBar plugin). See README.md.
set -euo pipefail

usage() {
  cat <<USAGE
usage: ./install.sh [--plugin-dir DIR] [--dry-run] [--yes]
  --plugin-dir DIR  put the plugin in this folder instead of SwiftBar's configured one
  --dry-run         show what would be done and change nothing
  --yes, -y         answer yes to every question (install SwiftBar with Homebrew if it
                    is missing, replace an existing copy of the plugin, start SwiftBar
                    at login)
USAGE
}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/nosleep.10s.sh"
BUNDLE_ID="com.ameba.SwiftBar"
DEFAULT_DIR="$HOME/Library/Application Support/SwiftBar/Plugins"
NOSLEEP="$HOME/.local/bin/nosleep"
PLUGIN_DIR=""; DRY=0; YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --plugin-dir) [ $# -ge 2 ] || { echo "install.sh: --plugin-dir needs a folder" >&2; exit 2; }; PLUGIN_DIR="$2"; shift 2 ;;
    --dry-run)    DRY=1; shift ;;
    --yes|-y)     YES=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "install.sh: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }
run() { if [ "$DRY" = 1 ]; then say "   (dry run) $*"; else "$@"; fi; }
ask() {   # $1 = question; yes/no, default no
  if [ "$YES" = 1 ]; then return 0; fi
  local q="$1"; q="${q#"${q%%[![:space:]]*}"}"   # the question without its leading spaces
  if [ "$DRY" = 1 ]; then say "   (dry run) would ask: $q (assuming yes)"; return 0; fi
  read -r -p "   $q [y/N] " answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
find_swiftbar() {
  local p
  for p in /Applications/SwiftBar.app "$HOME/Applications/SwiftBar.app"; do
    [ -d "$p" ] && { printf '%s\n' "$p"; return 0; }
  done
  p="$(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'" 2>/dev/null | head -1)"
  [ -n "$p" ] && { printf '%s\n' "$p"; return 0; }
  return 1
}

# ---- preflight --------------------------------------------------------------
[ "$(uname -s)" = Darwin ] || die "this is a macOS tool (uname says $(uname -s))"
[ -f "$SRC" ] || die "nosleep.10s.sh is missing next to this installer; run it from the unzipped menubar folder"

say "nosleep menu bar item installer"
say ""
say "This puts one small script, nosleep.10s.sh, into SwiftBar's plugin folder. SwiftBar"
say "(a free menu bar app) runs it every 10 seconds and shows the result at the top of"
say "the screen: an outlined box 'nosleep OFF', or an orange box 'nosleep ON'."
[ "$DRY" = 1 ] && say "DRY RUN: nothing will be changed."
say ""

# ---- 1. the nosleep command -------------------------------------------------
if [ -x "$NOSLEEP" ]; then
  say "1. nosleep command found at $NOSLEEP"
else
  say "1. WARNING: the nosleep command is not at $NOSLEEP."
  say "   The menu bar item will show 'nosleep ?' until you install it: run install.sh"
  say "   in the nosleep folder (the folder above this one)."
fi

# ---- 2. SwiftBar ------------------------------------------------------------
APP="$(find_swiftbar || true)"
if [ -n "$APP" ]; then
  say "2. SwiftBar found at $APP"
else
  say "2. SwiftBar is not installed."
  if command -v brew >/dev/null 2>&1; then
    if ask "Install it now with Homebrew (brew install --cask swiftbar)?"; then
      run brew install --cask swiftbar
      if [ "$DRY" = 0 ]; then
        APP="$(find_swiftbar || true)"
        [ -n "$APP" ] || die "Homebrew finished but SwiftBar.app was not found"
      fi
    else
      die "install SwiftBar first (brew install --cask swiftbar, or download it from https://github.com/swiftbar/SwiftBar/releases and move it to /Applications), then run this again"
    fi
  else
    die "install SwiftBar first: download it from https://github.com/swiftbar/SwiftBar/releases, move it to /Applications, then run this again"
  fi
fi

# ---- 3. the plugin folder ---------------------------------------------------
SET_DIR=0
if [ -z "$PLUGIN_DIR" ]; then
  PLUGIN_DIR="$(defaults read "$BUNDLE_ID" PluginDirectory 2>/dev/null || true)"
  if [ -n "$PLUGIN_DIR" ]; then
    say "3. SwiftBar's plugin folder is $PLUGIN_DIR"
  else
    PLUGIN_DIR="$DEFAULT_DIR"; SET_DIR=1
    say "3. SwiftBar has no plugin folder yet; setting it to $PLUGIN_DIR"
    run mkdir -p "$PLUGIN_DIR"
    run defaults write "$BUNDLE_ID" PluginDirectory -string "$PLUGIN_DIR"
  fi
else
  say "3. using the plugin folder $PLUGIN_DIR (from --plugin-dir)"
  run mkdir -p "$PLUGIN_DIR"
  CURRENT="$(defaults read "$BUNDLE_ID" PluginDirectory 2>/dev/null || true)"
  if [ -n "$CURRENT" ] && [ "$CURRENT" != "$PLUGIN_DIR" ]; then
    say "   note: SwiftBar is set to load plugins from $CURRENT, not from this folder"
  fi
fi
[ "$DRY" = 1 ] || [ -d "$PLUGIN_DIR" ] || die "the plugin folder $PLUGIN_DIR does not exist"

# ---- 4. copy the plugin in --------------------------------------------------
DST="$PLUGIN_DIR/nosleep.10s.sh"
say "4. installing $DST"
if [ -e "$DST" ] && ! cmp -s "$SRC" "$DST"; then
  ask "A different nosleep.10s.sh is already there. Replace it?" || die "left the existing plugin alone"
fi
for f in "$PLUGIN_DIR"/nosleep.*; do
  [ -e "$f" ] && [ "$f" != "$DST" ] && say "   note: $f also exists, so SwiftBar will show two nosleep items; remove it if you only want one"
done
run install -m 0755 "$SRC" "$DST"
[ "$DRY" = 1 ] || xattr -d com.apple.quarantine "$DST" 2>/dev/null || true

# ---- 5. start or refresh SwiftBar -------------------------------------------
if pgrep -xq SwiftBar; then
  if [ "$SET_DIR" = 1 ]; then
    say "5. restarting SwiftBar so it notices its new plugin folder"
    run osascript -e 'quit app "SwiftBar"'
    run sleep 1
    run open -a SwiftBar
  else
    say "5. asking SwiftBar to reload its plugins"
    run open -g "swiftbar://refreshallplugins"
  fi
else
  say "5. starting SwiftBar"
  run open -a SwiftBar
fi
if osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | tr ',' '\n' | grep -q SwiftBar; then
  say "   SwiftBar already starts at login"
elif ask "Start SwiftBar automatically when you log in?"; then
  run osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP\", hidden:false}" >/dev/null \
    || say "   could not add the login item (macOS may have blocked it); use SwiftBar's Preferences > Launch at Login instead"
fi

# ---- 6. check ---------------------------------------------------------------
say ""
if [ "$DRY" = 1 ]; then
  say "dry run complete; nothing was changed."
else
  if "$DST" | sed -n 2p | grep -q '^---$'; then
    say "the plugin runs correctly."
  else
    die "the plugin did not produce menu output; run it yourself to see why: $DST"
  fi
  say "done. Look at the top right of your screen for the nosleep box. If SwiftBar was just"
  say "installed, macOS may first ask whether to open an app downloaded from the internet;"
  say "click Open. A box with a question mark means the plugin hit an error: click it and"
  say "choose 'Show Error'."
fi
