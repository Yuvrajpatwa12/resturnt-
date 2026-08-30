# Implementation Plan - Advanced Payroll & Employee Profiles

This plan expands the HRM module to include professional salary tracking and employee profile pictures (Camera/Gallery support).

## User Review Required

> [!IMPORTANT]
> **New Dependency**: I will add the `image_picker` package to your `pubspec.yaml` to enable camera and gallery access.
> **Backend Storage**: Profile pictures will be uploaded to a new `uploads/profiles/` folder on your Hostinger server. You may need to create this folder manually if the script doesn't have permissions.

## Proposed Changes

### [Dependencies]
#### [MODIFY] [pubspec.yaml](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/pubspec.yaml)
- Add `image_picker: ^1.1.2` to the dependencies list.

### [Admin Pro UI]
#### [MODIFY] [hrm_management_screen.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/admin_pro/screens/hrm_management_screen.dart)
- **Profile Picture Selector**: Add a clickable avatar in the "Add/Edit Employee" form to pick an image via camera or gallery.
- **Salary Cycle Logic**:
    - Calculate `daysPassed` and `daysRemaining` based on the account creation date.
    - Implement a visual progress indicator in the salary list.
- **UI Redesign**: Update `_buildPayrollView` and `_buildEmployeeRow` to display real profile pictures instead of just initials.

### [Data Layer]
#### [MODIFY] [services/api_service.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/services/api_service.dart)
- **`uploadProfilePicture`**: New method to send image bytes to the server using `http.MultipartRequest`.
- **`addStaff` / `updateStaff`**: Update to include the `profile_pic_url`.

#### [NEW] [upload_profile.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/upload_profile.php) (On Hostinger)
- A new PHP script to receive the image file, save it to the server, and return the URL.

## Verification Plan

### Manual Verification
1. **Pick Image**: Open "Add Employee", click the profile icon, and select a photo.
2. **Submit**: Save the employee and verify the photo uploads successfully.
3. **Check Payroll**: Go to "Manage Employee Salary" and confirm the photo appears next to the salary details and the cycle counter is running.
4. **Camera Test**: (If on mobile) Verify the camera opens and captures images correctly.
