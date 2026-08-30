# Implementation Plan - Navigation Reorganization

The goal is to move the Cart functionality from the header to the bottom navigation bar, replacing the "Offer" tab.

## User Review Required

> [!IMPORTANT]
> - The **Cart Icon** will be removed from the home page header.
> - The **Offer** tab in the bottom navigation will be replaced by a **Cart** tab.
> - The **Cart** tab will show a live badge with the number of items.
> - I will remove the broken reference to `OffersPage`.

## Proposed Changes

### [Component Name] chiyabreak (Flutter App)

#### [MODIFY] [homepage.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/homepage.dart)
- Remove the cart icon `ValueListenableBuilder` block from `_buildHomeContent()`.
- Update `bottomNavigationBar`:
    - Replace the "Offer" `_buildNavItem` with a `ValueListenableBuilder` that returns a `Cart` nav item with a badge.
- Update `_buildBody()`:
    - Change `case 3` to return `const CartPage()`.
- Remove `import 'offer.dart';`.

## Verification Plan

### Automated Tests
- Run `analyze_file` to ensure no remaining references to `OffersPage` or `offer.dart`.

### Manual Verification
- Verify that the header no longer has a cart icon.
- Verify that the 4th tab in the bottom navigation is now "Cart".
- Verify that adding an item correctly updates the badge on the bottom "Cart" tab.
- Verify that clicking the "Cart" tab opens the cart list.
