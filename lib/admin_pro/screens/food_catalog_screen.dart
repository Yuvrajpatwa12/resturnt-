import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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
  final _descriptionController = TextEditingController(); // Restored
  final _sloganController = TextEditingController(); // Added
  
  String? _selectedCategoryId;
  String _selectedSection = 'none'; // Added for Just For You, Trending, etc.
  Map<String, dynamic>? _editingProduct; // State for Edit mode
  
  bool _isSubmitting = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _descriptionController.dispose();
    _sloganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_editingProduct != null) 
            _buildEditFoodForm()
          else if (widget.mode == "Add Food") 
            _buildAddFoodForm()
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
            onTap: () {
              Navigator.pop(ctx);
              _startEditing(p);
            },
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
            if (_editingProduct == null) ...[
              const Text("Product Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
            ],
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Product Image", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickImage,
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_selectedImageBytes != null ? Icons.check_circle : Icons.upload_file, 
                                   color: _selectedImageBytes != null ? Colors.green : AdminTheme.royalBlue, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _selectedImageBytes != null ? "Image Selected" : "Upload Photo",
                                style: TextStyle(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.bold, 
                                  color: _selectedImageBytes != null ? Colors.green : Colors.black87
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_selectedImageBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_selectedImageBytes!, height: 100, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 16),
            _buildTextField("Product Slogan", _sloganController, hint: "e.g. The best momo in town!"),
            const SizedBox(height: 16),
            _buildTextField("Description", _descriptionController, hint: "Enter short product details..."),
            const SizedBox(height: 16),
            
            // Home Section Picker
            const Text("Home Page Section", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                _buildSectionChip("none", "None"),
                _buildSectionChip("just_for_you", "Just For You"),
                _buildSectionChip("trending", "Trending"),
                _buildSectionChip("popular", "Popular"),
              ],
            ),
            const SizedBox(height: 32),
            
            if (_isSubmitting)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _editingProduct != null ? _submitEdit : _submitProduct,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                child: Text(_editingProduct != null ? "UPDATE PRODUCT DETAILS" : "ADD PRODUCT TO DATABASE"),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = pickedFile.name;
      });
    }
  }

  Future<void> _submitProduct() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields!")));
      return;
    }

    setState(() => _isSubmitting = true);

    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    String finalImageUrl = "";

    // 1. Upload image if selected
    if (_selectedImageBytes != null && _selectedImageName != null) {
      final uploadedUrl = await ApiService.uploadProductImage(_selectedImageBytes!, _selectedImageName!);
      if (uploadedUrl != null) {
        finalImageUrl = uploadedUrl;
      } else {
        setState(() => _isSubmitting = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Image upload failed!"), backgroundColor: Colors.red));
        return;
      }
    }

    // 2. Add product to DB
    final res = await ApiService.addProduct({
      'tenant_id': tenant.id,
      'category_id': _selectedCategoryId,
      'title': _titleController.text.trim(), // Added title here
      'price': _priceController.text.trim(),
      'image_url': finalImageUrl,
      'description': _descriptionController.text.trim(),
      'slogan': _sloganController.text.trim(),
      'featured_section': _selectedSection,
    });

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (res['success'] == true) {
      _titleController.clear();
      _priceController.clear();
      _imageController.clear();
      _descriptionController.clear();
      _sloganController.clear();
      setState(() {
        _selectedImageBytes = null;
        _selectedImageName = null;
        _selectedSection = 'none'; // Reset section
      });
      // Re-fetch menu to show new item
      TenantService().fetchMenuData(tenant.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product added successfully!"), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${res['message']}"), backgroundColor: Colors.red)
      );
    }
  }

  Widget _buildFoodVariantView() {
    return const Center(child: Text("Variants view coming soon."));
  }

  Widget _buildAvailabilityView() {
    return const Center(child: Text("Quick stock toggle coming soon.")    );
  }

  Widget _buildSectionChip(String value, String label) {
    bool isSelected = _selectedSection == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedSection = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AdminTheme.royalBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AdminTheme.royalBlue : Colors.grey[200]!),
          boxShadow: isSelected ? [BoxShadow(color: AdminTheme.royalBlue.withValues(alpha: 0.2), blurRadius: 8)] : [],
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _startEditing(Map<String, dynamic> p) {
    setState(() {
      _editingProduct = p;
      _titleController.text = p['title'] ?? '';
      _priceController.text = p['price']?.toString() ?? '';
      _descriptionController.text = p['description'] ?? '';
      _sloganController.text = p['slogan'] ?? '';
      _selectedCategoryId = p['category_id']?.toString();
      _selectedSection = p['featured_section'] ?? 'none';
      _selectedImageBytes = null; // Don't show preview for existing image unless picked new
    });
  }

  Widget _buildEditFoodForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(onPressed: () => setState(() => _editingProduct = null), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16)),
            const Text("Edit Product", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 24),
        _buildAddFoodForm(), // Reuse the form UI
      ],
    );
  }

  Future<void> _submitEdit() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty || _selectedCategoryId == null) return;
    setState(() => _isSubmitting = true);
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || _editingProduct == null) return;

    String finalImageUrl = _editingProduct!['image_url'] ?? _editingProduct!['image'] ?? "";

    if (_selectedImageBytes != null && _selectedImageName != null) {
      final uploadedUrl = await ApiService.uploadProductImage(_selectedImageBytes!, _selectedImageName!);
      if (uploadedUrl != null) finalImageUrl = uploadedUrl;
    }

    final res = await ApiService.updateProduct({
      'id': _editingProduct!['id'],
      'tenant_id': tenant.id,
      'category_id': _selectedCategoryId,
      'title': _titleController.text,
      'price': _priceController.text,
      'image_url': finalImageUrl,
      'description': _descriptionController.text,
      'slogan': _sloganController.text.trim(),
      'featured_section': _selectedSection,
    });

    setState(() => _isSubmitting = false);
    if (res['success'] == true) {
      setState(() => _editingProduct = null);
      TenantService().fetchMenuData(tenant.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product updated!"), backgroundColor: Colors.green));
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
