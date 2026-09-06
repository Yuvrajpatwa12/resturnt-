import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../pages/order_details_page.dart';

class TablesTab extends StatefulWidget {
  const TablesTab({super.key});

  @override
  State<TablesTab> createState() => _TablesTabState();
}

class _TablesTabState extends State<TablesTab> {
  int _selectedFloor = 1; // 1 for 1F, 2 for 2F

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- FLOOR SWITCHER ---
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              _buildFloorChip("1F Hall", _selectedFloor == 1, () => setState(() => _selectedFloor = 1)),
              _buildFloorChip("2F Hall", _selectedFloor == 2, () => setState(() => _selectedFloor = 2)),
              const Spacer(),
              const Text("EDIT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
              const SizedBox(width: 10),
              const Icon(Icons.add_circle_outline, size: 16, color: Colors.grey),
            ],
          ),
        ),
        
        Expanded(
          child: ValueListenableBuilder<Map<int, String>>(
            valueListenable: ShopManager.instance.tableStatuses,
            builder: (context, statuses, child) {
              // Filter IDs based on floor (1xx or 2xx)
              final floorPrefix = _selectedFloor * 100;
              final List<int> tableIds = statuses.keys
                  .where((id) => id > floorPrefix && id <= floorPrefix + 20)
                  .toList();
              tableIds.sort();

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: tableIds.length,
                itemBuilder: (context, index) {
                  final int id = tableIds[index];
                  final String status = statuses[id] ?? "Available";
                  return _buildFloorTableCard(context, id, status);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFloorChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5C00) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[200]!),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey, 
            fontSize: 11, 
            fontWeight: FontWeight.bold
          )
        ),
      ),
    );
  }

  Widget _buildFloorTableCard(BuildContext context, int id, String status) {
    bool isOccupied = status == "Dining";
    bool isBilled = status == "Billed";
    bool needsHelp = status == "Help Needed";
    
    // Display ID as 01, 02...
    String displayId = (id % 100).toString().padLeft(2, '0');
    String floorName = id < 200 ? "1F" : "2F";

    return GestureDetector(
      onTap: () {
        if (isOccupied || isBilled || needsHelp) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailsPage(tableId: id)));
        } else {
          ShopManager.instance.activeStaffTableId.value = id;
          ShopManager.instance.waiterTabIndex.value = 1; // Menus Tab
        }
      },
      child: ValueListenableBuilder<Map<int, int>>(
        valueListenable: ShopManager.instance.tableCountdownTimers,
        builder: (context, timers, child) {
          final int secondsLeft = timers[id] ?? 0;
          final bool isReady = isOccupied && secondsLeft <= 0;
          final int totalSeconds = ShopManager.instance.tableOriginalDurations.value[id] ?? 1;
          final double progress = secondsLeft / totalSeconds;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isReady || isBilled ? Colors.green : (isOccupied ? const Color(0xFFFF5C00).withValues(alpha: 0.3) : Colors.grey[100]!),
                width: 2,
              ),
              boxShadow: [
                if (isOccupied || isBilled)
                  BoxShadow(
                    color: (isReady || isBilled ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isOccupied && !isReady)
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2,
                      color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$floorName - $displayId", 
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: 10, 
                        color: (isOccupied || isBilled) ? Colors.black87 : Colors.grey[300]
                      )
                    ),
                    if (isOccupied) ...[
                      const SizedBox(height: 4),
                      if (isReady)
                        _buildStatusBadge("READY", Colors.green)
                      else
                        Text(
                          "${(secondsLeft / 60).floor()}:${(secondsLeft % 60).toString().padLeft(2, '0')}",
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00)),
                        ),
                      const SizedBox(height: 2),
                      const Text(
                        "VIEW ALL",
                        style: TextStyle(fontSize: 6, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 0.5),
                      ),
                    ] else if (isBilled)
                      _buildStatusBadge("BILLED", Colors.green)
                    else
                      const Icon(Icons.crop_square, color: Colors.grey, size: 18),
                  ],
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
    );
  }
}
