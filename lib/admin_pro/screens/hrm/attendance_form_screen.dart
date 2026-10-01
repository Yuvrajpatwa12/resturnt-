import 'package:flutter/material.dart';
import '../hrm_management_screen.dart';

class AttendanceFormScreen extends StatelessWidget {
  const AttendanceFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HRMManagementScreen(mode: "Attendance Form");
  }
}
