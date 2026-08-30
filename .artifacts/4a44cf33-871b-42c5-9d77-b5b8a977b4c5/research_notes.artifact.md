# Research Notes - Chiyalaa Waiter Pro

## Current Project State
- The project `chiyabreak` is a Flutter app.
- It already has a `StaffHub` in `lib/staff/` which seems to be a basic waiter/admin interface.
- It uses a singleton `ShopManager` (`lib/cart_manager.dart`) for state management using `ValueNotifier` and `ValueListenableBuilder`.
- The current theme is a seed-based Material 3 theme with an orange primary color (`0xFFFF5C00`).
- The project contains many files related to games, social features, and customer-facing views, which should be kept separate from the new "Waiter Pro" module.

## UI/UX Requirements
- **Theme**: Strictly Light Mode.
- **Background**: Pearl White / Off-White (#F8FAFC).
- **Primary**: Deep Royal Blue (#0047AB).
- **Secondary**: Dark Navy (#002D62).
- **Accent**: Emerald Green (#00C49F).
- **Surfaces**: Pure White (#FFFFFF) with soft shadows.

## New Module Structure
I will create a new directory `lib/waiter_pro/` to house the specific implementation for "Chiyalaa Waiter Pro". This will avoid cluttering the existing `lib/staff/` directory if the user wants to keep the old one for reference or other purposes, although the request says "update all existing page files and create new ones where required". I will aim to replace the main staff entry point with this new module.

### Components Needed:
1.  **Auth**: Waiter ID, 4-digit PIN, Shift Selector.
2.  **Dashboard**: Quick stats, interactive grid.
3.  **Table Management**: Floor filters, merging/clearing.
4.  **Menu**: Category slider, search, sticky cart.
5.  **Customization**: Variants, add-ons, chef notes.
6.  **Live Orders**: Cooking/Ready/Completed filters, elapsed time counters.
7.  **Billing**: Breakdown, tax calculation, payment modes, KOT/Invoice print.
8.  **Alerts**: Kitchen alerts, service calls.
9.  **Profile**: Shift summary, performance metrics.

## State Management Strategy
I will continue using the `ShopManager` pattern or a similar `ValueNotifier` based approach to ensure consistency with the existing codebase, but I will refactor or extend it to support the new features (e.g., shift data, variant selections).

## Routing
I will implement a named routing system or a clean `Navigator.push` strategy to interconnect the screens.
