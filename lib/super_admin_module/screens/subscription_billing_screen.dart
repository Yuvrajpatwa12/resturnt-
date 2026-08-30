import 'package:flutter/material.dart';
import '../styles.dart';

class SubscriptionBillingScreen extends StatefulWidget {
  const SubscriptionBillingScreen({super.key});

  @override
  State<SubscriptionBillingScreen> createState() => _SubscriptionBillingScreenState();
}

class _SubscriptionBillingScreenState extends State<SubscriptionBillingScreen> {
  // Filter state: 'All', 'Active', 'Expired', 'Free Trial'
  String _selectedFilter = 'All';

  // Mutable subscription plans data
  final List<Map<String, dynamic>> _plans = [
    {
      'title': '3 Days Free Trial',
      'duration': '3 Days',
      'price': 'NPR 0',
      'perks': 'Full Access • No Credit Card',
      'color': Colors.teal,
    },
    {
      'title': 'Monthly Starter',
      'duration': '28 Days',
      'price': 'NPR 799',
      'perks': 'Standard Features • 1 Store',
      'color': SAMStyles.royalBlue,
    },
    {
      'title': '3 Months Pro',
      'duration': '84 Days',
      'price': 'NPR 2,396.52',
      'perks': 'Priority Support • Advanced Analytics',
      'color': SAMStyles.darkNavy,
    },
    {
      'title': '6 Months Enterprise',
      'duration': '168 Days',
      'price': 'NPR 4,793.04',
      'perks': 'Unlimited • Multi-Store Ready',
      'color': SAMStyles.emeraldGreen,
    },
  ];

  // All store subscriptions demo data
  final List<Map<String, dynamic>> _storeSubscriptions = [
    {'name': 'Cafe Himalaya', 'plan': '3 Months Pro', 'daysPassed': '45 Days', 'daysLeft': '39 Days', 'status': 'Active', 'type': 'Paid'},
    {'name': 'Momo Station', 'plan': 'Monthly Starter', 'daysPassed': '20 Days', 'daysLeft': '8 Days', 'status': 'Active', 'type': 'Paid'},
    {'name': 'Boudha Bakery', 'plan': '6 Months Enterprise', 'daysPassed': '150 Days', 'daysLeft': '18 Days', 'status': 'Active', 'type': 'Paid'},
    {'name': 'Spice Garden', 'plan': '3 Days Free Trial', 'daysPassed': '3 Days', 'daysLeft': 'Expired', 'status': 'Expired', 'type': 'Trial'},
    {'name': 'Lakeside Café', 'plan': '3 Days Free Trial', 'daysPassed': '1 Day', 'daysLeft': '2 Days', 'status': 'Active', 'type': 'Trial'},
    {'name': 'Everest Dine', 'plan': 'Monthly Starter', 'daysPassed': '28 Days', 'daysLeft': 'Expired', 'status': 'Expired', 'type': 'Paid'},
  ];

  void _editPlan(int index) {
    final plan = _plans[index];
    final titleController = TextEditingController(text: plan['title']);
    final durationController = TextEditingController(text: plan['duration']);
    final priceController = TextEditingController(text: plan['price']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Plan: ${plan['title']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Plan Title"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(labelText: "Duration (e.g., 28 Days / 3 Months)"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: "Price (e.g., NPR 799)"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: SAMStyles.royalBlue, foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  _plans[index] = {
                    'title': titleController.text,
                    'duration': durationController.text,
                    'price': priceController.text,
                    'perks': plan['perks'],
                    'color': plan['color'],
                  };
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Plan updated successfully!")),
                );
              },
              child: const Text("Save Changes"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtering logic based on selected chip
    final filteredStores = _storeSubscriptions.where((store) {
      if (_selectedFilter == 'Active') {
        return store['status'] == 'Active';
      } else if (_selectedFilter == 'Expired') {
        return store['status'] == 'Expired';
      } else if (_selectedFilter == 'Free Trial') {
        return store['type'] == 'Trial';
      }
      return true; // 'All'
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Subscription & Plan Manager", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("Manage pricing tiers and monitor all restaurant subscription cycles.", style: TextStyle(color: SAMStyles.textGrey)),
          const SizedBox(height: 24),
          _buildPlanTierGrid(),
          const SizedBox(height: 40),
          _buildActiveRestaurantsSubscriptionList(filteredStores),
          const SizedBox(height: 40),
          _buildPaymentHistory(),
        ],
      ),
    );
  }

  // ================= 4 SUBSCRIPTION PLANS GRID =================
  Widget _buildPlanTierGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: _plans.asMap().entries.map((entry) {
            final index = entry.key;
            final plan = entry.value;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < _plans.length - 1 ? 16 : 0),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: SAMStyles.softShadow,
                  border: Border.all(color: (plan['color'] as Color).withOpacity(0.2), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan['title'], style: TextStyle(color: plan['color'], fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Text(plan['price'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    Text(plan['duration'], style: const TextStyle(color: SAMStyles.textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text(plan['perks'], style: const TextStyle(color: SAMStyles.textGrey, fontSize: 12)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _editPlan(index),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: plan['color']),
                          foregroundColor: plan['color'],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text("EDIT PLAN"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ================= RESTAURANT SUBSCRIPTION MONITORING WITH FILTER =================
  Widget _buildActiveRestaurantsSubscriptionList(List<Map<String, dynamic>> filteredStores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Restaurant Subscription Monitoring", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Filter by running, expired, or free trial users.", style: TextStyle(color: SAMStyles.textGrey, fontSize: 12)),
              ],
            ),
            // Filter Chips Bar
            Wrap(
              spacing: 8,
              children: ['All', 'Active', 'Expired', 'Free Trial'].map((filterName) {
                final isSelected = _selectedFilter == filterName;
                return ChoiceChip(
                  label: Text(filterName),
                  selected: isSelected,
                  selectedColor: SAMStyles.royalBlue,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = filterName;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: SAMStyles.softShadow),
          child: filteredStores.isEmpty
              ? const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: Text("No restaurants found for this filter.", style: TextStyle(color: SAMStyles.textGrey))),
          )
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredStores.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (context, index) {
              final store = filteredStores[index];
              final isExpired = store['status'] == 'Expired';
              final isTrial = store['type'] == 'Trial';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                leading: CircleAvatar(
                  backgroundColor: isExpired ? Colors.red.withOpacity(0.1) : (isTrial ? Colors.teal.withOpacity(0.1) : SAMStyles.royalBlue.withOpacity(0.1)),
                  child: Icon(Icons.store, color: isExpired ? Colors.red : (isTrial ? Colors.teal : SAMStyles.royalBlue)),
                ),
                title: Row(
                  children: [
                    Text(store['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (isTrial) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Text("TRIAL", style: TextStyle(color: Colors.teal, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                subtitle: Text("Plan: ${store['plan']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Passed: ${store['daysPassed']}", style: const TextStyle(fontSize: 12, color: SAMStyles.textGrey)),
                        Text("Left: ${store['daysLeft']}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isExpired ? Colors.red : SAMStyles.emeraldGreen)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isExpired ? Colors.red : SAMStyles.emeraldGreen).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(store['status']!, style: TextStyle(color: isExpired ? Colors.red : SAMStyles.emeraldGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= PAYMENT HISTORY =================
  Widget _buildPaymentHistory() {
    final payments = [
      {'id': '#INV-982', 'client': 'Cafe Himalaya', 'amount': 'NPR 2,396.52', 'status': 'Paid'},
      {'id': '#INV-981', 'client': 'Momo Station', 'amount': 'NPR 799.00', 'status': 'Pending'},
      {'id': '#INV-980', 'client': 'Boudha Bakery', 'amount': 'NPR 4,793.04', 'status': 'Paid'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Revenue & Earnings History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: SAMStyles.softShadow),
          child: Column(
            children: payments.map((p) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              leading: const Icon(Icons.receipt_long, color: SAMStyles.royalBlue),
              title: Text(p['client']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(p['id']!),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p['amount']!, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (p['status'] == 'Paid' ? SAMStyles.emeraldGreen : Colors.orange).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(p['status']!, style: TextStyle(color: p['status'] == 'Paid' ? SAMStyles.emeraldGreen : Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}