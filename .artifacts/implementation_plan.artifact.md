# Implementation Plan - Functional HomePage Integration

This plan details the transition of `HomePage` from a demo UI to a fully functional application interface, connecting all interactions to the global state and specialized sub-pages.

## Proposed Changes

### Core Logic

#### [MODIFY] [cart_manager.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/cart_manager.dart)
- **State Expansion**:
    - Add `ValueNotifier<int> selectedTableId` to manage the user's current table.
    - Add `ValueNotifier<String?> activeCategory` to handle home-to-menu category filtering.
- **Methods**:
    - Add `switchTable(int id)` to update the session.
    - Add `navigateToCategory(String category)` to handle cross-tab navigation.

### Client Module

#### [MODIFY] [homepage.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/homepage.dart)
- **Table Selector**:
    - Make the "TABLE 12" card clickable.
    - Open a `TableSelectionBottomSheet` allowing users to choose their table.
- **Header Actions**:
    - **Notifications**: Link to the existing `AlertsScreen` (or a client-side equivalent).
    - **Profile**: Switch to tab index 4 (Profile).
- **Categories**:
    - Tapping a category (e.g., "Momos") will now:
        1. Update `ShopManager.instance.activeCategory`.
        2. Switch `currentTabIndex` to 1 (Menu).
- **Section Actions**:
    - "View All", "Explore", and Promo "Order Now" will all trigger a navigation to the Menu tab.
- **Rewards Card**:
    - "Join Now" will navigate to the `RewardsPage`.
- **Summer Offer**:
    - Clickable card leading to a filtered "Special Items" view in the Menu.

#### [MODIFY] [menu.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/menu.dart)
- Listen to `ShopManager.instance.activeCategory` on initialization to auto-filter the menu when arriving from Home.

## Verification Plan

### Manual Verification
1. **Table Switch**: Tap "TABLE 12", select "TABLE 05", and verify the header updates globally.
2. **Category Flow**: Tap the "Momos" icon on Home. Verify the app switches to the Menu tab and only Momos are shown.
3. **Promo Flow**: Click "Order Now" on the Sandwich banner and verify it leads to the Menu tab.
4. **Rewards Flow**: Click "Join Now" on the Rewards card and verify it opens the `RewardsPage`.
5. **Direct Navigation**: Click the profile icon in the header and verify it switches to the Profile tab.
