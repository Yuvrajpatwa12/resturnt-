import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class FoodCatalogScreen extends StatefulWidget {
  final String mode;
  const FoodCatalogScreen({super.key, required this.mode});

  @override
  State<FoodCatalogScreen> createState() => _FoodCatalogScreenState();
}

class _FoodCatalogScreenState extends State<FoodCatalogScreen> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedCategoryId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mode == "Add Food") _buildAddFoodForm()
          else if (widget.mode == "Food Variant") _buildFoodVariantView()
          else if (widget.mode == "Food Availability") _buildAvailabilityView()
          else _buildFoodListView(),
        ],
      ),
    );
  }

  Widget _buildFoodListView() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: TenantService().products,
      builder: (context, products, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.mode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.search, color: AdminTheme.royalBlue)),
              ],
            ),
            const SizedBox(height: 16),
            if (products.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No products found in database.")))
            else
              ...products.map((p) => _buildFoodItemCard(p)),
          ],
        );
      },
    );
  }

  Widget _buildFoodItemCard(Map<String, dynamic> p) {
    final String title = p['title'] ?? 'Untitled Item';
    final String category = p['tag'] ?? 'Uncategorized';
    final String price = p['price']?.toString() ?? '0.00';
    final String description = p['description'] ?? 'Delicious freshly prepared item.';
    final String image = (p['image_url'] != null && p['image_url'].toString().isNotEmpty) 
        ? p['image_url'] 
        : _getCategoryImage(category);

    // Mock stock data for design consistency
    final int stock = 40; 
    final bool isLowStock = stock <= 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              // 1. Fixed Image Section
              Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    image,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 110, height: 110, 
                      color: Colors.grey[100],
                      child: const Icon(Icons.fastfood, color: Colors.grey),
                    ),
                  ),
                ),
              ),

              // 2. Details Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        "NPR $price",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900, 
                          fontSize: 18, 
                          color: Color(0xFF2563EB), // Reference Blue
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Stock Badge (Top Right)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isLowStock ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                isLowStock ? "Low Stock : $stock" : "In Stock : $stock",
                style: TextStyle(
                  color: isLowStock ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // 4. Action Button (Bottom Right)
          Positioned(
            bottom: 16,
            right: 16,
            child: InkWell(
              onTap: () => _showActionMenu(p),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF2D3282), // Reference Dark Blue
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_basket_outlined, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryImage(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('pizza')) return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500';
    if (cat.contains('burger')) return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500';
    if (cat.contains('tea')) return 'https://images.unsplash.com/photo-1561336313-0bd5e0b27ec8?w=500';
    if (cat.contains('momo') || cat.contains('dumpling')) return 'https://images.unsplash.com/photo-1534422298391-e4f8c170db06?w=500';
    if (cat.contains('coffee')) return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=500';
    if (cat.contains('dessert') || cat.contains('cake')) return 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=500';
    if (cat.contains('sides') || cat.contains('fry')) return 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=500';
    
    return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500'; // Default Food
  }

  void _showActionMenu(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Colors.blue),
            title: const Text("Edit Details"),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text("Delete Product"),
            onTap: () {
              Navigator.pop(ctx);
              _deleteProduct(p['id'].toString());
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String id) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Product?"),
        content: const Text("This will permanently remove the product from your menu."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteProduct(tenant.id, id);
      if (success) {
        TenantService().fetchMenuData(tenant.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product deleted.")));
      }
    }
  }

  Widget _buildAddFoodForm() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: TenantService().categories,
      builder: (context, categories, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Product Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            _buildTextField("Product Name", _titleController, hint: "e.g. Steam Chicken Momo"),
            const SizedBox(height: 16),
            
            // Dynamic Category Dropdown
            const Text("Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategoryId,
                  hint: const Text("Select Category", style: TextStyle(fontSize: 13)),
                  isExpanded: true,
                  items: categories.map((c) => DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(c['title']),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildTextField("Base Price", _priceController, hint: "450")),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField("Image URL", _imageController, hint: "https://...")),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField("Description", _descriptionController, hint: "Enter short product details..."),
            const SizedBox(height: 32),
            
            if (_isSubmitting)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _submitProduct,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                child: const Text("ADD PRODUCT TO DATABASE"),
              ),
          ],
        );
      },
    );
  }

  Future<void> _submitProduct() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields!")));
      return;
    }

    setState(() => _isSubmitting = true);

    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final success = await ApiService.addProduct({
      'tenant_id': tenant.id,
      'category_id': _selectedCategoryId,
      'title': _titleController.text,
      'price': _priceController.text,
      'image_url': _imageController.text,
      'description': _descriptionController.text,
    });

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      _titleController.clear();
      _priceController.clear();
      _imageController.clear();
      _descriptionController.clear();
      // Re-fetch menu to show new item
      TenantService().fetchMenuData(tenant.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product added successfully!"), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to add product."), backgroundColor: Colors.red));
    }
  }

  Widget _buildFoodVariantView() {
    return const Center(child: Text("Variants view coming soon."));
  }

  Widget _buildAvailabilityView() {
    return const Center(child: Text("Quick stock toggle coming soon."));
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
