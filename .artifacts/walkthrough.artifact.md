# Consolidated Management & Multi-Platform Social Integration

I have successfully relocated the administrative access points from the diner-facing app to the internal Staff Hub and expanded the social media management capabilities for restaurants.

## 1. Diner App Cleanup (Public Privacy)

To maintain a professional customer experience, I have removed all "Staff Dashboard" and "Master Hub" buttons from the public profiles:
- **[profile_page.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/profile_page.dart)**: Removed the "Management" section and Staff Hub button.
- **[settings_page.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/settings_page.dart)**: Removed the "Internal Tools" section.

Customers will now see a clean interface, while admins can access their tools securely from the staff login flow.

## 2. Advanced Social Media Management (Admin)

Admins now have a dedicated space to manage their restaurant's global presence:
- **Multi-Platform Links**: Added support for **Instagram, Facebook, and TikTok** URLs in addition to Google Maps.
- **New Management Screen**: Created **[social_media_management_screen.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/admin_pro/screens/social_media_management_screen.dart)**, accessible via the **Admin Hub Drawer** (under "Setting" -> "Social Media").
- **Dynamic Integration**: All social links are synchronized with the `Tenant` model, allowing future features (like "Follow us on IG") to use real data.

## 3. Secure Internal Navigation

Administrative tools are now centralized within the staff area:
- **[admin_hub.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/admin_pro/admin_hub.dart)**: Integrated the Social Media manager into the sidebar drawer for quick access.
- **[settings_tab.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/staff/tabs/settings_tab.dart)**: Added a "Master Hub (SaaS)" entry point, ensuring Super Admins can still navigate to the root management module after logging in as staff.

## 4. Backend Deployment (V2)

I have generated updated server-side files to support these new fields:
- **[backend_setup_v2.sql](file:///C:/Users/yuraj/AppData/Local/Google/AndroidStudio2026.1.2/projects/chiyabreak.60a64e92/.artifacts/76cc3ff0-f3ff-4b5d-b6f9-eb37f4b62f61/scratch/backend_setup_v2.sql)**: Adds the `instagram_link`, `facebook_link`, and `tiktok_link` columns to your database.
- **[review_api_v2.php](file:///C:/Users/yuraj/AppData/Local/Google/AndroidStudio2026.1.2/projects/chiyabreak.60a64e92/.artifacts/76cc3ff0-f3ff-4b5d-b6f9-eb37f4b62f61/scratch/review_api_v2.php)**: Handles the consolidated saving of all social media profiles in one request.

> [!IMPORTANT]
> Please run the V2 SQL script and upload the V2 PHP file to your server to enable these multi-social features.
