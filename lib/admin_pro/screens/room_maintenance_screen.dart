import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models.dart';
import '../admin_theme.dart';

class RoomMaintenanceScreen extends StatefulWidget {
  const RoomMaintenanceScreen({super.key});

  @override
  State<RoomMaintenanceScreen> createState() => _RoomMaintenanceScreenState();
}

class _RoomMaintenanceScreenState extends State<RoomMaintenanceScreen> {
  String _currentSubMode = "Room Overview";
  String _settingsSubMode = "Main";
  final List<HotelRoom> _rooms = _generateMockRooms();
  final List<MaintenanceRequest> _maintenanceRequests = _generateMockMaintenance();
  final List<LostAndFoundItem> _lostAndFound = _generateMockLostAndFound();
  String _searchQuery = "";
  String _floorFilter = "All Floors";
  String _typeFilter = "All Types";

  static List<HotelRoom> _generateMockRooms() {
    return List.generate(24, (index) {
      final floor = (index / 6).floor() + 1;
      final roomNum = "${floor}0${index % 6 + 1}";
      return HotelRoom(
        id: index.toString(),
        roomNumber: roomNum,
        type: index % 4 == 0 ? "Executive Suite" : (index % 3 == 0 ? "Deluxe Double" : "Standard Twin"),
        floor: floor,
        capacity: index % 4 == 0 ? 4 : 2,
        price: index % 4 == 0 ? 18000 : 9500,
        amenities: ["Wi-Fi", "Mini Bar", "AC", "Smart TV", "Safe"],
        occupancy: OccupancyStatus.values[index % OccupancyStatus.values.length],
        condition: RoomCondition.values[index % RoomCondition.values.length],
        housekeeping: HousekeepingStatus.values[index % HousekeepingStatus.values.length],
        currentGuest: index % 3 == 0 ? "Amit Sharma" : (index % 5 == 0 ? "Elena Gilbert" : null),
        bookingId: index % 3 == 0 ? "#BK-992$index" : (index % 5 == 0 ? "#BK-110$index" : null),
      );
    });
  }

  static List<MaintenanceRequest> _generateMockMaintenance() {
    return [
      MaintenanceRequest(id: "1", roomNumber: "101", category: "Plumbing", priority: MaintenancePriority.Urgent, status: MaintenanceStatus.InProgress, description: "Leaking faucet in bathroom", reportedBy: "HK Staff Sarah", reportedAt: DateTime.now().subtract(const Duration(hours: 2)), technician: "Ram Bahadur", cost: 1200),
      MaintenanceRequest(id: "2", roomNumber: "205", category: "Electrical", priority: MaintenancePriority.High, status: MaintenanceStatus.Reported, description: "AC making loud noise", reportedBy: "Guest Smith", reportedAt: DateTime.now().subtract(const Duration(days: 1))),
    ];
  }

  static List<LostAndFoundItem> _generateMockLostAndFound() {
    return [
      LostAndFoundItem(id: "1", itemName: "iPhone 13 Charger", roomNumber: "302", foundBy: "HK Anita", foundDate: DateTime.now().subtract(const Duration(days: 2)), status: "Unclaimed", storageLocation: "Safe A"),
      LostAndFoundItem(id: "2", itemName: "Brown Leather Wallet", roomNumber: "105", foundBy: "Waiter Arjun", foundDate: DateTime.now().subtract(const Duration(days: 5)), status: "Claimed"),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSubNavigation(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: SingleChildScrollView(
              key: ValueKey(_currentSubMode),
              padding: const EdgeInsets.all(24),
              child: _buildContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubNavigation() {
    final List<String> modes = [
      "Room Overview",
      "All Rooms",
      "Housekeeping",
      "Maintenance Requests",
      "Room Inspection",
      "Out of Service",
      "Lost & Found",
      "Room Settings"
    ];
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: modes.length,
        itemBuilder: (context, index) {
          final isSelected = _currentSubMode == modes[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: InkWell(
              onTap: () => setState(() => _currentSubMode = modes[index]),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? AdminTheme.royalBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  modes[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentSubMode) {
      case "Room Overview":
        return _buildRoomOverview();
      case "All Rooms":
        return _buildAllRoomsTable();
      case "Housekeeping":
        return _buildHousekeepingView();
      case "Maintenance Requests":
        return _buildMaintenanceView();
      case "Room Inspection":
        return _buildInspectionView();
      case "Out of Service":
        return _buildOutOfServiceView();
      case "Lost & Found":
        return _buildLostAndFoundView();
      case "Room Settings":
        return _buildRoomSettingsView();
      default:
        return _buildPlaceholderView();
    }
  }

  // --- 1. ROOM OVERVIEW ---
  Widget _buildRoomOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryBar(),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: _buildSearchField()),
            const SizedBox(width: 16),
            _buildFloorSelector(),
            const SizedBox(width: 16),
            _buildTypeSelector(),
          ],
        ),
        const SizedBox(height: 32),
        _buildRoomGrid(),
      ],
    );
  }

  Widget _buildSummaryBar() {
    final stats = {
      "Total": _rooms.length,
      "Available": _rooms.where((r) => r.occupancy == OccupancyStatus.Vacant).length,
      "Occupied": _rooms.where((r) => r.occupancy == OccupancyStatus.Occupied).length,
      "Cleaning": _rooms.where((r) => r.condition == RoomCondition.Cleaning).length,
      "Maintenance": _rooms.where((r) => r.condition == RoomCondition.Maintenance).length,
    };
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: stats.entries.map((e) => _buildStatCard(e.key, e.value.toString())).toList(),
    );
  }

  Widget _buildStatCard(String label, String value) {
    Color color = AdminTheme.royalBlue;
    IconData icon = Icons.hotel;
    if (label == "Available") {
      color = AdminTheme.emeraldGreen;
      icon = Icons.check_circle;
    }
    if (label == "Occupied") {
      color = Colors.orange;
      icon = Icons.person;
    }
    if (label == "Cleaning") {
      color = Colors.purple;
      icon = Icons.cleaning_services;
    }
    if (label == "Maintenance") {
      color = Colors.red;
      icon = Icons.build;
    }
    return Container(
      width: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: const InputDecoration(
          icon: Icon(Icons.search, color: Colors.grey, size: 20),
          hintText: "Search room, guest or booking...",
          border: InputBorder.none,
          hintStyle: TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildFloorSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _floorFilter,
          style: const TextStyle(fontSize: 13, color: AdminTheme.darkNavy, fontWeight: FontWeight.bold),
          items: ["All Floors", "1st Floor", "2nd Floor", "3rd Floor", "4th Floor"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _floorFilter = v!),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _typeFilter,
          style: const TextStyle(fontSize: 13, color: AdminTheme.darkNavy, fontWeight: FontWeight.bold),
          items: ["All Types", "Executive Suite", "Deluxe Double", "Standard Twin"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _typeFilter = v!),
        ),
      ),
    );
  }

  Widget _buildRoomGrid() {
    final filtered = _rooms.where((r) {
      final matchesSearch = r.roomNumber.contains(_searchQuery) || (r.currentGuest?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesFloor = _floorFilter == "All Floors" || "${r.floor}st Floor" == _floorFilter || "${r.floor}nd Floor" == _floorFilter || "${r.floor}rd Floor" == _floorFilter || "${r.floor}th Floor" == _floorFilter;
      final matchesType = _typeFilter == "All Types" || r.type == _typeFilter;
      return matchesSearch && matchesFloor && matchesType;
    }).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildRoomCard(filtered[index]),
    );
  }

  Widget _buildRoomCard(HotelRoom room) {
    Color color = AdminTheme.emeraldGreen;
    if (room.occupancy == OccupancyStatus.Occupied) color = Colors.orange;
    if (room.occupancy == OccupancyStatus.Reserved) color = Colors.blue;
    if (room.condition == RoomCondition.Maintenance) color = Colors.red;
    if (room.condition == RoomCondition.Cleaning) color = Colors.purple;

    return InkWell(
      onTap: () => _showRoomDetails(room),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AdminTheme.softShadow,
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(room.roomNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                Icon(_getConditionIcon(room.condition), size: 14, color: color),
              ],
            ),
            const SizedBox(height: 2),
            Text(room.type, style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            if (room.currentGuest != null) Text(room.currentGuest!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis) else Text("VACANT", style: TextStyle(color: AdminTheme.emeraldGreen.withValues(alpha: 0.7), fontWeight: FontWeight.w900, fontSize: 10)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(room.occupancy.name.toUpperCase(), style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900)),
                ),
                Text("F${room.floor}", style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getConditionIcon(RoomCondition condition) {
    switch (condition) {
      case RoomCondition.Clean: return Icons.check_circle;
      case RoomCondition.Dirty: return Icons.error_outline;
      case RoomCondition.Cleaning: return Icons.cleaning_services;
      case RoomCondition.Maintenance: return Icons.build;
      default: return Icons.help_outline;
    }
  }

  // --- 2. ALL ROOMS TABLE ---
  Widget _buildAllRoomsTable() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AdminTheme.softShadow),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AdminTheme.royalBlue.withValues(alpha: 0.05)),
        columns: const [
          DataColumn(label: Text("Room")),
          DataColumn(label: Text("Type")),
          DataColumn(label: Text("Occupancy")),
          DataColumn(label: Text("Condition")),
          DataColumn(label: Text("Guest")),
          DataColumn(label: Text("Actions")),
        ],
        rows: _rooms.map((r) => DataRow(cells: [
          DataCell(Text(r.roomNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(r.type)),
          DataCell(_buildStatusBadge(r.occupancy.name, AdminTheme.royalBlue)),
          DataCell(_buildStatusBadge(r.condition.name, Colors.orange)),
          DataCell(Text(r.currentGuest ?? "-")),
          DataCell(IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _showRoomDetails(r))),
        ])).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showRoomDetails(HotelRoom room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text("Room ${room.roomNumber} Details", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            // Add details as needed
          ],
        ),
      ),
    );
  }

  // --- 3. HOUSEKEEPING ---
  Widget _buildHousekeepingView() {
    final cleaningQueue = _rooms.where((r) => r.condition == RoomCondition.Dirty || r.condition == RoomCondition.Cleaning).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Housekeeping Queue", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cleaningQueue.length,
          itemBuilder: (context, index) {
            final r = cleaningQueue[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
              child: Row(
                children: [
                  const Icon(Icons.cleaning_services, color: Colors.purple),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Room ${r.roomNumber}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("Status: ${r.condition.name} • Last checked: 2h ago", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildStatusBadge("URGENT", Colors.red),
                  const SizedBox(width: 16),
                  ElevatedButton(onPressed: () {}, child: const Text("ASSIGN")),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // --- 4. MAINTENANCE ---
  Widget _buildMaintenanceView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Active Requests", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text("NEW REQUEST")),
          ],
        ),
        const SizedBox(height: 24),
        ..._maintenanceRequests.map((m) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AdminTheme.softShadow),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Room ${m.roomNumber} - ${m.category}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _buildStatusBadge(m.priority.name, m.priority == MaintenancePriority.Urgent ? Colors.red : Colors.orange),
                ],
              ),
              const SizedBox(height: 8),
              Text(m.description, style: const TextStyle(color: Colors.grey)),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Assigned to: ${m.technician ?? 'Pending'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("Reported at: ${DateFormat('MMM dd, HH:mm').format(m.reportedAt)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  Row(
                    children: [
                      if (m.status != MaintenanceStatus.Resolved) OutlinedButton(onPressed: () {}, child: const Text("UPDATE STATUS")),
                      const SizedBox(width: 8),
                      _buildStatusBadge(m.status.name, _getMaintenanceStatusColor(m.status)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        )),
      ],
    );
  }

  Color _getMaintenanceStatusColor(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.Reported:
        return Colors.blue;
      case MaintenanceStatus.Assigned:
        return Colors.orange;
      case MaintenanceStatus.InProgress:
        return Colors.purple;
      case MaintenanceStatus.Resolved:
        return AdminTheme.emeraldGreen;
      default:
        return Colors.grey;
    }
  }

  // --- 5. ROOM INSPECTION ---
  Widget _buildInspectionView() {
    final inspectionQueue = _rooms.where((r) => r.housekeeping == HousekeepingStatus.InspectionPending).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Inspection Queue", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text("Rooms requiring final approval before becoming Available.", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 24),
        if (inspectionQueue.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No rooms pending inspection."))) else ...inspectionQueue.map((r) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
          child: Row(
            children: [
              const Icon(Icons.fact_check, color: Colors.blue, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Room ${r.roomNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("${r.type} • Cleaned by: staff_01", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _showInspectionDialog(r),
                style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue),
                child: const Text("START INSPECTION"),
              ),
            ],
          ),
        )),
      ],
    );
  }

  void _showInspectionDialog(HotelRoom room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Inspect Room ${room.roomNumber}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInspectionCheckItem("Bedding & Linen perfectly placed"),
            _buildInspectionCheckItem("Bathroom cleaned & amenities restocked"),
            _buildInspectionCheckItem("Electronic devices (TV/AC) working"),
            _buildInspectionCheckItem("Mini-bar inventory checked"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FAIL (SEND TO HK)")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("PASS & MAKE AVAILABLE")),
        ],
      ),
    );
  }

  Widget _buildInspectionCheckItem(String label) {
    bool isChecked = true;
    return StatefulBuilder(
      builder: (context, setModalState) {
        return CheckboxListTile(
          value: isChecked,
          onChanged: (v) => setModalState(() => isChecked = v!),
          title: Text(label, style: const TextStyle(fontSize: 13)),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        );
      }
    );
  }

  // --- 6. OUT OF SERVICE ---
  Widget _buildOutOfServiceView() {
    final oosRooms = _rooms.where((r) => r.condition == RoomCondition.OutOfOrder || r.condition == RoomCondition.OutOfService).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Out of Service Rooms", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.warning_amber), label: const Text("BLOCK ROOM")),
          ],
        ),
        const SizedBox(height: 24),
        if (oosRooms.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No rooms currently out of service."))) else ...oosRooms.map((r) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AdminTheme.softShadow,
            border: const Border(left: BorderSide(color: Colors.red, width: 4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Room ${r.roomNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Text("Reason: Major Renovation • Expected Restore: 25 Sep", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("Blocked by Admin on Aug 15. All furniture removed for polish.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              OutlinedButton(onPressed: () {}, child: const Text("RESTORE ROOM")),
            ],
          ),
        )),
      ],
    );
  }

  // --- 5. LOST & FOUND ---
  Widget _buildLostAndFoundView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Lost & Found Inventory", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AdminTheme.softShadow),
          child: DataTable(
            columns: const [
              DataColumn(label: Text("Item")),
              DataColumn(label: Text("Room")),
              DataColumn(label: Text("Date Found")),
              DataColumn(label: Text("Status")),
              DataColumn(label: Text("Actions")),
            ],
            rows: _lostAndFound.map((i) => DataRow(cells: [
              DataCell(Text(i.itemName, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(i.roomNumber)),
              DataCell(Text(DateFormat('dd/MM/yyyy').format(i.foundDate))),
              DataCell(_buildStatusBadge(i.status, i.status == "Claimed" ? AdminTheme.emeraldGreen : Colors.orange)),
              DataCell(TextButton(onPressed: () {}, child: const Text("VIEW"))),
            ])).toList(),
          ),
        ),
      ],
    );
  }

  // --- 6. ROOM SETTINGS ---
  Widget _buildRoomSettingsView() {
    if (_settingsSubMode == "Room Types") return _buildRoomTypesConfig();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Hotel Configuration", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildSettingsCard("Room Types", "Manage pricing, capacity and amenities for suites and rooms.", Icons.category_outlined, () => setState(() => _settingsSubMode = "Room Types")),
        _buildSettingsCard("Floors & Wings", "Configure layout structure and staff assignments.", Icons.layers_outlined, () {}),
        _buildSettingsCard("Inspection Checklist", "Define standard rules for room approval.", Icons.fact_check_outlined, () {}),
      ],
    );
  }

  Widget _buildRoomTypesConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(onPressed: () => setState(() => _settingsSubMode = "Main"), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16)),
            const Text("Room Types & Pricing", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text("NEW TYPE")),
          ],
        ),
        const SizedBox(height: 24),
        _buildTypeCard("Executive Suite", "NPR 18,000", "4 Guests", "12 Active Rooms"),
        _buildTypeCard("Deluxe Double", "NPR 12,500", "2 Guests", "24 Active Rooms"),
        _buildTypeCard("Standard Twin", "NPR 9,500", "2 Guests", "40 Active Rooms"),
      ],
    );
  }

  Widget _buildTypeCard(String name, String price, String cap, String count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AdminTheme.softShadow),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.king_bed_outlined, color: AdminTheme.royalBlue)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("$cap • $count", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(price, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminTheme.royalBlue, fontSize: 16)),
          const SizedBox(width: 16),
          _buildActionBtn(Icons.edit_outlined, AdminTheme.royalBlue, () {}),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: AdminTheme.royalBlue.withValues(alpha: 0.1), child: Icon(icon, color: AdminTheme.royalBlue, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildPlaceholderView() {
    return const Center(child: Text("Coming soon..."));
  }

  Widget _buildActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
