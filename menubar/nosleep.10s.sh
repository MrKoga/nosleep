#!/bin/bash
# nosleep.10s.sh — SwiftBar plugin: shows in the menu bar whether `nosleep` is ON or OFF.
#
# Companion to nosleep (the folder this one came inside of), the terminal
# command that keeps a MacBook running with the lid closed. This shows a small boxed label at the top
# of the screen, an outlined box reading "nosleep OFF" or an orange box reading
# "nosleep ON", and its dropdown turns nosleep on or off.
#
# How it decides: it reads the one number that matters, SleepDisabled in `pmset -g`
# (1 = the Mac will not sleep, 0 = normal). SwiftBar re-runs this file every 10 seconds
# (the ".10s" in the filename), and the nosleep command pokes SwiftBar to refresh the
# moment it changes state. Nothing to install beyond SwiftBar and macOS: the two box
# images are pre-rendered PNGs embedded at the bottom of this file as base64.
#
# Settings you can change:
STYLE="box"                          # "box" = the image labels; "text" = plain text with an icon
NOSLEEP="$HOME/.local/bin/nosleep"   # where the nosleep command is installed
#
# <swiftbar.title>nosleep status</swiftbar.title>
# <swiftbar.version>2.0</swiftbar.version>
# <swiftbar.author>Evan Koga</swiftbar.author>
# <swiftbar.author.github>mrkoga</swiftbar.author.github>
# <swiftbar.abouturl>https://github.com/mrkoga/nosleep</swiftbar.abouturl>
# <swiftbar.desc>Shows whether nosleep (pmset disablesleep) is on or off, and turns it on or off from the dropdown.</swiftbar.desc>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>

MARKER="$HOME/.local/state/nosleep.on"   # nosleep leaves this file behind while it is on

sleep_disabled=$(/usr/bin/pmset -g 2>/dev/null | /usr/bin/awk '/SleepDisabled/{print $2}')
[ -z "$sleep_disabled" ] && sleep_disabled="?"

# The menu bar title. $1 is ON or OFF. The OFF image is a "template image" (black on
# clear), which macOS recolors to match a light or dark menu bar; the ON image is orange.
title() {
  if [ "$STYLE" = "box" ]; then
    if [ "$1" = "ON" ]; then echo "| image=$ON_PNG tooltip=nosleep is ON"
    else echo "| templateImage=$OFF_PNG tooltip=nosleep is OFF"; fi
  else
    if [ "$1" = "ON" ]; then echo "nosleep ON | sfimage=eye color=orange"
    else echo "nosleep OFF | sfimage=moon.zzz"; fi
  fi
}

main() {
  if [ ! -x "$NOSLEEP" ]; then
    echo "nosleep ? | sfimage=questionmark.square"
    echo "---"
    echo "The nosleep command is not installed (looked for $NOSLEEP)"
    echo "Install it from the nosleep folder this menu bar item came in"
    echo "pmset SleepDisabled = $sleep_disabled | font=Menlo size=11"
    echo "---"
    echo "Refresh | refresh=true"
    return
  fi

  # Dropdown actions run the nosleep command directly, with no terminal window. They
  # need no password because nosleep's installer added a sudo rule for exactly these calls.
  on_action="bash=$NOSLEEP param1=-on terminal=false refresh=true"
  off_action="bash=$NOSLEEP param1=-off terminal=false refresh=true"

  if [ "$sleep_disabled" = "1" ]; then
    title ON
    echo "---"
    echo "nosleep is ON"
    if [ -f "$MARKER" ]; then
      echo "The Mac keeps running through every lid close until you turn it off"
    else
      echo "Sleep is disabled, but not by nosleep. 'Turn nosleep OFF' below restores normal sleep"
    fi
    echo "pmset SleepDisabled = $sleep_disabled | font=Menlo size=11"
    echo "---"
    echo "Turn nosleep OFF (normal sleep) | $off_action"
  else
    title OFF
    echo "---"
    echo "nosleep is OFF"
    if [ -f "$MARKER" ]; then
      echo "Normal sleep, but a stale nosleep marker file was left behind. 'Turn nosleep OFF' below clears it"
    else
      echo "Normal sleep behavior (closing the lid sleeps the Mac)"
    fi
    echo "pmset SleepDisabled = $sleep_disabled | font=Menlo size=11"
    echo "---"
    echo "Turn nosleep ON (stay awake with the lid closed) | $on_action"
    [ -f "$MARKER" ] && echo "Turn nosleep OFF (clear the stale marker) | $off_action"
  fi
  echo "---"
  echo "Refresh | refresh=true"
}

# The two menu bar images: 12 pt San Francisco text in an 18 pt rounded box, drawn at 2x
# for Retina screens, as PNG in base64. See docs/menubar.png for what they look like.
ON_PNG='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'
OFF_PNG='iVBORw0KGgoAAAANSUhEUgAAAJoAAAAmCAYAAAA894IZAAAACXBIWXMAABYlAAAWJQFJUiTwAAAFPklEQVR4nO2cWYgcRRjHf7smahLPVTHxiKtGvEGDIEbxvhdFhDyIigqi8UAwKEL0QdEXlQgKXg8iwSPgQURiJEFXHzQ+eOTFA4xJNPEMGzVx13Vz7EjBv0Jtp6q7pqdnHGfqD81uf8dUdfW/vvrqq92BhIQWoCdHV2tFBxK6g1M+YSJYQhWYwK3ejDKRLKEq1EKsq9WxrCYkhODlkY1oiWQJVSEboGq+pdNnmJBQL3p8AjeaJZIlVImd3PJFtISEypGIltAS9HZQiDbXdDoHFwOvAGuBUeAfYB3wKnBJ5HgUXQ826BONSWWcEpqKvYCXgKsc2Yhecr+ua4C3gOuB4ZzP+gUYz9FvqcgnCi5b/6/olIg2FVilZ/kDeAA4xNHPABYAv8vmC2BKRePRjDGcwK1EtPbBk3ofG4ATcuyOA9bLdqFHn4jWJHRCRDsS2KHnuCDC/nzZGp+Z7U60spsBt1Mml1gJ/AVsBpYBpwb8TH7xNLBGCa5Jbl8Ajg3YnwQsBn4FxpQYPw7sU0dfD1OkWK021ysHOrkiH3csjtfzm7xpCFgRSRqDudqcvQe8TzEGZdsr37ZHmaXT2j+in2MimZUPe17KWU5uYa5NSjqt/UDGfo5esrV3fb8G9ouYjacBG6Ub18u3UWM0k3CX9bFtX6mdYfbZxoF5EWP6gexvIx63y2ew3SPaLjd1fsA2YD6wh+SnKAoY3duOvSHFz5K/pqTWYH/gGcn/zCS+KyV/E+iT7AjgM8kfKhikaYqYRv4icLDTl4WSb860WcbHtm0IudRZxkyfn3Mm4jEFY7pGtmcQjznyMWPe0UR7yqO7Qrq/nTrdfZIZkviW66XSm2XRwkazWZ7BHRIB8wbpLslCy9AS6R9u0MeNspM9Pu9Kb1KGPAzL7ijicbR8TNqCp09mcv8YuOZX4NMyop3u0R3o6A/IRKcbAp93mfTfObLvJbu5jv64RPtQsqsDPgPSr2rQx7Z9a8DnculNpKyaaLMKiFZP4bWMT8uIdmjki/9N9ycG7C05TS60m2TzJNuu4uSN2kzEtGcLj1bum51u7teIj5WFNhcHeZ7NBzPJ0tIZ8WLz9Ft1b3ZzPkx2fEzeZmES708zk8EsUbdE9Me2GXM14lOr49n6CGNQNncQjzsDS33R+/GhjE/bEc1GNFOuyJv12wM5nImc1wEvOzu7xwr6szGQ4+WhjE9VEe0e2ZmSRSwsOe8O9KnriPaR7m8qyNG+jWj7PGezMSmnP59I5ithhFDGpyhHG5De1ADz0O+UUS6KaPdCZ3IeHuhT1xHtXt1/HohYy6R/1CmTmJzo48Chs/38vXP6s6AgQph61ZfA8w362La/AXb3+CzP2aFn8YSTHxYdQW3wRHa6nWj7Aj9J9nqmjvasU0eb4eQ17kCa+patZ9m621cF/enTiYKRL3JqX1OV49ld3twGfWzbW1TKmOk8m62jjUbuJqdoMtpD9fszNbvpKhVtcibunhHj3zVEMzgzU913K+4jKgNkl9NtzvIw5PiaF3dORH/O9pxG2DZriiA06GPl16qf2ZOBHTkpgw/TnHqdvYZVwnBlS5wJGDP+XUM096xzrZL6H1SBN2eEPswG3tBmYquWlEVaOmL7069la7XaNCR6R0diIdTj47Y9W+ebI/Ixv59LOVyqP3Jcp5OFMdUWF0uXh44hWkJzX1CnYCe3OuVPuRPaHIloCS0jWt7XIiQklIXLpZ6eAMHSPxInNIJd+NSb930JCQkl4A1aiWAJzURPaDOQlsyEqjCBS+mrRROqRgpWCfxn+Bd/mvnhciV1DgAAAABJRU5ErkJggg=='

main
