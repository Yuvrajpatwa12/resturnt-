# Walkthrough - Real-Time Push Notifications Integration

I have implemented the core infrastructure for **Real-Time Push Notifications**. This allows your app to send alerts directly to users' phones even when they aren't using the app.

## Key Components Implemented

### 1. Database Token Storage
- Updated the `customers` table to store a **`fcm_token`**.
- This token acts like a "home address" for each phone, allowing our server to know exactly where to send the alerts.

### 2. Backend Notification Engine
- **`push_notifier.php`**: A new high-performance script that manages the connection between your Hostinger server and Google's Firebase servers.
- **Smart Triggers**:
    - **Follow Alert**: When a user is followed, they get a push notification.
    - **Wave Alert**: When a user is waved at, they get an instant buzz on their phone.
    - **Order Updates**: (Optional) Can be added to notify users when food is ready.

### 3. App Token Management
- **Automatic Registration**: The app now requests notification permissions during onboarding. If the user allows it, their unique token is automatically synced to your database.
- **Foreground Handlers**: Added logic to `CartManager` to handle notifications while the app is actively open.

## 🛠️ CRITICAL: Firebase Console Setup

To make these notifications actually appear on phones, you must follow these steps:

1.  **Create a Firebase Project**:
    - Go to [Firebase Console](https://console.firebase.google.com).
    - Create a new project named "ChiyaBreak".
2.  **Add Your Web App**:
    - Click the **Web** icon (`</>`) to register your app.
    - Copy the `firebaseConfig` object and create a file `lib/firebase_options.dart` (or let Flutter generate it).
3.  **Download Service Account**:
    - Go to **Project Settings** -> **Service Accounts**.
    - Click **Generate New Private Key**.
    - Rename the downloaded file to **`service-account.json`** and upload it to your Hostinger `saas_api/` folder.
4.  **Enable Messaging**:
    - Ensure **Cloud Messaging** is enabled in the Firebase settings.

> [!WARNING]
> **Push notifications will NOT work** until you upload the `service-account.json` to Hostinger and provide the Firebase configuration to your Flutter project.

> [!TIP]
> Once setup is complete, you can test by waving at yourself from another device—your phone should vibrate and show a notification banner instantly!
