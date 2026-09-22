# Consolidated Admin Management & Social Links Integration

This plan details moving administrative access points from the user app to the Staff Hub and expanding the restaurant's social profile capabilities.

## User Review Required

> [!IMPORTANT]
> - **Management Access**: The "Staff Dashboard" and "Master Hub" buttons will be removed from the public diner profiles and diner settings. They will only be accessible from within the Staff Settings area.
> - **Database Columns**: New columns (`instagram_link`, `facebook_link`, `tiktok_link`) must be added to the `tenants` table.
> - **Admin UI**: The "Restaurant Profile" page will be renamed or expanded to "Social & Business Profile" to manage all external links in one place.

## Proposed Changes

### 1. Database & Backend
#### [MODIFY] [review_api.php](file:///C:/Users/yuraj/AppData/Local/Google/AndroidStudio2026.1.2/projects/chiyabreak.60a64e92/.artifacts/76cc3ff0-f3ff-4b5d-b6f9-eb37f4b62f61/scratch/review_api.php)
- Update `update_google_link` action (or rename to `update_social_links`) to handle `google_maps_link`, `instagram_link`, `facebook_link`, and `tiktok_link`.

### 2. Core Models & Services
#### [MODIFY] [tenant_service.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/services/tenant_service.dart)
- Expand `Tenant` class with `instagramLink`, `facebookLink`, and `tiktokLink`.
- Update `fromMap` factory to parse these new fields from the API response.

#### [MODIFY] [api_service.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/services/api_service.dart)
- Add `updateSocialLinks(String tenantId, Map<String, String> links)` to send all social URLs to the server in one request.

### 3. Admin Panel (Staff Hub)
#### [MODIFY] [restaurant_profile_page.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/staff/pages/restaurant_profile_page.dart)
- Add input fields for Instagram, Facebook, and TikTok.
- Update saving logic to use the new multi-field API method.

#### [MODIFY] [settings_tab.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/staff/tabs/settings_tab.dart)
- Add "Master Hub (SaaS)" access point here for Super Admins.

### 4. Diner App Cleanup
#### [MODIFY] [profile_page.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/profile_page.dart)
- Remove the "Management" section and "Staff Dashboard" menu item.

#### [MODIFY] [settings_page.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/settings_page.dart)
- Remove the "Internal Tools" section (Dashboard and Master Hub).

## Verification Plan

### Manual Verification
1.  **Cleanup Check**: Verify that "Staff Dashboard" is no longer visible in the regular diner Profile or Settings.
2.  **Social Config**: Log into Staff mode, go to Restaurant Profile, enter links for FB/IG/TikTok, and save.
3.  **Persistence**: Refresh the app and verify the links are still there in the Admin panel.
4.  **Master Hub Access**: Verify that Master Hub can be accessed from the Staff Settings tab.
