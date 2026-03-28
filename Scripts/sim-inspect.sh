#!/usr/bin/env bash
# sim-inspect.sh — Build, install, launch, and screenshot ZenSocial in the iOS Simulator.
# Usage:
#   ./Scripts/sim-inspect.sh                     # build + install + launch + screenshot
#   ./Scripts/sim-inspect.sh screenshot          # screenshot only (app already running)
#   ./Scripts/sim-inspect.sh tap <x> <y>         # tap at coordinates
#   ./Scripts/sim-inspect.sh scroll <x> <y> <dx> <dy>  # swipe gesture

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
