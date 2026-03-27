# Expectations / Goals

- Make app look like one cohesive app, not web apps rendered inside a local app
- Make it easily navigatable
- Allow as much screen space for social media apps to make them feel native, not a smaller window inside another app

# UI Changes

- [-] Remove clunky bar from bottom making it hard to navigate, switch to either a
  - floating movable button that exapands when clicked to present all options
  - gesture based system where you navigate with swipe gestures
- [-] Custome loading screens to match styling of app
  - Also include unique ones based on what is currently happening, IE:
    - Waiting for Sign In
    - Loading Instagram
    - Loading YouTube
    - etc.
- [-] Blend the background of whatever social meadia platform is open into the native IOS app so it all looks like one cohesive app, not a web app rendered inside an app
- [-] Make it so sign it Modal appears like a modal, leaves other page visible behind it (by be a smaller size)

# Features

- Built in ad blocker
- Dismiss "Use the app" popups
- Push notifications, even when the app is closed, and have the push notifcations bring you to the app
- corner snapping locations for ZenNavigator (new name for pill button)

## New home button placement

- For cetain platforms, set the placement of the hom pill to a specific spot to work with platform UI
  - Put it into the navigation bar for Instagram and Youtube
  - YouTube:
    - Place it into the top bar when watching a video: /var/folders/gz/bgmrctb506b_lqtwhwhfkg5w0000gp/T/TemporaryItems/NSIRD_screencaptureui_zTR0NL/Screenshot\ 2026-03-26\ at\ 2.07.12 PM.png
      -Place it into the bottom navigator bar when not watching a video: /var/folders/gz/bgmrctb506b_lqtwhwhfkg5w0000gp/T/TemporaryItems/NSIRD_screencaptureui_n0KK0S/Screenshot\ 2026-03-26\ at\ 2.08.04 PM.png

# Fixes

- Stop playing videos after platfrom has been closed (known issue for YouTube)
- Add movement annamation when dragging home button
- Make it so floating home pill does not go off screen when expanded clsose to the edge
- Make current platform go all the way to the bottom of the screen
- Hide the FloatingPillButton when not a social media platform (like when on the home page)
