import 'package:flutter/material.dart';
import 'tenant_service.dart';
import '../admin_pro/admin_login_screen.dart';
import '../admin_pro/admin_hub.dart';
import '../waiter_pro/waiter_hub.dart';
import '../kitchen_pro/kitchen_hub.dart';

class StaffGateway extends StatelessWidget {
  const StaffGateway({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Staff?>(
      valueListenable: TenantService().currentStaff,
      builder: (context, staff, child) {
        // 1. Always show Login Screen if not authenticated
        if (staff == null) {
          return const AdminLoginScreen(roleHint: "Staff");
        }

        // 2. Automatic Routing based on Database Role
        switch (staff.role) {
          case 'Admin':
            return const AdminHub();
          case 'Waiter':
            return const WaiterHub();
          case 'Kitchen':
          case 'Chef':
            return const KitchenHub();
          case 'Cashier':
            return const AdminHub();
          default:
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Role '${staff.role}' not recognized for this portal."),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => TenantService().logout(),
                      child: const Text("Logout & Try Again"),
                    ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}
