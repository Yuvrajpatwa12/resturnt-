import 'package:flutter/material.dart';
import '../hrm_management_screen.dart';

class AddEmployeeScreen extends StatelessWidget {
  const AddEmployeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HRMManagementScreen(mode: "Add Employee");
  }
}
