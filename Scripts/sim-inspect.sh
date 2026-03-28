#!/usr/bin/env bash
# sim-inspect.sh — Build, install, launch, and screenshot ZenSocial in the iOS Simulator.
# Usage:
#   ./Scripts/sim-inspect.sh                       # build + install + launch + screenshot
#   ./Scripts/sim-inspect.sh screenshot            # screenshot only (app already running)
#   ./Scripts/sim-inspect.sh tap <x> <y>           # tap at coordinates (unreliable on Metal windows)
#   ./Scripts/sim-inspect.sh scroll <x> <y> <dx> <dy>  # swipe gesture
#   ./Scripts/sim-inspect.sh navigate <platform>   # set UserDefaults + relaunch to platform (instagram|youtube|home)
#   ./Scripts/sim-inspect.sh watch [interval]      # screenshot loop every N seconds (default 3), Ctrl+C to stop
#   ./Scripts/sim-inspect.sh winpos                # print simulator window position and suggested tap coords

set -euo pipefail

DEVICE_ID="15796420-57AA-4732-BE47-5AB2F98B7626"  # iPhone 17
BUNDLE_ID="com.zensocial.app"
SCHEME="ZenSocial"
PROJECT="ZenSocial.xcodeproj"
SCREENSHOT_DIR="/tmp/zensocial-sim"
mkdir -p "$SCREENSHOT_DIR"

CMD="${1:-build}"

case "$CMD" in
  screenshot)
    TS=$(date +%H%M%S)
    OUT="$SCREENSHOT_DIR/screen-$TS.png"
    xcrun simctl io booted screenshot "$OUT"
    echo "$OUT"
    ;;

  tap)
    # Converts device logical points → screen coordinates and clicks via cliclick.
    # Requires: cliclick installed (brew install cliclick), Simulator window on primary display.
    # Usage: ./Scripts/sim-inspect.sh tap <device_x> <device_y>
    # Device points for iPhone 17: 402x874
    # NOTE: cliclick is unreliable on Simulator — the Metal-rendered window doesn't respond to
    # synthetic mouse events. Use `navigate` for tab switching instead.
    # Run `./Scripts/sim-inspect.sh winpos` first to verify window position.
    DEVICE_X="${2:?tap requires device_x}"
    DEVICE_Y="${3:?tap requires device_y}"
    WIN_POS=$(osascript -e 'tell application "System Events" to tell process "Simulator" to get position of front window')
    WIN_W=$(osascript -e 'tell application "System Events" to tell process "Simulator" to get item 1 of size of front window')
    WIN_X=$(echo "$WIN_POS" | cut -d, -f1 | tr -d ' ')
    WIN_Y=$(echo "$WIN_POS" | cut -d, -f2 | tr -d ' ')
    # Chrome offsets (iPhone 17): 27px left bezel, 49px top bezel
    SCREEN_X=$(( WIN_X + 27 + DEVICE_X ))
    SCREEN_Y=$(( WIN_Y + 49 + DEVICE_Y ))
    osascript -e 'tell application "Simulator" to activate' 2>/dev/null
    sleep 0.3
    cliclick c:${SCREEN_X},${SCREEN_Y}
    sleep 1
    TS=$(date +%H%M%S)
    OUT="$SCREENSHOT_DIR/screen-$TS.png"
    xcrun simctl io booted screenshot "$OUT"
    echo "$OUT"
    ;;

  winpos)
    WIN_POS=$(osascript -e 'tell application "System Events" to tell process "Simulator" to get position of front window')
    WIN_SZ=$(osascript -e 'tell application "System Events" to tell process "Simulator" to get size of front window')
    echo "Window position: $WIN_POS  size: $WIN_SZ"
    python3 -c "
pos = '$WIN_POS'.split(', ')
sz = '$WIN_SZ'.split(', ')
wx, wy = int(pos[0]), int(pos[1])
print(f'Instagram button → screen: {wx+27+160}, {wy+49+262}')
print(f'YouTube button  → screen: {wx+27+160}, {wy+49+430}')
print(f'Window center   → screen: {wx+228}, {wy+486}')
"
    ;;

  swipe)
    X="${2:?swipe requires x}"
    Y="${3:?swipe requires y}"
    DX="${4:-0}"
    DY="${5:--200}"
    ENDX=$(( X + DX ))
    ENDY=$(( Y + DY ))
    xcrun simctl io booted swipe "$X" "$Y" "$ENDX" "$ENDY"
    sleep 0.5
    TS=$(date +%H%M%S)
    OUT="$SCREENSHOT_DIR/screen-$TS.png"
    xcrun simctl io booted screenshot "$OUT"
    echo "$OUT"
    ;;

  navigate)
    # Navigate to a platform tab by writing to the app's UserDefaults and relaunching.
    # Exploits NavigationState.restoreLastPlatform() which reads @AppStorage("lastPlatform") on init.
    # No simulator coordinate clicking needed — reliable across all window positions.
    PLATFORM="${2:?navigate requires platform (instagram|youtube|home)}"
    echo "==> Setting lastPlatform to '$PLATFORM'..."
    xcrun simctl spawn booted defaults write com.zensocial.app lastPlatform "$PLATFORM"
    echo "==> Terminating app..."
    xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
    sleep 0.5
    echo "==> Relaunching app..."
    xcrun simctl launch booted "$BUNDLE_ID"
    # 8s: UA extraction + WKWebView init + web content render
    # Pass a custom wait as 3rd arg: ./Scripts/sim-inspect.sh navigate instagram 12
    WAIT="${3:-8}"
    echo "==> Waiting ${WAIT}s for content to load..."
    sleep "$WAIT"
    TS=$(date +%H%M%S)
    OUT="$SCREENSHOT_DIR/screen-$TS.png"
    xcrun simctl io booted screenshot "$OUT"
    echo "$OUT"
    ;;

  watch)
    # Screenshot loop for continuous monitoring while iterating on CSS/theme changes.
    # Prints each path — open the latest file in Preview or use `qlmanage -p <path>` to view.
    INTERVAL="${2:-3}"
    echo "==> Watching simulator (every ${INTERVAL}s). Ctrl+C to stop."
    while true; do
      TS=$(date +%H%M%S)
      OUT="$SCREENSHOT_DIR/screen-$TS.png"
      xcrun simctl io booted screenshot "$OUT" 2>/dev/null && echo "$OUT"
      sleep "$INTERVAL"
    done
    ;;

  build|*)
    echo "==> Booting simulator $DEVICE_ID..."
    xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
    open -a Simulator 2>/dev/null || true
    sleep 2

    echo "==> Building $SCHEME..."
    xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -destination "id=$DEVICE_ID" \
      -configuration Debug \
      build \
      ONLY_ACTIVE_ARCH=YES \
      2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED"

    echo "==> Finding app bundle..."
    APP=$(find ~/Library/Developer/Xcode/DerivedData -name "ZenSocial.app" \
          -path "*iphonesimulator*" 2>/dev/null | head -1)
    echo "    $APP"

    echo "==> Installing..."
    xcrun simctl install "$DEVICE_ID" "$APP"

    echo "==> Launching..."
    xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
    sleep 3

    echo "==> Screenshot..."
    TS=$(date +%H%M%S)
    OUT="$SCREENSHOT_DIR/screen-$TS.png"
    xcrun simctl io booted screenshot "$OUT"
    echo "SCREENSHOT: $OUT"
    ;;
esac
