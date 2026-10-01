import 'package:flutter/material.dart';
import '../hrm_management_screen.dart';

class EmployeeSalaryScreen extends StatelessWidget {
  const EmployeeSalaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HRMManagementScreen(mode: "Manage Employee Salary");
  }
}
