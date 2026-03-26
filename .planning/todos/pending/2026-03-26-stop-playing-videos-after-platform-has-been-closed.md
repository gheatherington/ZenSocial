---
created: 2026-03-26T22:18:08.589Z
title: Stop playing videos after platform has been closed
area: general
files: []
---

## Problem

YouTube (and potentially other platforms) continues playing audio/video after the user navigates away from the platform tab or closes the platform view. Known issue — media playback should pause when the WKWebView is no longer the active screen.

## Solution

Inject JS at the appropriate lifecycle point (e.g., when the view disappears or loses active status) to pause all media: `document.querySelectorAll('video, audio').forEach(el => el.pause())`. Hook into SwiftUI's `onDisappear` or the ZStack opacity toggle to trigger the pause script via `WKWebView.evaluateJavaScript`.
