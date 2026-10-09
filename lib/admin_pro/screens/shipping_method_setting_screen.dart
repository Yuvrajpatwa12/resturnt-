import 'package:flutter/material.dart';
import '../admin_theme.dart';

class ShippingMethodSettingScreen extends StatefulWidget {
  final String mode;
  const ShippingMethodSettingScreen({super.key, this.mode = "Shipping Method Setting"});

  @override
  State<ShippingMethodSettingScreen> createState() => _ShippingMethodSettingScreenState();
}

class _ShippingMethodSettingScreenState extends State<ShippingMethodSettingScreen> {
  final List<Map<String, dynamic>> _shippingMethods = [
    {
      'id': 'dine_in',
      'name': 'Dine-In Service',
      'type': 'Table Order',
      'icon': Icons.restaurant_rounded,
      'color': const Color(0xFF0047AB),
      'isActive': true,
      'feeType': 'Free (0 NPR)',
      'feeAmount': 0.0,
      'minOrder': 'NPR 0',
      'estTime': '10 - 20 Mins',
      'maxRadius': 'Inside Restaurant',
      'description': 'Direct table dining service delivered by restaurant waiters.',
    },
    {
      'id': 'takeaway',
      'name': 'Takeaway / Parcel Pickup',
      'type': 'Self Pickup',
      'icon': Icons.takeout_dining_rounded,
      'color': const Color(0xFF10B981),
      'isActive': true,
      'feeType': 'Packaging Fee',
      'feeAmount': 15.0,
      'minOrder': 'NPR 0',
      'estTime': '15 - 25 Mins',
      'maxRadius': 'Store Counter',
      'description': 'Packaged food ready for customer self-pickup at counter.',
    },
    {
      'id': 'inhouse_delivery',
      'name': 'In-House Rider Delivery',
      'type': 'Local Delivery',
      'icon': Icons.delivery_dining_rounded,
      'color': const Color(0xFFF59E0B),
      'isActive': true,
      'feeType': 'Distance Based (KM Tier)',
      'feeAmount': 60.0,
      'minOrder': 'NPR 300',
      'estTime': '25 - 40 Mins',
      'maxRadius': '8 KM',
      'description': 'Delivered directly by restaurant riders with hot bag containers.',
    },
    {
      'id': 'pathao_courier',
      'name': 'Pathao / Foodmandu Partner',
      'type': 'Third-Party Logistics',
      'icon': Icons.two_wheeler_rounded,
      'color': const Color(0xFFEF4444),
      'isActive': true,
      'feeType': 'Partner Calculated API',
      'feeAmount': 80.0,
      'minOrder': 'NPR 250',
      'estTime': '20 - 35 Mins',
      'maxRadius': '12 KM',
      'description': 'Automated rider dispatch via Pathao / Foodmandu logistics network.',
    },
    {
      'id': 'express_delivery',
      'name': 'VIP Express Delivery',
      'type': 'Priority Delivery',
      'icon': Icons.electric_bolt_rounded,
      'color': const Color(0xFF8B5CF6),
      'isActive': false,
      'feeType': 'Flat Rate',
      'feeAmount': 150.0,
      'minOrder': 'NPR 500',
      'estTime': '15 - 25 Mins',
      'maxRadius': '5 KM',
      'description': 'Guaranteed priority dispatch within 25 minutes.',
    },
  ];

  final _freeShippingThresholdCtrl = TextEditingController(text: "1500");
  final _defaultBaseDeliveryFeeCtrl = TextEditingController(text: "50");
  final _perKmRateCtrl = TextEditingController(text: "15");

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(),
          const SizedBox(height: 24),
          _buildGlobalDeliveryRulesCard(),
          const SizedBox(height: 24),
          _buildMethodsHeader(),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _shippingMethods.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildShippingCard(_shippingMethods[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminTheme.darkNavy, Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Shipping & Delivery Settings",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  "Configure delivery methods, distance-based pricing models, free shipping order limits, and rider dispatch rules.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAddShippingModal(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.emeraldGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_location_alt_rounded, size: 20),
            label: const Text("ADD SHIPPING METHOD", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalDeliveryRulesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_rounded, color: AdminTheme.royalBlue, size: 22),
              SizedBox(width: 10),
              Text(
                "Global Delivery Calculation Engine",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _freeShippingThresholdCtrl,
                  decoration: InputDecoration(
                    labelText: "Free Delivery Minimum Threshold (NPR)",
                    prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AdminTheme.royalBlue),
                    filled: true,
                    fillColor: AdminTheme.pearlWhite,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _defaultBaseDeliveryFeeCtrl,
                  decoration: InputDecoration(
                    labelText: "Base Delivery Charge (0 - 3 KM)",
                    prefixIcon: const Icon(Icons.payments_outlined, color: AdminTheme.royalBlue),
                    filled: true,
                    fillColor: AdminTheme.pearlWhite,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _perKmRateCtrl,
                  decoration: InputDecoration(
                    labelText: "Additional Rate / KM (NPR)",
                    prefixIcon: const Icon(Icons.add_road_rounded, color: AdminTheme.royalBlue),
                    filled: true,
                    fillColor: AdminTheme.pearlWhite,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text(
          "Available Delivery Channels & Rates",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
        ),
        Text(
          "5 Channels Configured",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildShippingCard(Map<String, dynamic> method) {
    final Color color = method['color'] as Color;
    final bool isActive = method['isActive'] as bool;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
        border: Border.all(
          color: isActive ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(method['icon'] as IconData, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      method['name'],
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        method['type'],
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  method['description'],
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildMetaChip("Pricing Model", method['feeType'], Icons.style_rounded),
                    _buildMetaChip("Min Order", method['minOrder'], Icons.shopping_bag_outlined),
                    _buildMetaChip("Est. Time", method['estTime'], Icons.timer_outlined),
                    _buildMetaChip("Max Radius", method['maxRadius'], Icons.map_outlined),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    isActive ? "ACTIVE" : "DISABLED",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AdminTheme.emeraldGreen : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: isActive,
                    activeColor: AdminTheme.emeraldGreen,
                    onChanged: (val) {
                      setState(() {
                        method['isActive'] = val;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showEditShippingModal(context, method),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminTheme.royalBlue,
                  side: const BorderSide(color: AdminTheme.royalBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text("EDIT RATES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminTheme.pearlWhite,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text("$label: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
        ],
      ),
    );
  }

  void _showAddShippingModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final estTimeCtrl = TextEditingController(text: "20 - 30 Mins");
    final minOrderCtrl = TextEditingController(text: "NPR 200");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Add New Delivery Channel", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: "Channel Name",
                hintText: "e.g. Express Drone Delivery / Area Courier",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: estTimeCtrl,
              decoration: InputDecoration(
                labelText: "Estimated Delivery Time",
                hintText: "e.g. 20 - 30 Mins",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minOrderCtrl,
              decoration: InputDecoration(
                labelText: "Minimum Order Amount",
                hintText: "e.g. NPR 200",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      _shippingMethods.add({
                        'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        'name': nameCtrl.text.trim(),
                        'type': 'Custom Delivery',
                        'icon': Icons.local_shipping_outlined,
                        'color': AdminTheme.royalBlue,
                        'isActive': true,
                        'feeType': 'Flat Rate',
                        'feeAmount': 50.0,
                        'minOrder': minOrderCtrl.text.trim(),
                        'estTime': estTimeCtrl.text.trim(),
                        'maxRadius': '10 KM',
                        'description': 'Custom shipping channel configured by admin.',
                      });
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("New Shipping Channel Added!")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.royalBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("CREATE SHIPPING METHOD", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditShippingModal(BuildContext context, Map<String, dynamic> method) {
    final estTimeCtrl = TextEditingController(text: method['estTime']);
    final minOrderCtrl = TextEditingController(text: method['minOrder']);
    final maxRadiusCtrl = TextEditingController(text: method['maxRadius']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Edit ${method['name']} Rates", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: estTimeCtrl,
              decoration: const InputDecoration(labelText: "Estimated Delivery Duration"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: minOrderCtrl,
              decoration: const InputDecoration(labelText: "Minimum Order Amount"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: maxRadiusCtrl,
              decoration: const InputDecoration(labelText: "Maximum Service Radius"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                method['estTime'] = estTimeCtrl.text.trim();
                method['minOrder'] = minOrderCtrl.text.trim();
                method['maxRadius'] = maxRadiusCtrl.text.trim();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${method['name']} rates updated!")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue),
            child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
