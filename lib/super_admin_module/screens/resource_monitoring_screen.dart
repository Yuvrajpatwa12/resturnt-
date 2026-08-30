import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../styles.dart';

class ResourceMonitoringScreen extends StatefulWidget {
  const ResourceMonitoringScreen({super.key});

  @override
  State<ResourceMonitoringScreen> createState() => _ResourceMonitoringScreenState();
}

class _ResourceMonitoringScreenState extends State<ResourceMonitoringScreen> {
  List<Map<String, dynamic>> _resources = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchResourceUsage();
    if (data != null) {
      setState(() => _resources = data);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _resources.where((s) => s['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Resource Monitoring Hub", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("Live database latency and storage tracking per restaurant tenant.", style: TextStyle(color: SAMStyles.textGrey)),
          const SizedBox(height: 32),
          _buildGlobalMetrics(),
          const SizedBox(height: 40),
          _buildTableControls(),
          const SizedBox(height: 16),
          if (_isLoading) 
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else
            _buildResourceTable(filteredList),
        ],
      ),
    );
  }

  Widget _buildGlobalMetrics() {
    return Row(
      children: [
        _buildMiniStat("Network Traffic", "5.9k / min", Icons.speed, SAMStyles.royalBlue),
        const SizedBox(width: 24),
        _buildMiniStat("Avg. Latency", "48 ms", Icons.bolt, Colors.orange),
        const SizedBox(width: 24),
        _buildMiniStat("Total Storage", "5.2 GB", Icons.storage, SAMStyles.emeraldGreen),
      ],
    );
  }

  Widget _buildMiniStat(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: SAMStyles.softShadow),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: SAMStyles.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildTableControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Tenant Infrastructure Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(
          width: 300,
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: "Search tenant...",
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResourceTable(List<Map<String, dynamic>> data) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: SAMStyles.softShadow),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final s = data[index];
          final double used = s['storage_used'];
          final double limit = s['storage_limit'];
          final double percent = used / limit;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(s['health'], style: const TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.w900))),
                  ]),
                ),
                Expanded(
                  flex: 4,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Storage: $used / $limit GB", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), const Text("82%", style: TextStyle(fontSize: 10, color: Colors.grey))]),
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: percent, backgroundColor: Colors.grey[100], color: SAMStyles.royalBlue, minHeight: 6)),
                  ]),
                ),
                const SizedBox(width: 40),
                Expanded(
                  flex: 2,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("API Latency", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(s['api_latency'], style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.orange, fontSize: 12)),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
