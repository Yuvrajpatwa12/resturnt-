# Implementation Plan - Deep Debug & Startup Fix

Identify the specific point of failure during the web boot process by implementing an on-screen visual debugger and switching to the high-stability bootstrap protocol.

## User Review Required

> [!IMPORTANT]
> **On-Screen Debugging**: I am adding a small console window to the bottom of the loading screen. If the app fails to load, it will print the error message there in red. You can take a screenshot of this to show me.

> [!NOTE]
> **Bootstrap protocol**: Your server contains `flutter_bootstrap.js`. I am updating `index.html` to use this file directly, as it is the most reliable way to start a Flutter 3.24 app.

## Proposed Changes

### 1. Visual Debugger
#### [MODIFY] [web/index.html](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/web/index.html)
- Add a `<div id="debug-log">` to show real-time status.
- Add a global `window.onerror` handler to catch and display any JavaScript crashes on the screen.
- Switch to the official `<script src="flutter_bootstrap.js" async></script>` method.

### 2. Dart-to-JS Handshake
#### [MODIFY] [lib/main.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/main.dart)
- Call a small JavaScript function as the first line of `main()` to notify the browser that the Dart code has successfully started executing.

## Verification Plan

### Manual Verification
1. Run `flutter build web --release`.
2. Upload to Hostinger.
3. Open `startupsgo.tech`.
4. Watch the "Log Messages" at the bottom.
5. If it stays stuck, take a screenshot of the **Red Error Text** and show me.
