# Implementation Plan - MySQLi Backend Synchronization

This plan migrates all Attendance and Expense backend scripts from PDO back to **MySQLi**. Since your server uses the `mysqli` driver, this is required to fix the "Status 500" errors and ensure all data saves correctly.

## User Review Required

> [!IMPORTANT]
> **Action Required**: You must replace the existing code on your Hostinger server with the MySQLi versions provided below. I will provide them in logical groups.

## Proposed Changes

### [Backend - Attendance Module]
#### [MODIFY] [mark_attendance.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/mark_attendance.php)
#### [MODIFY] [get_attendance.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/get_attendance.php)
#### [MODIFY] [get_attendance_report.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/get_attendance_report.php)
#### [MODIFY] [get_attendance_analytics.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/get_attendance_analytics.php)
#### [MODIFY] [get_employee_stats.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/get_employee_stats.php)

### [Backend - Expense Module]
#### [MODIFY] [add_expense_v3.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/add_expense_v3.php)
#### [MODIFY] [get_expenses.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/get_expenses.php)
#### [MODIFY] [get_expense_dashboard.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/get_expense_dashboard.php)
#### [MODIFY] [add_vendor.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/add_vendor.php)
#### [MODIFY] [get_vendors.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/get_vendors.php)
#### [MODIFY] [add_recurring.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/add_recurring.php)
#### [MODIFY] [get_recurring.php](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/saas_api/get_recurring.php)

## Verification Plan

### Manual Verification
1. **Upload critically used files**: Start with `add_recurring.php` and `add_vendor.php`.
2. **Mark Attendance**: Verify the "Saving..." flow now completes with a "Success" message and the record appears in the database.
3. **Register Vendor**: Verify you can add a new supplier without getting a server error.
4. **Dashboard Check**: Open the Expense Statement and verify charts load without a red screen.
