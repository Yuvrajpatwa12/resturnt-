import 'package:flutter/material.dart';
import '../hrm_management_screen.dart';

class AttendanceReportScreen extends StatelessWidget {
  const AttendanceReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HRMManagementScreen(mode: "Attendance Report");
  }
}
