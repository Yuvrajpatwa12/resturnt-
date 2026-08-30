import 'package:flutter/material.dart';
import '../theme.dart';

class OrderCustomizationDialog extends StatefulWidget {
  final String itemName;
  final Function(String notes) onSave;

  const OrderCustomizationDialog({super.key, required this.itemName, required this.onSave});

  @override
  State<OrderCustomizationDialog> createState() => _OrderCustomizationDialogState();
}

class _OrderCustomizationDialogState extends State<OrderCustomizationDialog> {
  String _selectedVariant = 'Regular';
  final List<String> _addOns = [];
  final _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Customize Item", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            Text(
              widget.itemName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: WaiterProTheme.darkNavy),
            ),
            const SizedBox(height: 24),
            const Text("Select Variant", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: ['Small', 'Regular', 'Large'].map((variant) {
                bool isSelected = _selectedVariant == variant;
                return ChoiceChip(
                  label: Text(variant),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _selectedVariant = variant),
                  selectedColor: WaiterProTheme.royalBlue,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : WaiterProTheme.darkNavy),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text("Add-ons", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildAddOn("Extra Sugar", "NPR 20"),
            _buildAddOn("Honey Substitute", "NPR 50"),
            _buildAddOn("Extra Ginger", "NPR 10"),
            const SizedBox(height: 24),
            const Text("Special Instructions", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "E.g. Less spicy, make it extra hot...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                widget.onSave(_notesController.text);
                Navigator.pop(context);
              },
              child: const Text("ADD TO ORDER"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOn(String name, String price) {
    bool isSelected = _addOns.contains(name);
    return CheckboxListTile(
      title: Text(name),
      subtitle: Text(price, style: const TextStyle(color: WaiterProTheme.royalBlue, fontWeight: FontWeight.bold)),
      value: isSelected,
      onChanged: (val) {
        setState(() {
          if (val!) {
            _addOns.add(name);
          } else {
            _addOns.remove(name);
          }
        });
      },
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: WaiterProTheme.royalBlue,
    );
  }
}
