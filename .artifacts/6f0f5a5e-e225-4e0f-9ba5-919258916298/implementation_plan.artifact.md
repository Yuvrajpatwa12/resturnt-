# Phase 12: Professional URL Routing & QR Detection Fix

This plan fixes the issue where QR codes are not reliably opening the app or detecting the table number. We will implement "Path URL Strategy" (removing the `#` from your website links) and make the table detection logic much stronger.

## 1. The "Path URL" Upgrade
By default, Flutter Web uses a `#` in the link (e.g., `startupsgo.tech/#/`). This can break QR parameters. We will remove this so your links look clean like `startupsgo.tech/?table=5`.

## Proposed Changes

### A. Routing & URL Strategy
#### [MODIFY] [main.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/main.dart)
- Import `package:flutter_web_plugins/url_strategy.dart`.
- Call `usePathUrlStrategy()` before `runApp`.
- **Why?**: This ensures that `https://startupsgo.tech/?table=12` is handled exactly as a standard website, making it easier for phone cameras and browsers to understand.

### B. Robust Table Detection
- Update `_initApp` to check multiple sources for the table ID:
    1. Standard Query Params: `?table=12`
    2. Fragment Params (Legacy fallback): `/#/?table=12`
- This ensures that no matter how the browser loads the page, the table number is NEVER missed.

### C. Dev Portal "Logout" Fix
- Ensure that when a developer clicks "Logout" in the portal, it also clears any detected table ID so they can test a "Clean" entry.

## 2. Server Configuration (Hostinger)

> [!IMPORTANT]
> **.htaccess Required**: Since we are removing the `#`, you MUST have the `.htaccess` file in your `public_html` folder.
> You already have it, but please ensure it contains the code I gave you earlier to prevent "404 Not Found" errors.

## Verification Plan

### Manual Verification
1. **Build**: Run `flutter build web --release`.
2. **Deploy**: Upload new files to Hostinger.
3. **URL Test**: Manually type `https://startupsgo.tech/?table=99` in your phone browser.
4. **Result**: Verify the app opens the **Customer Hub** instantly and shows **Table 99**.
5. **QR Test**: Scan a generated QR from the Admin Hub. Verify it opens the site directly (not a Google search).
