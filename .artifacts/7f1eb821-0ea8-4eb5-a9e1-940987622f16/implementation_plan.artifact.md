# Real-Time Push Notifications (FCM Integration)

Implement real-time push notifications so users get alerts on their phones (even when the app is in the background) when someone follows them, waves at them, or their order status changes.

## User Review Required

> [!IMPORTANT]
> **Technology**: We will use **Firebase Cloud Messaging (FCM)**. This is the industry standard for sending alerts directly to Android and iOS devices.
>
> **Setup Required**: You will need to create a free Firebase Project at [console.firebase.google.com](https://console.firebase.google.com) and provide the `google-services.json` (Android) or `firebase_options.dart` (Web).

> [!NOTE]
> **Browser Permissions**: On Web (Chrome/Safari), the user must click "Allow" when the browser asks for notification permissions for this to work.

## Proposed Changes

### [Backend - PHP/MySQL]

#### [MODIFY] [full_system_setup.sql](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/.artifacts/7f1eb821-0ea8-4eb5-a9e1-940987622f16/full_system_setup.sql)
- **Table `customers`**: Add `fcm_token` column (TEXT). This stores the unique address of each user's phone.

#### [NEW] [push_notifier.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/.artifacts/7f1eb821-0ea8-4eb5-a9e1-940987622f16/scratch/push_notifier.php)
- A helper script that connects to Google Firebase API.
- Functions to send "New Follower" or "Order Ready" alerts to specific tokens.

#### [MODIFY] [nearby_api.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/.artifacts/7f1eb821-0ea8-4eb5-a9e1-940987622f16/scratch/nearby_api.php)
- Trigger the `push_notifier.php` whenever a follow or wave record is inserted.

### [Customer App - Flutter]

#### [MODIFY] [pubspec.yaml](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/pubspec.yaml)
- Add `firebase_core` and `firebase_messaging` dependencies.

#### [MODIFY] [cart_manager.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/cart_manager.dart)
- **Token Management**: On startup, get the FCM token and send it to the `customers` table via API.
- **Foreground Alerts**: Handle notifications while the app is open (show a top banner).

#### [MODIFY] [main.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/main.dart)
- Initialize Firebase during the Splash Screen loading phase.

## Verification Plan

### Manual Verification
1. **Permission**: Open app -> Click "Allow" on the notification popup.
2. **Follow Test**: Use Phone A to follow User B.
3. **Push Check**: Verify User B gets a system notification at the top of their phone screen (even if the app is minimized).
4. **Order Alert**: Change an order to "Ready" in Admin Hub -> Verify the customer gets a "Your food is ready!" notification.
