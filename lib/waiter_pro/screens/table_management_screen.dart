import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../theme.dart';
import 'digital_menu_screen.dart';
import 'running_order_summary_screen.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedTables = {};
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tables & Floor"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: WaiterProTheme.royalBlue,
          indicatorColor: WaiterProTheme.royalBlue,
          tabs: const [
            Tab(text: "Indoor"),
            Tab(text: "Roof"),
            Tab(text: "VIP"),
            Tab(text: "Reservations"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Search table number",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: "Clear search",
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children:
                  [
                        'All',
                        'Available',
                        'Occupied',
                        'KOT pending',
                        'Ready',
                        'Billing',
                        'Reserved',
                        'Dirty',
                      ]
                      .map(
                        (status) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(status),
                            selected: _statusFilter == status,
                            onSelected: (_) =>
                                setState(() => _statusFilter = status),
                            selectedColor: WaiterProTheme.royalBlue,
                            labelStyle: TextStyle(
                              color: _statusFilter == status
                                  ? Colors.white
                                  : WaiterProTheme.darkNavy,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              "Long-press a table to select it for a future merge or transfer.",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTableGrid(100),
                _buildTableGrid(200),
                _buildTableGrid(300),
                _buildReservations(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showComingSoon(
                    "Table merge",
                    "Select tables to preview this action. Order transfer is not connected yet.",
                  ),
                  icon: const Icon(Icons.merge_type),
                  label: Text(
                    _selectedTables.isEmpty
                        ? "Merge"
                        : "Merge (${_selectedTables.length})",
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    side: const BorderSide(color: WaiterProTheme.royalBlue),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showComingSoon(
                    "Table transfer",
                    "Selected table orders cannot be moved until a server-backed transfer workflow is connected.",
                  ),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text("Transfer"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableGrid(int offset) {
    return ValueListenableBuilder<Map<int, String>>(
      valueListenable: ShopManager.instance.tableStatuses,
      builder: (context, statuses, child) {
        if (statuses.isEmpty) {
          ShopManager.instance.initializeTables(20);
          return const Center(child: CircularProgressIndicator());
        }

        final tableIds = List.generate(12, (index) => offset + index + 1).where(
          (id) {
            final query = _searchController.text.trim().toLowerCase();
            final status = statuses[id] ?? 'Available';
            return (query.isEmpty || id.toString().contains(query)) &&
                (_statusFilter == 'All' ||
                    _normalizedStatus(status) == _statusFilter);
          },
        ).toList();

        if (tableIds.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.table_restaurant_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _searchController.text.isNotEmpty
                        ? "No table matches this search."
                        : "No tables match this status.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: tableIds.length,
          itemBuilder: (context, index) {
            final tableId = tableIds[index];
            final rawStatus = statuses[tableId] ?? 'Available';
            final status = _normalizedStatus(rawStatus);
            final selected = _selectedTables.contains(tableId);
            final isOccupied = rawStatus == 'Dining';
            final color = _statusColor(status);

            return Semantics(
              button: true,
              selected: selected,
              label: "Table $tableId, $status",
              child: InkWell(
                onLongPress: () => _toggleTable(tableId),
                onTap: () {
                  if (_selectedTables.isNotEmpty) {
                    _toggleTable(tableId);
                  } else if (isOccupied) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RunningOrderSummaryScreen(tableId: "T-$tableId"),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DigitalMenuScreen(tableId: "T-$tableId"),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.14)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? color : color.withValues(alpha: 0.45),
                      width: selected ? 2 : 1.3,
                    ),
                    boxShadow: WaiterProTheme.softShadow,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? Icons.check_circle : _statusIcon(status),
                        color: color,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "T-$tableId",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: WaiterProTheme.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReservations() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WaiterProTheme.royalBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: WaiterProTheme.royalBlue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Reservation preview only — no booking data is connected.",
                  style: TextStyle(color: WaiterProTheme.darkNavy),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _reservationPreview("Sample booking", "Today • 7:00 PM", "4 guests"),
        _reservationPreview("Sample booking", "Today • 8:30 PM", "2 guests"),
      ],
    );
  }

  Widget _reservationPreview(String name, String time, String guests) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEAF0FA),
          child: Icon(Icons.event_available, color: WaiterProTheme.royalBlue),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$time • $guests"),
        trailing: const Text(
          "DEMO",
          style: TextStyle(
            color: Colors.orange,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _toggleTable(int tableId) {
    setState(() {
      if (!_selectedTables.add(tableId)) _selectedTables.remove(tableId);
    });
  }

  void _showComingSoon(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("GOT IT"),
          ),
        ],
      ),
    );
  }

  String _normalizedStatus(String status) {
    switch (status.toLowerCase()) {
      case 'dining':
      case 'occupied':
        return 'Occupied';
      case 'kot pending':
      case 'pending':
      case 'new order':
        return 'KOT pending';
      case 'ready':
        return 'Ready';
      case 'billing':
      case 'bill requested':
        return 'Billing';
      case 'dirty':
      case 'needs cleaning':
        return 'Dirty';
      case 'reserved':
        return 'Reserved';
      default:
        return 'Available';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Occupied':
        return WaiterProTheme.royalBlue;
      case 'KOT pending':
        return Colors.orange.shade800;
      case 'Ready':
        return WaiterProTheme.emeraldGreen;
      case 'Billing':
        return Colors.deepPurple;
      case 'Dirty':
        return Colors.brown;
      case 'Reserved':
        return Colors.teal;
      default:
        return Colors.green.shade700;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Occupied':
        return Icons.people_alt;
      case 'KOT pending':
        return Icons.pending_actions;
      case 'Ready':
        return Icons.room_service;
      case 'Billing':
        return Icons.receipt_long;
      case 'Dirty':
        return Icons.cleaning_services;
      case 'Reserved':
        return Icons.event_seat;
      default:
        return Icons.event_available;
    }
  }
}
