# Super Admin - Categorized Staff Management & Dynamic Analytics

I have successfully updated the **Super Admin** module to provide a clear visual and analytical distinction between **Waiters** and the **Kitchen Team**.

## Key Deliverables

### 1. Categorized Staff Directory
- **Role-Based Grouping**: In the restaurant's detail view, staff members are no longer in a single list. They are now grouped into:
    - **Service Team (Waiters)**: Highlighted with **Royal Blue** accents and service icons.
    - **Production Team (Kitchen)**: Highlighted with **Orange** accents and kitchen/chef icons.
- **Visual Distinction**: Each group has a colored left-border and dedicated iconography to help administrators quickly identify departments.

### 2. Contextual Profile Deep-Dive
The staff profile subview ([staff_detail_subview.dart](file:///C:/Users/yuraj/AndroidStudioProjects/chiyabreak/lib/super_admin_module/screens/staff_detail_subview.dart)) now dynamically adapts its metrics based on the person's role:

- **For Waiters**:
    - **Performance Metrics**: Focuses on "Orders Taken" and "Revenue Generated (NPR)".
    - **Insights**: Shows "Most Sold Items" to track sales performance.
    - **History**: Displays a "Waiter Order History" table with table IDs and response times.
- **For Kitchen Team**:
    - **Performance Metrics**: Focuses on "Items Prepped" and "Prep Efficiency (%)".
    - **Insights**: Shows "High Volume Prepared Items" to track production output.
    - **History**: Displays a "Kitchen Prep History" table with department stations and prep durations.

### 3. Unified Session Tracking
- Both roles share a consistent **Attendance Record** log, tracking shift starts, meal breaks, and clock-outs.
- **Live Status**: Real-time "ACTIVE NOW" badges are color-coded by role for instant departmental monitoring.

## Technical Polish
- **Scalable Architecture**: The UI logic automatically detects keywords in the staff role (e.g., "Chef", "Kitchen", "Waiter") to switch between Blue and Orange design states.
- **Mock Data Ready**: Pre-populated with diverse roles (Manager, Head Chef, Waiter, Kitchen Assistant) to demonstrate the categorization.

## How to Test
1. Open **Admin Hub** > **Clients** > **Cafe Himalaya**.
2. Observe the two separate boxes for **Service Team** and **Production Team**.
3. **Tap on "Sita Rai" (Head Chef)**: Notice the orange theme and preparation-focused metrics.
4. **Tap on "Kiran Magar" (Waiter)**: Notice the blue theme and sales-focused metrics.

Please restart the app to explore the new departmental staff management system!
