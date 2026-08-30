# Implementation Plan - Staff Pro Suite: Multi-Floor & Live Alerts

This plan introduces advanced operational features to the Staff Pro Suite, including multi-floor table management, interactive analytics charts, and a global restaurant alert system.

## Proposed Changes

### 1. Multi-Floor Table Support (1F & 2F)

#### [MODIFY] [cart_manager.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/cart_manager.dart)
- Expand `tableStatuses` and `tableOrders` to support floor-prefixed IDs (e.g., `101` for 1F-01, `201` for 2F-01).
- Update `initializeTables` to setup 20 tables per floor.

#### [MODIFY] [tables_tab.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/staff/tabs/tables_tab.dart)
- Enable the **"1F Hall"** and **"2F Hall"** switcher chips.
- Filter the table grid based on the selected floor.

### 2. Interactive Analytics Dashboard

#### [MODIFY] [admin_tab.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/staff/tabs/admin_tab.dart)
- Replace static Sales Cards with **Interactive Bar Charts** (mocked using `AnimatedContainers`).
- Add a "Peak Hours" visualization to show when the restaurant is busiest.
- Implement a "Revenue vs Target" progress ring.

### 3. Global Staff Alert System

#### [MODIFY] [staff_hub.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/staff/staff_hub.dart)
- Implement a **Top-Level Alert Overlay**.
- This overlay will listen to the `tableStatuses` in `ShopManager`.
- **Behavior**: If any table (on any floor) changes to "Help Needed" or "Ready," a pulsing orange banner will appear at the top of the screen, regardless of which tab the waiter is currently viewing.

### 4. Advanced Search & Filter (Bills History)

#### [MODIFY] [bills_tab.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/staff/tabs/bills_tab.dart)
- **Search Logic**: Implement a search bar that filters the list by Order ID or Table Number.
- **Status Filters**: Update the "All/Active/Billed" chips to fully filter the underlying list.

### 5. Tactile Feedback (Premium Haptics)

- Integrate `HapticFeedback.mediumImpact()` into:
    - Order confirmation.
    - Sending the digital bill.
    - Ticking a menu item.

## Verification Plan

### Manual Verification
1.  **Floor Switching**: Toggle between 1F and 2F. Verify Table 1F-01 has a different status than 2F-01.
2.  **Dashboard Visuals**: Check the new charts in the Admin tab for smooth animations.
3.  **Global Alerts**: Mark a table on 2F as "Help Needed" while viewing the Menus tab on 1F. Verify the orange alert banner appears.
4.  **Search Test**: Type "146" in the Bills search bar. Verify only Order #146 remains visible.
5.  **Haptic Check**: Perform a "Send Bill" action and verify the tactile vibration on a physical device.
