import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

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
  String _selectedSuitableTime = 'All Day'; // Morning, Lunch, Evening, Late Night, All Day
  String _selectedMealTag = 'Popular'; // ✨ AI Picks, ⚡ Fast Food, 🔥 Popular, 🌱 Healthy, 😋 Sweet Cravings
  String _selectedPrepTime = '15-20 min'; // 1-5 min, 5-10 min, 10-15 min, 15-25 min, 25-35 min
  Map<String, dynamic>? _editingProduct; // State for Edit mode
  
  // Product Sizes & Variants State
  bool _hasVariants = false;
  String _selectedVariantType = 'sizes'; // 'sizes', 'portions', 'volume', 'custom'
  String _variantTimeSlotFilter = 'All'; // 'All', 'Morning', 'Lunch', 'Evening', 'Late Night', 'All Day'
  String _variantCategoryFilter = 'All';
  String _variantSearchQuery = '';
  bool _isFoodListSearching = false;
  String _foodListSearchQuery = '';

  // Availability Management State
  String _availabilityStatusFilter = 'All'; // 'All', 'Available', 'Out of Stock'
  String _availabilityCategoryFilter = 'All';
  String _availabilitySearchQuery = '';
  final Map<String, int> _localAvailabilityOverrides = {};
  final _smallPriceCtrl = TextEditingController();
  final _mediumPriceCtrl = TextEditingController();
  final _largePriceCtrl = TextEditingController();
  final _halfPriceCtrl = TextEditingController();
  final _fullPriceCtrl = TextEditingController();
  final _glassPriceCtrl = TextEditingController();
  final _pitcherPriceCtrl = TextEditingController();
  final _bottlePriceCtrl = TextEditingController();
  final List<Map<String, TextEditingController>> _customVariants = [];

  bool _isSubmitting = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  
  Uint8List? _selectedGlbBytes;
  String? _selectedGlbName;
  Uint8List? _selectedUsdzBytes;
  String? _selectedUsdzName;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _descriptionController.dispose();
    _sloganController.dispose();
    _smallPriceCtrl.dispose();
    _mediumPriceCtrl.dispose();
    _largePriceCtrl.dispose();
    _halfPriceCtrl.dispose();
    _fullPriceCtrl.dispose();
    _glassPriceCtrl.dispose();
    _pitcherPriceCtrl.dispose();
    _bottlePriceCtrl.dispose();
    for (var row in _customVariants) {
      row['nameCtrl']?.dispose();
      row['priceCtrl']?.dispose();
    }
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
        final filteredProducts = products.where((p) {
          if (_foodListSearchQuery.isNotEmpty) {
            final q = _foodListSearchQuery.toLowerCase();
            final title = (p['title'] ?? '').toString().toLowerCase();
            final desc = (p['description'] ?? '').toString().toLowerCase();
            final tag = (p['tag'] ?? '').toString().toLowerCase();
            if (!title.contains(q) && !desc.contains(q) && !tag.contains(q)) return false;
          }
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.mode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => _isFoodListSearching = !_isFoodListSearching),
                  icon: Icon(_isFoodListSearching ? Icons.close : Icons.search, color: AdminTheme.royalBlue),
                ),
              ],
            ),
            if (_isFoodListSearching) ...[
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _foodListSearchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: "Search food items...",
                  prefixIcon: const Icon(Icons.search, color: AdminTheme.royalBlue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (filteredProducts.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No products match your search.")))
            else
              ...filteredProducts.map((p) => _buildFoodItemCard(p)),
          ],
        );
      },
    );
  }

  String _getFormattedImageUrl(String? rawUrl, String fallbackCategory) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return _getCategoryImage(fallbackCategory);
    }
    String trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      trimmed = trimmed.substring(1);
    }
    return '${ApiService.baseUrl}/$trimmed';
  }

  Widget _buildFoodItemCard(Map<String, dynamic> p) {
    final String title = p['title'] ?? 'Untitled Item';
    final String category = p['tag'] ?? 'Uncategorized';
    final String price = p['price']?.toString() ?? '0.00';
    final String description = p['description'] ?? 'Delicious freshly prepared item.';
    final String rawImg = (p['image_url'] != null && p['image_url'].toString().isNotEmpty) 
        ? p['image_url'].toString() 
        : (p['image'] != null && p['image'].toString().isNotEmpty ? p['image'].toString() : '');
    final String image = _getFormattedImageUrl(rawImg, category);

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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (p['suitable_time'] != null && p['suitable_time'].toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AdminTheme.royalBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p['suitable_time'].toString(),
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue),
                              ),
                            ),
                          if ((p['meal_tag'] ?? p['tag']) != null && (p['meal_tag'] ?? p['tag']).toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                (p['meal_tag'] ?? p['tag']).toString(),
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00)),
                              ),
                            ),
                        ],
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                IconButton(
                  onPressed: () {
                    final tenant = TenantService().currentTenant.value;
                    if (tenant != null) {
                      TenantService().fetchMenuData(tenant.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing with database...")));
                    }
                  }, 
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: AdminTheme.royalBlue),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!, width: 1.5)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategoryId,
                  hint: Text(
                    categories.isEmpty ? "No Categories Found" : "Select Category", 
                    style: TextStyle(fontSize: 13, color: categories.isEmpty ? Colors.red : Colors.grey[600])
                  ),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminTheme.royalBlue),
                  items: categories.map((c) => DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(
                      c['title'] ?? 'Unnamed', 
                      style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)
                    ),
                  )).toList(),
                  onChanged: (val) {
                    debugPrint("CATEGORY SELECTED: $val");
                    setState(() => _selectedCategoryId = val);
                  },
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
            const SizedBox(height: 20),

            // Product Sizes & Variants Section
            _buildVariantFormSection(),
            const SizedBox(height: 24),
            
            // 3D Model Section (Premium Feature Check)
            if (TenantService().currentTenant.value?.isPremiumEnabled ?? false) ...[
              const Text("3D Models (AR)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildModelPicker(
                      "Android (.glb)", 
                      _selectedGlbName, 
                      () => _pickModel('glb'),
                      Icons.android,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModelPicker(
                      "iOS (.usdz)", 
                      _selectedUsdzName, 
                      () => _pickModel('usdz'),
                      Icons.apple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            
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
            const SizedBox(height: 20),

            // Preparation Time Selector
            const Text("Preparation Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPrepTimeChip("1-5 min", "⚡ 1-5 min"),
                _buildPrepTimeChip("5-10 min", "⏱️ 5-10 min"),
                _buildPrepTimeChip("10-15 min", "🍳 10-15 min"),
                _buildPrepTimeChip("15-25 min", "🔥 15-25 min"),
                _buildPrepTimeChip("25-35 min", "⌛ 25-35 min"),
              ],
            ),
            const SizedBox(height: 20),

            // Suitable Time Slot Selector
            const Text("Suitable Time Slot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimeChip("All Day", "🌟 All Day"),
                _buildTimeChip("Morning", "☕ Morning"),
                _buildTimeChip("Lunch", "🍕 Lunch"),
                _buildTimeChip("Evening", "🍔 Evening"),
                _buildTimeChip("Late Night", "🌙 Late Night"),
              ],
            ),
            const SizedBox(height: 20),

            // Meal Filter Tag Selector
            const Text("Meal Filter Tag", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTagChip("✨ AI Picks"),
                _buildTagChip("⚡ Fast Food"),
                _buildTagChip("🔥 Popular"),
                _buildTagChip("🌱 Healthy"),
                _buildTagChip("😋 Sweet Cravings"),
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

  Future<void> _pickModel(String type) async {
    if (kIsWeb) {
      try {
        debugPrint("Opening Web native file picker for: $type");
        final web.HTMLInputElement input = web.document.createElement('input') as web.HTMLInputElement;
        input.type = 'file';
        input.accept = '.$type';
        
        input.onChange.listen((event) {
          if (input.files!.length > 0) {
            final file = input.files!.item(0)!;
            debugPrint("Web File selected: ${file.name}");
            
            final reader = web.FileReader();
            reader.readAsArrayBuffer(file);
            reader.onLoadEnd.listen((e) {
              final Uint8List bytes = (reader.result as JSArrayBuffer).toDart.asUint8List();
              setState(() {
                if (type == 'glb') {
                  _selectedGlbBytes = bytes;
                  _selectedGlbName = file.name;
                } else {
                  _selectedUsdzBytes = bytes;
                  _selectedUsdzName = file.name;
                }
              });
            });
          }
        });
        input.click();
      } catch (e) {
        debugPrint("Web Picker Error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Web Picker Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    // Fallback for Mobile/Desktop
    try {
      debugPrint("Opening file_picker for: $type");
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [type],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          if (type == 'glb') {
            _selectedGlbBytes = file.bytes;
            _selectedGlbName = file.name;
          } else {
            _selectedUsdzBytes = file.bytes;
            _selectedUsdzName = file.name;
          }
        });
      }
    } catch (e) {
      debugPrint("FilePicker Error: $e");
    }
  }

  void _clearVariantControllers() {
    _smallPriceCtrl.clear();
    _mediumPriceCtrl.clear();
    _largePriceCtrl.clear();
    _halfPriceCtrl.clear();
    _fullPriceCtrl.clear();
    _glassPriceCtrl.clear();
    _pitcherPriceCtrl.clear();
    _bottlePriceCtrl.clear();
    for (var row in _customVariants) {
      row['nameCtrl']?.dispose();
      row['priceCtrl']?.dispose();
    }
    _customVariants.clear();
  }

  List<Map<String, String>> _buildVariantsList() {
    if (!_hasVariants) return [];

    List<Map<String, String>> list = [];
    if (_selectedVariantType == 'sizes') {
      if (_smallPriceCtrl.text.trim().isNotEmpty) {
        list.add({'name': 'Small', 'price': _smallPriceCtrl.text.trim()});
      }
      if (_mediumPriceCtrl.text.trim().isNotEmpty) {
        list.add({'name': 'Medium', 'price': _mediumPriceCtrl.text.trim()});
      }
      if (_largePriceCtrl.text.trim().isNotEmpty) {
        list.add({'name': 'Large', 'price': _largePriceCtrl.text.trim()});
      }
    } else if (_selectedVariantType == 'portions') {
      if (_halfPriceCtrl.text.trim().isNotEmpty) {
        list.add({'name': 'Half', 'price': _halfPriceCtrl.text.trim()});
      }
      if (_fullPriceCtrl.text.trim().isNotEmpty) {
        list.add({'name': 'Full', 'price': _fullPriceCtrl.text.trim()});
      }
    } else if (_selectedVariantType == 'volume') {
      if (_glassPriceCtrl.text.trim().isNotEmpty) {
        list.add({'name': 'Glass', 'price': _glassPriceCtrl.text.trim()});
      }
      if (_pitcherPriceCtrl.text.trim().isNotEmpty) {
        list.add({'name': 'Pitcher', 'price': _pitcherPriceCtrl.text.trim()});
      }
      if (_bottlePriceCtrl.text.trim().isNotEmpty) {
        list.add({'name': 'Bottle', 'price': _bottlePriceCtrl.text.trim()});
      }
    } else if (_selectedVariantType == 'custom') {
      for (var row in _customVariants) {
        String n = row['nameCtrl']!.text.trim();
        String p = row['priceCtrl']!.text.trim();
        if (n.isNotEmpty && p.isNotEmpty) {
          list.add({'name': n, 'price': p});
        }
      }
    }
    return list;
  }

  Widget _buildVariantFormSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.tune_rounded, color: AdminTheme.royalBlue, size: 20),
                  SizedBox(width: 8),
                  Text("Product Sizes & Portion Options", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Switch(
                value: _hasVariants,
                activeColor: AdminTheme.royalBlue,
                onChanged: (val) {
                  setState(() => _hasVariants = val);
                },
              ),
            ],
          ),
          if (_hasVariants) ...[
            const SizedBox(height: 12),
            const Text("Select Size / Portion Type", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildVariantTypeChip('sizes', '🍕 Sizes (Small / Medium / Large)'),
                _buildVariantTypeChip('portions', '🥣 Portions (Half / Full)'),
                _buildVariantTypeChip('volume', '🥤 Volume (Glass / Pitcher / Bottle)'),
                _buildVariantTypeChip('custom', '⚙️ Custom Options'),
              ],
            ),
            const SizedBox(height: 16),
            const Text("Set Individual Prices (NPR)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            if (_selectedVariantType == 'sizes') ...[
              Row(
                children: [
                  Expanded(child: _buildTextField("Small Price", _smallPriceCtrl, hint: "e.g. 150")),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("Medium Price", _mediumPriceCtrl, hint: "e.g. 250")),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("Large Price", _largePriceCtrl, hint: "e.g. 350")),
                ],
              ),
            ] else if (_selectedVariantType == 'portions') ...[
              Row(
                children: [
                  Expanded(child: _buildTextField("Half Portion Price", _halfPriceCtrl, hint: "e.g. 120")),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("Full Portion Price", _fullPriceCtrl, hint: "e.g. 220")),
                ],
              ),
            ] else if (_selectedVariantType == 'volume') ...[
              Row(
                children: [
                  Expanded(child: _buildTextField("Glass Price", _glassPriceCtrl, hint: "e.g. 80")),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("Pitcher Price", _pitcherPriceCtrl, hint: "e.g. 350")),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("Bottle Price", _bottlePriceCtrl, hint: "e.g. 600")),
                ],
              ),
            ] else if (_selectedVariantType == 'custom') ...[
              ..._customVariants.asMap().entries.map((entry) {
                int idx = entry.key;
                var row = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: _buildTextField("Option Name", row['nameCtrl']!, hint: "e.g. 250ml")),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: _buildTextField("Price (NPR)", row['priceCtrl']!, hint: "e.g. 100")),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            row['nameCtrl']!.dispose();
                            row['priceCtrl']!.dispose();
                            _customVariants.removeAt(idx);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _customVariants.add({
                      'nameCtrl': TextEditingController(),
                      'priceCtrl': TextEditingController(),
                    });
                  });
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text("ADD CUSTOM OPTION"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.royalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildVariantTypeChip(String type, String label) {
    bool isSelected = _selectedVariantType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AdminTheme.royalBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      onSelected: (val) => setState(() => _selectedVariantType = type),
    );
  }

  Widget _buildModelPicker(String label, String? fileName, VoidCallback onTap, IconData icon) {
    final bool isSelected = fileName != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? Colors.green : Colors.grey[200]!, width: isSelected ? 2 : 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: isSelected ? Colors.green : AdminTheme.royalBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSelected ? fileName : "Click to Upload",
                    style: TextStyle(
                      fontSize: 11, 
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.green : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle, color: Colors.green, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitProduct() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields!")));
      return;
    }

    final tenant = TenantService().currentTenant.value;
    if (tenant == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Tenant data not loaded!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String finalImageUrl = "";
      String finalGlbUrl = "";
      String finalUsdzUrl = "";

      // 1. Upload assets
      if (_selectedImageBytes != null && _selectedImageName != null) {
        final uploadedUrl = await ApiService.uploadProductImage(_selectedImageBytes!, _selectedImageName!);
        if (uploadedUrl != null) finalImageUrl = uploadedUrl;
      }

      if (_selectedGlbBytes != null && _selectedGlbName != null) {
        final uploadedUrl = await ApiService.upload3DModel(_selectedGlbBytes!, _selectedGlbName!);
        if (uploadedUrl != null) finalGlbUrl = uploadedUrl;
      }

      if (_selectedUsdzBytes != null && _selectedUsdzName != null) {
        final uploadedUrl = await ApiService.upload3DModel(_selectedUsdzBytes!, _selectedUsdzName!);
        if (uploadedUrl != null) finalUsdzUrl = uploadedUrl;
      }

      // 2. Add product to DB
      final variantsList = _buildVariantsList();
      final String variantsJson = json.encode(variantsList);

      final res = await ApiService.addProduct({
        'tenant_id': tenant.id,
        'category_id': _selectedCategoryId,
        'title': _titleController.text.trim(),
        'price': _priceController.text.trim(),
        'image_url': finalImageUrl,
        'description': _descriptionController.text.trim(),
        'slogan': _sloganController.text.trim(),
        'featured_section': _selectedSection,
        'suitable_time': _selectedSuitableTime,
        'tag': _selectedMealTag,
        'meal_tag': _selectedMealTag,
        'prep_time': _selectedPrepTime,
        'model_url': finalGlbUrl,
        'ios_model_url': finalUsdzUrl,
        'has_variants': _hasVariants ? 1 : 0,
        'variant_type': _selectedVariantType,
        'variants': variantsJson,
      });

      if (res['success'] == true) {
        _titleController.clear();
        _priceController.clear();
        _descriptionController.clear();
        _sloganController.clear();
        setState(() {
          _selectedImageBytes = null;
          _selectedImageName = null;
          _selectedGlbBytes = null;
          _selectedGlbName = null;
          _selectedUsdzBytes = null;
          _selectedUsdzName = null;
        });
        TenantService().fetchMenuData(tenant.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product added successfully!"), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Failed to add product."), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildFoodVariantView() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: TenantService().products,
      builder: (context, products, child) {
        // Filter products based on search, category, and time slot filters
        final filteredProducts = products.where((p) {
          if (_variantSearchQuery.isNotEmpty) {
            final q = _variantSearchQuery.toLowerCase();
            final title = (p['title'] ?? '').toString().toLowerCase();
            final desc = (p['description'] ?? '').toString().toLowerCase();
            final slogan = (p['slogan'] ?? '').toString().toLowerCase();
            if (!title.contains(q) && !desc.contains(q) && !slogan.contains(q)) return false;
          }

          if (_variantCategoryFilter != 'All') {
            final catId = (p['category_id'] ?? '').toString();
            final catTitle = (p['tag'] ?? p['meal_tag'] ?? '').toString().toLowerCase();
            if (catId != _variantCategoryFilter && !catTitle.contains(_variantCategoryFilter.toLowerCase())) {
              return false;
            }
          }

          if (_variantTimeSlotFilter != 'All') {
            final slot = (p['suitable_time'] ?? 'All Day').toString().toLowerCase();
            if (!slot.contains(_variantTimeSlotFilter.toLowerCase()) && slot != 'all day') {
              return false;
            }
          }

          return true;
        }).toList();

        // Calculate Stats
        final int totalCount = products.length;
        final int variantCount = products.where((p) => p['has_variants'] == true || p['has_variants'] == 1 || p['has_variants'] == '1').length;
        final Set<String> timeSlots = products.map((p) => (p['suitable_time'] ?? 'All Day').toString()).toSet();

        // Group filtered products by suitable time slot
        final Map<String, List<Map<String, dynamic>>> groupedByTime = {};
        for (var p in filteredProducts) {
          final slot = (p['suitable_time'] ?? 'All Day').toString();
          if (!groupedByTime.containsKey(slot)) groupedByTime[slot] = [];
          groupedByTime[slot]!.add(p);
        }

        final categoriesList = TenantService().categories.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title & Refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Food Variant Explorer", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                    Text("Categorized view of menu options, meal slots & portion prices.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    final tenant = TenantService().currentTenant.value;
                    if (tenant != null) {
                      TenantService().fetchMenuData(tenant.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing variants with database...")));
                    }
                  },
                  icon: const Icon(Icons.sync_rounded, color: AdminTheme.royalBlue),
                  tooltip: "Sync Menu Data",
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stat Cards
            Row(
              children: [
                Expanded(child: _buildVariantStatCard("TOTAL ITEMS", "$totalCount Products", Icons.restaurant_menu_rounded, AdminTheme.royalBlue)),
                const SizedBox(width: 12),
                Expanded(child: _buildVariantStatCard("WITH VARIANTS", "$variantCount Items", Icons.tune_rounded, const Color(0xFFFF5C00))),
                const SizedBox(width: 12),
                Expanded(child: _buildVariantStatCard("TIME SLOTS", "${timeSlots.length} Slots", Icons.access_time_filled_rounded, const Color(0xFF16A34A))),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar & Category Dropdown
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _variantSearchQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: "Search food variants, items or slogans...",
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search_rounded, color: AdminTheme.royalBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _variantCategoryFilter,
                      icon: const Icon(Icons.filter_list_rounded, color: AdminTheme.royalBlue, size: 20),
                      items: [
                        const DropdownMenuItem(value: "All", child: Text("All Categories", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ...categoriesList.map((c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text(c['title'] ?? 'Category', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        )),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _variantCategoryFilter = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Time Slot Chips Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  {"id": "All", "label": "🌟 All Slots"},
                  {"id": "Morning", "label": "☕ Morning"},
                  {"id": "Lunch", "label": "🍕 Lunch"},
                  {"id": "Evening", "label": "🍔 Evening"},
                  {"id": "Late Night", "label": "🌙 Late Night"},
                  {"id": "All Day", "label": "🌟 All Day"},
                ].map((slot) {
                  bool isSel = _variantTimeSlotFilter == slot['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(slot['label']!),
                      selected: isSel,
                      selectedColor: AdminTheme.royalBlue,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      backgroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
                      onSelected: (_) => setState(() => _variantTimeSlotFilter = slot['id']!),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),

            // Grouped Product Sections
            if (filteredProducts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text("No food items match your filters.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    SizedBox(height: 4),
                    Text("Try clearing filters or adding new food products.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              )
            else
              ...groupedByTime.entries.map((entry) {
                final String timeSlotName = entry.key;
                final List<Map<String, dynamic>> slotItems = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Header
                    Container(
                      margin: const EdgeInsets.only(bottom: 16, top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_filled_rounded, size: 16, color: Color(0xFFFF5C00)),
                          const SizedBox(width: 8),
                          Text(
                            "$timeSlotName (${slotItems.length} Items)".toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFFF5C00), letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),

                    // Cards in this Time Slot
                    ...slotItems.map((p) => _buildVariantProductCard(p)),
                    const SizedBox(height: 20),
                  ],
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildVariantStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantProductCard(Map<String, dynamic> p) {
    final String title = p['title'] ?? 'Untitled Item';
    final String category = p['tag'] ?? 'Uncategorized';
    final String price = p['price']?.toString() ?? '0.00';
    final String timeSlot = p['suitable_time'] ?? 'All Day';
    final String slogan = p['slogan'] ?? '';
    final String rawImg = (p['image_url'] != null && p['image_url'].toString().isNotEmpty) 
        ? p['image_url'].toString() 
        : (p['image'] != null && p['image'].toString().isNotEmpty ? p['image'].toString() : '');
    final String image = _getFormattedImageUrl(rawImg, category);

    // Parse Variants
    List parsedVariants = [];
    if (p['variants'] != null) {
      if (p['variants'] is String && (p['variants'] as String).isNotEmpty) {
        try { parsedVariants = json.decode(p['variants']); } catch (_) {}
      } else if (p['variants'] is List) {
        parsedVariants = p['variants'];
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Photo Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  image,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    width: 70, height: 70,
                    color: Colors.grey[100],
                    child: const Icon(Icons.fastfood, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Product Header Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminTheme.darkNavy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (slogan.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(slogan, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AdminTheme.royalBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "⏱️ $timeSlot",
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Base Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("BASE PRICE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
                  Text("NPR $price", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                ],
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),

          // Variants Breakdown Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.tune_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text("SIZES & PORTION VARIANTS:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
              const SizedBox(width: 12),
              Expanded(
                child: parsedVariants.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Text("Standard Portion: NPR $price", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: parsedVariants.map((v) {
                          final String vName = v['name'] ?? 'Option';
                          final String vPrice = v['price']?.toString() ?? '0';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              "$vName: NPR $vPrice",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(width: 12),

              // Manage Variants Button
              ElevatedButton.icon(
                onPressed: () => _startEditing(p),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text("MANAGE VARIANTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.darkNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityView() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: TenantService().products,
      builder: (context, products, child) {
        // Filter products based on search, category, and availability status
        final filteredProducts = products.where((p) {
          final bool isAvail = p['is_available'] == true || p['is_available'] == 1 || p['is_available'] == '1' || p['is_available'] == null;

          if (_availabilitySearchQuery.isNotEmpty) {
            final q = _availabilitySearchQuery.toLowerCase();
            final title = (p['title'] ?? '').toString().toLowerCase();
            final desc = (p['description'] ?? '').toString().toLowerCase();
            if (!title.contains(q) && !desc.contains(q)) return false;
          }

          if (_availabilityCategoryFilter != 'All') {
            final catId = (p['category_id'] ?? '').toString();
            final catTitle = (p['tag'] ?? p['meal_tag'] ?? '').toString().toLowerCase();
            if (catId != _availabilityCategoryFilter && !catTitle.contains(_availabilityCategoryFilter.toLowerCase())) {
              return false;
            }
          }

          if (_availabilityStatusFilter == 'Available' && !isAvail) return false;
          if (_availabilityStatusFilter == 'Out of Stock' && isAvail) return false;

          return true;
        }).toList();

        // Calculate Stats
        final int totalCount = products.length;
        final int availCount = products.where((p) => p['is_available'] == true || p['is_available'] == 1 || p['is_available'] == '1' || p['is_available'] == null).length;
        final int outOfStockCount = totalCount - availCount;

        final categoriesList = TenantService().categories.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title & Refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Food Stock & Availability", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                    Text("Real-time ON/OFF stock toggle control for your menu items.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    final tenant = TenantService().currentTenant.value;
                    if (tenant != null) {
                      TenantService().fetchMenuData(tenant.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing stock status with database...")));
                    }
                  },
                  icon: const Icon(Icons.sync_rounded, color: AdminTheme.royalBlue),
                  tooltip: "Sync Stock Data",
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stat Cards
            Row(
              children: [
                Expanded(child: _buildAvailabilityStatCard("TOTAL MENU", "$totalCount Items", Icons.restaurant_menu_rounded, AdminTheme.royalBlue)),
                const SizedBox(width: 12),
                Expanded(child: _buildAvailabilityStatCard("IN STOCK (ON)", "$availCount Active", Icons.check_circle_rounded, const Color(0xFF16A34A))),
                const SizedBox(width: 12),
                Expanded(child: _buildAvailabilityStatCard("OUT OF STOCK", "$outOfStockCount Disabled", Icons.cancel_rounded, Colors.redAccent)),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar & Category Dropdown
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _availabilitySearchQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: "Search items to toggle availability...",
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search_rounded, color: AdminTheme.royalBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _availabilityCategoryFilter,
                      icon: const Icon(Icons.filter_list_rounded, color: AdminTheme.royalBlue, size: 20),
                      items: [
                        const DropdownMenuItem(value: "All", child: Text("All Categories", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ...categoriesList.map((c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text(c['title'] ?? 'Category', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        )),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _availabilityCategoryFilter = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  {"id": "All", "label": "🌟 All Items ($totalCount)"},
                  {"id": "Available", "label": "✅ Available / ON ($availCount)"},
                  {"id": "Out of Stock", "label": "❌ Out of Stock / OFF ($outOfStockCount)"},
                ].map((chip) {
                  bool isSel = _availabilityStatusFilter == chip['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(chip['label']!),
                      selected: isSel,
                      selectedColor: AdminTheme.royalBlue,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      backgroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
                      onSelected: (_) => setState(() => _availabilityStatusFilter = chip['id']!),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),

            // Product Cards List
            if (filteredProducts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.no_meals_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text("No products match availability filters.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    SizedBox(height: 4),
                    Text("Try adjusting your search or category filter.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              )
            else
              ...filteredProducts.map((p) => _buildAvailabilityCard(p)),
          ],
        );
      },
    );
  }

  Widget _buildAvailabilityStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(Map<String, dynamic> p) {
    final String pId = p['id']?.toString() ?? '';
    final String title = p['title'] ?? 'Untitled Item';
    final String category = p['tag'] ?? 'Uncategorized';
    final String price = p['price']?.toString() ?? '0.00';
    
    // Check local override first, then fallback to product model
    final int? overrideVal = _localAvailabilityOverrides[pId];
    final bool isAvailable = overrideVal != null 
        ? (overrideVal == 1) 
        : (p['is_available'] == true || p['is_available'] == 1 || p['is_available'] == '1' || p['is_available'] == null || p['is_available'] == 'true');

    final String rawImg = (p['image_url'] != null && p['image_url'].toString().isNotEmpty) 
        ? p['image_url'].toString() 
        : (p['image'] != null && p['image'].toString().isNotEmpty ? p['image'].toString() : '');
    final String image = _getFormattedImageUrl(rawImg, category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
        border: Border.all(
          color: isAvailable ? const Color(0xFF16A34A).withValues(alpha: 0.3) : Colors.redAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Photo Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              image,
              width: 65,
              height: 65,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                width: 65, height: 65,
                color: Colors.grey[100],
                child: const Icon(Icons.fastfood, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Title & Category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminTheme.darkNavy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdminTheme.royalBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("NPR $price", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF2563EB))),
                  ],
                ),
              ],
            ),
          ),

          // Status Badge & ON/OFF Switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isAvailable ? const Color(0xFF16A34A).withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 14,
                      color: isAvailable ? const Color(0xFF16A34A) : Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAvailable ? "IN STOCK" : "OUT OF STOCK",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isAvailable ? const Color(0xFF16A34A) : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // ON/OFF Switch
              Switch(
                value: isAvailable,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF16A34A),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey.shade300,
                onChanged: (newStatus) async {
                  final tenant = TenantService().currentTenant.value;
                  final tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';

                  final int statusInt = newStatus ? 1 : 0;

                  // 1. Lock in local override map & item map
                  setState(() {
                    _localAvailabilityOverrides[pId] = statusInt;
                    p['is_available'] = statusInt;
                  });

                  // 2. Update product in TenantService products list directly
                  final currentProducts = TenantService().products.value;
                  final index = currentProducts.indexWhere((item) => item['id']?.toString() == pId);
                  if (index != -1) {
                    currentProducts[index]['is_available'] = statusInt;
                    TenantService().products.value = List.from(currentProducts);
                  }

                  // 3. Send API call to backend server
                  final success = await ApiService.toggleAvailability(tenantId, pId, statusInt);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          newStatus 
                              ? "'$title' marked IN STOCK (ON)" 
                              : "'$title' marked OUT OF STOCK (OFF)",
                        ),
                        backgroundColor: newStatus ? const Color(0xFF16A34A) : Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildTimeChip(String value, String label) {
    bool isSelected = _selectedSuitableTime == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AdminTheme.royalBlue,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 11),
      onSelected: (val) => setState(() => _selectedSuitableTime = value),
    );
  }

  Widget _buildPrepTimeChip(String value, String label) {
    bool isSelected = _selectedPrepTime == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AdminTheme.royalBlue,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 11),
      onSelected: (val) => setState(() => _selectedPrepTime = value),
    );
  }

  Widget _buildTagChip(String label) {
    bool isSelected = _selectedMealTag == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFFF5C00),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 11),
      onSelected: (val) => setState(() => _selectedMealTag = label),
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
      _selectedSuitableTime = p['suitable_time'] ?? 'All Day';
      _selectedMealTag = p['meal_tag'] ?? p['tag'] ?? '🔥 Popular';
      _selectedPrepTime = p['prep_time']?.toString() ?? '15-20 min';
      _selectedImageBytes = null; // Don't show preview for existing image unless picked new

      _hasVariants = p['has_variants'] == true || p['has_variants'] == 1 || p['has_variants'] == '1';
      _selectedVariantType = p['variant_type']?.toString() ?? 'sizes';
      _clearVariantControllers();

      if (p['variants'] != null) {
        List parsed = [];
        if (p['variants'] is String && (p['variants'] as String).isNotEmpty) {
          try { parsed = json.decode(p['variants']); } catch (_) {}
        } else if (p['variants'] is List) {
          parsed = p['variants'];
        }

        if (parsed.isNotEmpty) {
          _hasVariants = true;
          for (var v in parsed) {
            String vName = (v['name'] ?? '').toString().trim();
            String vPrice = (v['price'] ?? '').toString().trim();
            if (vName == 'Small') _smallPriceCtrl.text = vPrice;
            if (vName == 'Medium') _mediumPriceCtrl.text = vPrice;
            if (vName == 'Large') _largePriceCtrl.text = vPrice;
            if (vName == 'Half') _halfPriceCtrl.text = vPrice;
            if (vName == 'Full') _fullPriceCtrl.text = vPrice;
            if (vName == 'Glass') _glassPriceCtrl.text = vPrice;
            if (vName == 'Pitcher') _pitcherPriceCtrl.text = vPrice;
            if (vName == 'Bottle') _bottlePriceCtrl.text = vPrice;
          }
        }
      }
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
    
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || _editingProduct == null) return;

    setState(() => _isSubmitting = true);
    try {
      String finalImageUrl = _editingProduct!['image_url'] ?? _editingProduct!['image'] ?? "";
      String finalGlbUrl = _editingProduct!['model_url'] ?? "";
      String finalUsdzUrl = _editingProduct!['ios_model_url'] ?? "";

      if (_selectedImageBytes != null && _selectedImageName != null) {
        final uploadedUrl = await ApiService.uploadProductImage(_selectedImageBytes!, _selectedImageName!);
        if (uploadedUrl != null) finalImageUrl = uploadedUrl;
      }

      if (_selectedGlbBytes != null && _selectedGlbName != null) {
        final uploadedUrl = await ApiService.upload3DModel(_selectedGlbBytes!, _selectedGlbName!);
        if (uploadedUrl != null) finalGlbUrl = uploadedUrl;
      }

      if (_selectedUsdzBytes != null && _selectedUsdzName != null) {
        final uploadedUrl = await ApiService.upload3DModel(_selectedUsdzBytes!, _selectedUsdzName!);
        if (uploadedUrl != null) finalUsdzUrl = uploadedUrl;
      }

      final variantsList = _buildVariantsList();
      final String variantsJson = json.encode(variantsList);

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
        'suitable_time': _selectedSuitableTime,
        'tag': _selectedMealTag,
        'meal_tag': _selectedMealTag,
        'prep_time': _selectedPrepTime,
        'model_url': finalGlbUrl,
        'ios_model_url': finalUsdzUrl,
        'has_variants': _hasVariants ? 1 : 0,
        'variant_type': _selectedVariantType,
        'variants': variantsJson,
      });

      if (res['success'] == true) {
        setState(() => _editingProduct = null);
        TenantService().fetchMenuData(tenant.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product updated!"), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Failed to update product."), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
