import 'package:flutter/material.dart';
import '../hrm_management_screen.dart';

class ManageEmployeeScreen extends StatelessWidget {
  const ManageEmployeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HRMManagementScreen(mode: "Manage Employee");
  }
}
