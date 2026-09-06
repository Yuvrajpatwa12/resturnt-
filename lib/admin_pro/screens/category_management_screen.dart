import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class CategoryManagementScreen extends StatefulWidget {
  final String mode;
  const CategoryManagementScreen({super.key, required this.mode});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _nameController = TextEditingController();
  final _rankController = TextEditingController(text: "1");
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _rankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mode == "Add Category") _buildAddCategoryForm()
          else _buildCategoryListView(),
        ],
      ),
    );
  }

  Widget _buildCategoryListView() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: TenantService().categories,
      builder: (context, categories, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("All Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () {
                    final tenant = TenantService().currentTenant.value;
                    if (tenant != null) TenantService().fetchMenuData(tenant.id);
                  }, 
                  icon: const Icon(Icons.refresh, color: AdminTheme.royalBlue)
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (categories.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No categories found.")))
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AdminTheme.softShadow,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 20),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.category_outlined, color: AdminTheme.royalBlue, size: 20),
                            ),
                            IconButton(
                              onPressed: () => _deleteCategory(cat['id'].toString()),
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(cat['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
                        Text("Rank: ${cat['rank'] ?? '0'}", style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCategory(String id) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Category?"),
        content: const Text("This will remove the category. Make sure no products are assigned to it."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.deleteCategory(tenant.id, id);
      if (res['success'] == true) {
        TenantService().fetchMenuData(tenant.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Category deleted.")));
      }
    }
  }

  Widget _buildAddCategoryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Create New Category", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        _buildTextField("Category Name", _nameController, hint: "e.g. Beverages"),
        const SizedBox(height: 16),
        _buildTextField("Display Rank", _rankController, hint: "1"),
        const SizedBox(height: 32),
        if (_isSubmitting)
          const Center(child: CircularProgressIndicator())
        else
          ElevatedButton(
            onPressed: _submitCategory,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
            child: const Text("SAVE CATEGORY TO DATABASE"),
          ),
      ],
    );
  }

  Future<void> _submitCategory() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isSubmitting = true);
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final success = await ApiService.addCategory(
      tenant.id, 
      _nameController.text, 
      int.tryParse(_rankController.text) ?? 1
    );

    setState(() => _isSubmitting = false);
    if (success) {
      _nameController.clear();
      TenantService().fetchMenuData(tenant.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Category added successfully!"), backgroundColor: Colors.green));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to add category."), backgroundColor: Colors.red));
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
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
