# Implementation Plan - Designation Management System

This plan implements a full Designation Management system within the HRM module. It allows administrators to define job titles and roles dynamically, which can then be assigned to employees.

## User Review Required

> [!IMPORTANT]
> **Database Requirement**: I will provide SQL code to create the `designations` table. You must run this in your phpMyAdmin on Hostinger.
> **Real-Time Integration**: Once a designation is added, it will immediately appear as an option when adding or editing a new employee.

## Proposed Changes

### [Admin Pro UI]
#### [MODIFY] [hrm_management_screen.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/admin_pro/screens/hrm_management_screen.dart)
- **New View**: Implement `_buildDesignationView()` which includes:
    - An explanation header explaining the purpose of designations.
    - A form to add new designations (Title and Department).
    - A list of existing designations with delete capability.
- **Dynamic Employee Form**:
    - Change the "System Role" hardcoded dropdown to fetch job titles from the new designations system.
- **State Management**: Add `_designationsList` and `_loadDesignations()` to handle the data.

### [Data Layer]
#### [MODIFY] [services/api_service.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/services/api_service.dart)
- Add `fetchDesignations(tenantId)`
- Add `addDesignation(data)`
- Add `deleteDesignation(id)`

### [Backend]
#### [NEW] [add_designation.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/.artifacts/16d65584-180b-4fe9-a136-0738081b64ee/scratch/add_designation.php)
#### [NEW] [get_designations.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/.artifacts/16d65584-180b-4fe9-a136-0738081b64ee/scratch/get_designations.php)
#### [NEW] [delete_designation.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/.artifacts/16d65584-180b-4fe9-a136-0738081b64ee/scratch/delete_designation.php)

## Verification Plan

### Manual Verification
1. **Explain Header**: Navigate to "Designation" and verify the description text is visible at the top.
2. **Add Designation**: Add "Executive Chef" under "Kitchen" department. Verify it appears in the list immediately.
3. **Assign to Employee**: Go to "Add Employee" and check if "Executive Chef" is now available in the role/title dropdown.
4. **Delete**: Delete a designation and verify it is removed from the system.
