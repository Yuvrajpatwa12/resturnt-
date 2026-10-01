import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class CounterManagementScreen extends StatefulWidget {
  const CounterManagementScreen({super.key});

  @override
  State<CounterManagementScreen> createState() => _CounterManagementScreenState();
}

class _CounterManagementScreenState extends State<CounterManagementScreen> {
  // Demo Data Source
  final List<Map<String, dynamic>> _counters = [
    {'id': 'C-001', 'name': 'Main Counter', 'status': 'Online', 'color': AdminTheme.emeraldGreen},
    {'id': 'C-002', 'name': 'Express Counter', 'status': 'Busy', 'color': Colors.orange},
    {'id': 'C-003', 'name': 'Bar Counter', 'status': 'Offline', 'color': Colors.red},
    {'id': 'C-004', 'name': 'Patio Service', 'status': 'Online', 'color': AdminTheme.emeraldGreen},
  ];

  String _searchQuery = "";

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AdminTheme.royalBlue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- WORKABLE ACTIONS ---

  Future<void> _addOrEditCounter({Map<String, dynamic>? existingCounter}) async {
    final nameController = TextEditingController(text: existingCounter?['name']);
    final idController = TextEditingController(text: existingCounter?['id']);
    bool isEditing = existingCounter != null;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEditing ? "Edit Counter" : "Add New Counter", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Counter Name", hintText: "e.g. Roof Top Counter"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: "Counter ID", hintText: "e.g. C-005"),
              enabled: !isEditing,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty || idController.text.isEmpty) return;
              setState(() {
                if (isEditing) {
                  int index = _counters.indexWhere((e) => e['id'] == existingCounter['id']);
                  if (index != -1) {
                    _counters[index]['name'] = nameController.text;
                  }
                } else {
                  _counters.add({
                    'id': idController.text,
                    'name': nameController.text,
                    'status': 'Online',
                    'color': AdminTheme.emeraldGreen,
                  });
                }
              });
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue, foregroundColor: Colors.white),
            child: Text(isEditing ? "UPDATE" : "SAVE"),
          ),
        ],
      ),
    );

    if (result == true) {
      _showToast(isEditing ? "Counter updated" : "Counter added successfully");
    }
  }

  void _showQRCodeDialog(Map<String, dynamic> counter) {
    final tenant = TenantService().currentTenant.value;
    String domain = (tenant != null && tenant.domain.isNotEmpty) ? tenant.domain : "startupsgo.tech";
    String counterId = counter['id'].toString();
    String qrData = "https://$domain/?counter=$counterId";

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          width: 420,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 10),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stylized Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  decoration: const BoxDecoration(
                    color: AdminTheme.royalBlue,
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        counter['name'].toString().toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "TERMINAL ID: $counterId",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      // QR Code Container
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 5),
                          ],
                          border: Border.all(color: Colors.grey.shade100, width: 2),
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 220.0,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AdminTheme.darkNavy),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AdminTheme.royalBlue),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      const Text(
                        "SCAN TO INTERACT",
                        style: TextStyle(fontWeight: FontWeight.w900, color: AdminTheme.darkNavy, letterSpacing: 2, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Point your camera at this QR code to access the $domain self-service portal.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5),
                      ),
                      
                      const SizedBox(height: 32),
                      // Action Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: qrData));
                                _showToast("Link copied to clipboard!");
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text("COPY LINK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showToast("Downloading QR Image..."),
                              icon: const Icon(Icons.file_download_outlined, size: 16),
                              label: const Text("DOWNLOAD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminTheme.royalBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("DISMISS", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                      ),
                    ],
                  ),
                ),
                
                // Footer Branding
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  width: double.infinity,
                  color: Colors.grey.shade50,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 12, color: AdminTheme.royalBlue),
                        const SizedBox(width: 8),
                        Text("POWERED BY CHIYABREAK SAAS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteCounter(Map<String, dynamic> counter) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Counter"),
        content: Text("Are you sure you want to remove '${counter['name']}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              setState(() => _counters.remove(counter));
              Navigator.pop(ctx);
              _showToast("Counter removed", isError: true);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCounters = _counters.where((c) => c['name'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("POS Counters", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                  Text("Manage active sales terminals and staff assignments", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _addOrEditCounter(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("ADD COUNTER", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.royalBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AdminTheme.softShadow,
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                icon: Icon(Icons.search, color: Colors.grey, size: 20),
                hintText: "Search counters by name...",
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Counters Grid/List
          if (filteredCounters.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AdminTheme.softShadow,
              ),
              child: const Column(
                children: [
                  Icon(Icons.point_of_sale_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text("No counters found matching search.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            )
          else
            ...filteredCounters.map((c) => _buildCounterCard(c)),
        ],
      ),
    );
  }

  Widget _buildCounterCard(Map<String, dynamic> counter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.point_of_sale, color: AdminTheme.royalBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(counter['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("ID: ${counter['id']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: (counter['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(counter['status'], style: TextStyle(color: counter['color'], fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _showQRCodeDialog(counter),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 20, color: AdminTheme.royalBlue),
                    tooltip: "Generate QR",
                  ),
                  IconButton(
                    onPressed: () => _showToast("Printing reports for ${counter['name']}..."),
                    icon: const Icon(Icons.print_outlined, size: 18, color: Colors.grey),
                    tooltip: "Print Report",
                  ),
                  IconButton(
                    onPressed: () => _addOrEditCounter(existingCounter: counter),
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                    tooltip: "Edit Counter",
                  ),
                  IconButton(
                    onPressed: () => _deleteCounter(counter),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    tooltip: "Delete Counter",
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
