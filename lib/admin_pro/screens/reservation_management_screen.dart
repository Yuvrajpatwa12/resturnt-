import 'package:flutter/material.dart';
import '../admin_theme.dart';

class ReservationManagementScreen extends StatelessWidget {
  final String mode;
  const ReservationManagementScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mode == "Add Booking") _buildAddBookingForm()
          else if (mode == "Unavailable Day") _buildHolidayView()
          else if (mode == "Reservation Setting") _buildSettingView()
          else _buildReservationListView(),
        ],
      ),
    );
  }

  Widget _buildReservationListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Booking Log", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Text("TODAY", style: TextStyle(color: AdminTheme.royalBlue, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(4, (index) => _buildReservationCard(index)),
      ],
    );
  }

  Widget _buildReservationCard(int index) {
    final List<String> names = ["Yuvraj Patwa", "Catherine J.", "Noah Smith", "Sarah Miller"];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminTheme.royalBlue.withValues(alpha: 0.1),
            child: const Icon(Icons.person_outline, color: AdminTheme.royalBlue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(names[index % names.length], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Text("Table T-105 • 4 People", style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("07:30 PM", style: TextStyle(fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AdminTheme.emeraldGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text("CONFIRMED", style: TextStyle(color: AdminTheme.emeraldGreen, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddBookingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("New Reservation", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        _buildTextField("Customer Name", "Enter guest name"),
        const SizedBox(height: 16),
        _buildTextField("Phone Number", "+977-XXXXXXXXXX"),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField("No. of Guests", "2")),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField("Table ID", "T-101")),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField("Date", "22/08/2026")),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField("Time", "08:00 PM")),
          ],
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
          child: const Text("CREATE BOOKING"),
        ),
      ],
    );
  }

  Widget _buildHolidayView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Restaurant Holidays", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text("Mark specific dates as unavailable for bookings.", style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
          child: Column(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 48, color: AdminTheme.royalBlue),
              const SizedBox(height: 16),
              const Text("No unavailable dates set for August.", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: () {}, child: const Text("ADD UNAVAILABLE DAY")),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Booking Policy", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildToggleCard("Auto-Confirm Bookings", true),
        _buildToggleCard("SMS Notification", false),
        _buildToggleCard("Table Pre-Assignment", true),
      ],
    );
  }

  Widget _buildToggleCard(String label, bool value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: (v) {},
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        activeTrackColor: AdminTheme.emeraldGreen,
      ),
    );
  }

  Widget _buildTextField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
