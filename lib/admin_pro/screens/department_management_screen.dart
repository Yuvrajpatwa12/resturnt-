import 'package:flutter/material.dart';
import 'department/department_screen.dart';
import 'department/add_division_screen.dart';
import 'department/manage_division_screen.dart';

class DepartmentManagementScreen extends StatelessWidget {
  final String mode;
  final Function(int index)? onNavigateIndex;

  const DepartmentManagementScreen({
    super.key,
    required this.mode,
    this.onNavigateIndex,
  });

  void _handleNavigateMode(String targetMode) {
    if (onNavigateIndex != null) {
      if (targetMode == "Department List" || targetMode == "Department") {
        onNavigateIndex!(54);
      } else if (targetMode == "Add Division") {
        onNavigateIndex!(55);
      } else if (targetMode == "Manage Division") {
        onNavigateIndex!(56);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case "Department List":
      case "Department":
        return DepartmentScreen(onNavigateMode: _handleNavigateMode);
      case "Add Division":
        return AddDivisionScreen(onNavigateMode: _handleNavigateMode);
      case "Manage Division":
        return ManageDivisionScreen(onNavigateMode: _handleNavigateMode);
      default:
        return DepartmentScreen(onNavigateMode: _handleNavigateMode);
    }
  }
}
