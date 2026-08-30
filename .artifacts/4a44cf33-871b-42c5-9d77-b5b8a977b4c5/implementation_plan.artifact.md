# Implementation Plan - Chiyalaa Waiter Pro

Transform the existing staff interface into a premium, functional, and interconnected waiter application "Chiyalaa Waiter Pro".

## User Review Required

> [!IMPORTANT]
> The app will strictly follow a Light Theme with the specified color palette (#F8FAFC, #0047AB, #002D62, #00C49F).
> I will create a new core directory `lib/waiter_pro/` to organize the new screens and logic.
> I will update `lib/main.dart` to launch the new `LoginScreen` by default.

## Proposed Changes

### Core UI & Theme
#### [NEW] [waiter_pro_theme.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/waiter_pro/theme.dart)
Define the `ThemeData` with the custom color palette, soft shadows, and typography.

### Authentication
#### [NEW] [login_screen.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/waiter_pro/screens/login_screen.dart)
Implement Waiter ID, PIN, and Shift Selector.

### Dashboard & Navigation
#### [NEW] [waiter_hub.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/waiter_pro/waiter_hub.dart)
Main container with the new navigation structure (Dashboard, Tables, Orders, Alerts, Profile).

#### [NEW] [dashboard_screen.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/waiter_pro/screens/dashboard_screen.dart)
Live stats chips and interactive table grid.

### Table & Order Management
#### [NEW] [table_management_screen.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/waiter_pro/screens/table_management_screen.dart)
Floor tabs (Indoor, Roof, VIP), search, and table actions.

#### [NEW] [digital_menu_screen.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/waiter_pro/screens/digital_menu_screen.dart)
Horizontal category slider, item grid, and sticky cart bar.

#### [NEW] [order_customization_dialog.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/waiter_pro/widgets/order_customization_dialog.dart)
Variant selectors and add-ons.

### Operations
#### [NEW] [live_orders_screen.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/waiter_pro/screens/live_orders_screen.dart)
Cooking/Ready/Completed filters with timers.

#### [NEW] [bill_settlement_screen.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/waiter_pro/screens/bill_settlement_screen.dart)
Itemized breakdown, tax logic, and payment modes.

### Notifications & Profile
#### [NEW] [alerts_screen.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/waiter_pro/screens/alerts_screen.dart)
Live list for kitchen and service alerts.

#### [NEW] [profile_screen.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/waiter_pro/screens/profile_screen.dart)
Waiter details, metrics, and shift logout.

### Main Entry Point
#### [MODIFY] [main.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/main.dart)
Set `initialRoute` or `home` to the new `LoginScreen`.

## Verification Plan

### Manual Verification
- Verify the light theme application across all screens.
- Test navigation flow from Login -> Dashboard -> Table -> Menu -> Checkout.
- Verify bill calculation (10% SC, 13% VAT).
- Check responsiveness of the table grid and menu slider.
