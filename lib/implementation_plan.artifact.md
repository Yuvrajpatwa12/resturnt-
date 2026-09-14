# Implementation Plan - Final Cache Breach (v1.0.4)

Kill all persistent browser caches and server-side LiteSpeed locks to ensure the latest "Share Your Story" and "Group Dining" features are visible on all devices.

## User Review Required

> [!CAUTION]
> **Disabling Service Workers**: I am disabling the "Offline Support" (Service Worker) for this build. This is the only guaranteed way to stop browsers (especially iOS Safari) from showing old versions of your app.

> [!TIP]
> **Visual Indicator**: I am incrementing the version to **v1.0.4**. If you see this number at the bottom of your screen, the breach is successful.

## Proposed Changes

### 1. Web Root Configuration
#### [MODIFY] [index.html](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/web/index.html)
- Increment version to `1.0.4`.
- Add script to `unregister()` all service workers immediately on load.
- Force a redirect to `?v=1.0.4` if the version doesn't match.

#### [MODIFY] [.htaccess](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/web/.htaccess)
- Add explicit headers for `main.dart.js` and `flutter_service_worker.js` to prevent server-side caching.

### 2. UI Updates
#### [MODIFY] [homepage.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/homepage.dart)
- Update version text to **"Chiyala Web Build v1.0.4"**.
- Add a small green indicator icon next to the version to make it visually different from previous attempts.

## Verification Plan

### Manual Verification
1. Run `flutter build web --release`.
2. Delete `public_html/index.html` and `public_html/main.dart.js` on Hostinger before uploading.
3. Upload new files.
4. Open `startupsgo.tech` on iPhone.
5. Confirm that **v1.0.4** is visible at the bottom.
6. Verify "SHARE YOUR STORY" card is visible.
