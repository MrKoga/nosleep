#!/bin/bash
# uninstall.sh — removes the nosleep menu bar item. Leaves SwiftBar itself installed.
# usage: ./uninstall.sh [PLUGIN_DIR]   (the folder is read from SwiftBar's settings if omitted)
set -uo pipefail

BUNDLE_ID="com.ameba.SwiftBar"
PLUGIN_DIR="${1:-$(defaults read "$BUNDLE_ID" PluginDirectory 2>/dev/null)}"
[ -n "$PLUGIN_DIR" ] || { echo "uninstall.sh: could not find SwiftBar's plugin folder; pass it as the first argument" >&2; exit 1; }
DST="$PLUGIN_DIR/nosleep.10s.sh"

if [ -e "$DST" ]; then
  rm -f "$DST" && echo "removed $DST"
else
  echo "nothing to remove: $DST does not exist"
fi
pgrep -xq SwiftBar && open -g "swiftbar://refreshallplugins"
echo "SwiftBar itself was left installed. To remove it too: 'brew uninstall --cask swiftbar' (or drag"
echo "SwiftBar from Applications to the Trash), and take it out of System Settings > General > Login Items."
