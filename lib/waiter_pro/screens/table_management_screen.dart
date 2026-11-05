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
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
            Tab(text: "Tables"),
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTableGrid(),
                _buildReservations(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableGrid() {
    return ValueListenableBuilder<Map<int, String>>(
      valueListenable: ShopManager.instance.tableStatuses,
      builder: (context, statuses, child) {
        if (statuses.isEmpty) {
          ShopManager.instance.initializeTables();
          return const Center(child: CircularProgressIndicator());
        }

        final tableIds = statuses.keys.where((id) {
          final query = _searchController.text.trim().toLowerCase();
          final status = statuses[id] ?? 'Available';
          return (query.isEmpty || id.toString().contains(query)) &&
              (_statusFilter == 'All' ||
                  _normalizedStatus(status) == _statusFilter);
        }).toList()..sort();

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
            final isOccupied = [
              'dining',
              'readyforbilling',
            ].contains(rawStatus.toLowerCase());
            final color = _statusColor(status);

            return Semantics(
              button: true,
              label: "Table $tableId, $status",
              child: InkWell(
                onTap: () {
                  if (isOccupied) {
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withValues(alpha: 0.45),
                      width: 1.3,
                    ),
                    boxShadow: WaiterProTheme.softShadow,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _statusIcon(status),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          "No reservation records are available for this restaurant.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
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
      case 'readyforbilling':
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
