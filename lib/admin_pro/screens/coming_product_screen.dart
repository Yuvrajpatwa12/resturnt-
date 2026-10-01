import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../admin_theme.dart';
import '../../services/tenant_service.dart';
import '../../services/api_service.dart';

class ComingProductScreen extends StatefulWidget {
  const ComingProductScreen({super.key});

  @override
  State<ComingProductScreen> createState() => _ComingProductScreenState();
}

class _ComingProductScreenState extends State<ComingProductScreen> {
  final TextEditingController _comingSearchCtrl = TextEditingController();

  static const Color accentBlue = Color(0xFF2563EB);
  static const Color lightBlueBg = Color(0xFFEFF6FF);
  static const Color lightGreenBg = Color(0xFFF0FDF4);
  static const Color greenText = Color(0xFF16A34A);

  @override
  void dispose() {
    _comingSearchCtrl.dispose();
    super.dispose();
  }

  // Helper to format Image URLs (Handles relative paths & empty fallbacks)
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

  String _getCategoryImage(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('pizza')) return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500';
    if (cat.contains('burger')) return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500';
    if (cat.contains('tea') || cat.contains('lassi') || cat.contains('drink')) return 'https://images.unsplash.com/photo-1561336313-0bd5e0b27ec8?w=500';
    if (cat.contains('momo') || cat.contains('dumpling')) return 'https://images.unsplash.com/photo-1534422298391-e4f8c170db06?w=500';
    if (cat.contains('coffee')) return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=500';
    if (cat.contains('dessert') || cat.contains('icecream') || cat.contains('cake')) return 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=500';
    if (cat.contains('roll') || cat.contains('chicken') || cat.contains('soup') || cat.contains('thupa')) return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500';
    return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: TenantService().products,
        builder: (context, products, child) {
          final categoriesList = TenantService().categories.value;

          final comingProducts = products.where((p) {
            final val = p['is_coming_soon'];
            final isComing = val == true || val == 1 || val == '1' || val == 'true';
            if (!isComing) return false;

            final query = _comingSearchCtrl.text.trim().toLowerCase();
            if (query.isNotEmpty) {
              final title = (p['title'] ?? '').toString().toLowerCase();
              final desc = (p['description'] ?? '').toString().toLowerCase();
              return title.contains(query) || desc.contains(query);
            }
            return true;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Header Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AdminTheme.softShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightBlueBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.upcoming_rounded, color: accentBlue, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Coming Products",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: lightBlueBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${comingProducts.length} ${comingProducts.length == 1 ? 'Item' : 'Items'}",
                                  style: const TextStyle(
                                    color: accentBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Showcase upcoming menu items and teaser dishes on the customer app",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddComingProductDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text("Add Coming Product"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Search Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AdminTheme.softShadow,
                      ),
                      child: TextField(
                        controller: _comingSearchCtrl,
                        onChanged: (v) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: "Search coming products...",
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500], size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AdminTheme.softShadow,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: accentBlue),
                      onPressed: () {
                        final tenant = TenantService().currentTenant.value;
                        if (tenant != null) {
                          TenantService().fetchMenuData(tenant.id);
                        }
                      },
                      tooltip: "Refresh List",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Product List / Empty State
              if (comingProducts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AdminTheme.softShadow,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: lightBlueBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.upcoming_outlined, size: 48, color: accentBlue),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "No Coming Products Uploaded",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Add new upcoming teasers to build excitement among your customers.",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _showAddComingProductDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add Coming Product"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: comingProducts.length,
                  itemBuilder: (context, index) {
                    final p = comingProducts[index];
                    final catId = p['category_id']?.toString() ?? '';
                    final categoryObj = categoriesList.firstWhere(
                      (c) => c['id']?.toString() == catId,
                      orElse: () => {'title': 'Category $catId'},
                    );
                    final categoryName = categoryObj['title'] ?? 'General';
                    final title = p['title'] ?? '';
                    final price = p['price']?.toString() ?? '0.00';
                    final desc = p['description']?.toString() ?? '';
                    final rawImg = p['image_url'] ?? p['image'] ?? '';
                    final imageUrl = _getFormattedImageUrl(rawImg, categoryName);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AdminTheme.softShadow,
                      ),
                      child: Row(
                        children: [
                          // Image Container (90x90 rounded)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 90,
                              height: 90,
                              color: Colors.grey[100],
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Center(
                                  child: Icon(Icons.fastfood_rounded, color: Colors.grey[400], size: 36),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),

                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  desc.isNotEmpty ? desc : "Upcoming teaser product",
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),

                                // Category Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    categoryName,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Price in Vibrant Blue
                                Text(
                                  "NPR $price",
                                  style: const TextStyle(
                                    color: accentBlue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Actions & Badge
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: lightGreenBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  "COMING SOON",
                                  style: TextStyle(
                                    color: greenText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Edit Button
                                  Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: lightBlueBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: InkWell(
                                      onTap: () => _showEditComingProductDialog(context, p),
                                      borderRadius: BorderRadius.circular(10),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.edit_outlined, color: accentBlue, size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            "Edit",
                                            style: TextStyle(
                                              color: accentBlue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Delete Button
                                  Container(
                                    height: 36,
                                    width: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 18),
                                      onPressed: () => _deleteComingProduct(context, p['id']?.toString() ?? ''),
                                      tooltip: "Delete Product",
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  void _showAddComingProductDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool isSubmitting = false;

    final categories = TenantService().categories.value;
    String? selectedCategoryId = categories.isNotEmpty ? categories.first['id'].toString() : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: lightBlueBg,
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                            child: const Icon(Icons.add_circle_outline, color: accentBlue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Add Coming Product",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Form Fields
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: "Product Title *",
                      hintText: "e.g. Special Mango Lassi",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Price (NPR) *",
                            hintText: "e.g. 150",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: "Category *",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: categories.map((c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text(c['title'] ?? 'Category', overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "Description *",
                      hintText: "Brief teaser description for customers...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Upload Container
                  const Text("Product Image *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        final bytes = await pickedFile.readAsBytes();
                        setDialogState(() {
                          selectedImageBytes = bytes;
                          selectedImageName = pickedFile.name;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: selectedImageBytes != null ? lightGreenBg : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedImageBytes != null ? greenText : Colors.grey.shade300,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedImageBytes != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                            color: selectedImageBytes != null ? greenText : accentBlue,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedImageBytes != null ? (selectedImageName ?? "Image Selected") : "Click to select image",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: selectedImageBytes != null ? greenText : Colors.black87,
                                  ),
                                ),
                                Text(
                                  selectedImageBytes != null ? "Tap to change image" : "JPG, PNG or WEBP from computer",
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          if (selectedImageBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(selectedImageBytes!, width: 44, height: 44, fit: BoxFit.cover),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting ? null : () async {
                          if (titleCtrl.text.trim().isEmpty ||
                              priceCtrl.text.trim().isEmpty ||
                              descCtrl.text.trim().isEmpty ||
                              selectedCategoryId == null ||
                              selectedImageBytes == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("All fields and product image are compulsory!"), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          final tenant = TenantService().currentTenant.value;
                          final tenantId = tenant != null ? tenant.id : 'startups_main';

                          String imageUrl = "";
                          final uploadedUrl = await ApiService.uploadProductImage(selectedImageBytes!, selectedImageName!);
                          if (uploadedUrl != null) imageUrl = uploadedUrl;

                          final res = await ApiService.addProduct({
                            "tenant_id": tenantId,
                            "category_id": int.tryParse(selectedCategoryId ?? '0') ?? 0,
                            "title": titleCtrl.text.trim(),
                            "price": priceCtrl.text.trim(),
                            "description": descCtrl.text.trim(),
                            "image_url": imageUrl,
                            "tag": "Coming Soon",
                            "is_coming_soon": 1,
                          });

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (res['success'] == true) {
                            if (tenant != null) {
                              TenantService().fetchMenuData(tenant.id);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Coming product added successfully!"), backgroundColor: accentBlue),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: ${res['message']}"), backgroundColor: Colors.red),
                            );
                          }
                        },
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Upload Coming Product"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditComingProductDialog(BuildContext context, Map<String, dynamic> product) {
    final titleCtrl = TextEditingController(text: product['title']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: product['price']?.toString() ?? '');
    final descCtrl = TextEditingController(text: product['description']?.toString() ?? '');
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    String existingImageUrl = product['image_url'] ?? product['image'] ?? '';
    bool isSubmitting = false;

    final categories = TenantService().categories.value;
    String? selectedCategoryId = product['category_id']?.toString() ?? (categories.isNotEmpty ? categories.first['id'].toString() : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: lightBlueBg,
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                            child: const Icon(Icons.edit, color: accentBlue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Edit Coming Product",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Form Fields
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: "Product Title *",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Price (NPR) *",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: "Category *",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: categories.map((c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text(c['title'] ?? 'Category', overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "Description *",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Container
                  const Text("Change Image (Optional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        final bytes = await pickedFile.readAsBytes();
                        setDialogState(() {
                          selectedImageBytes = bytes;
                          selectedImageName = pickedFile.name;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_upload_outlined, color: accentBlue, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedImageBytes != null ? (selectedImageName ?? "New Image Selected") : "Update Product Image",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  selectedImageBytes != null ? "Tap to change image" : "Leave unchanged to keep current image",
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          if (selectedImageBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(selectedImageBytes!, width: 44, height: 44, fit: BoxFit.cover),
                            )
                          else if (existingImageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(_getFormattedImageUrl(existingImageUrl, 'Food'), width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox()),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting ? null : () async {
                          if (titleCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty || selectedCategoryId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("All text fields are compulsory!"), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          final tenant = TenantService().currentTenant.value;
                          final tenantId = tenant != null ? tenant.id : 'startups_main';

                          String imageUrl = existingImageUrl;
                          if (selectedImageBytes != null && selectedImageName != null) {
                            final uploadedUrl = await ApiService.uploadProductImage(selectedImageBytes!, selectedImageName!);
                            if (uploadedUrl != null) imageUrl = uploadedUrl;
                          }

                          final res = await ApiService.updateProduct({
                            "id": product['id'],
                            "tenant_id": tenantId,
                            "category_id": int.tryParse(selectedCategoryId ?? '0') ?? 0,
                            "title": titleCtrl.text.trim(),
                            "price": priceCtrl.text.trim(),
                            "description": descCtrl.text.trim(),
                            "image_url": imageUrl,
                            "tag": "Coming Soon",
                            "is_coming_soon": 1,
                          });

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (res['success'] == true) {
                            if (tenant != null) {
                              TenantService().fetchMenuData(tenant.id);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Coming product updated successfully!"), backgroundColor: Colors.green),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: ${res['message']}"), backgroundColor: Colors.red),
                            );
                          }
                        },
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Save Changes"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteComingProduct(BuildContext context, String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Coming Product"),
        content: const Text("Are you sure you want to delete this coming product? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true && productId.isNotEmpty) {
      final tenant = TenantService().currentTenant.value;
      final tenantId = tenant != null ? tenant.id : 'startups_main';

      final success = await ApiService.deleteProduct(tenantId, productId);
      if (success) {
        if (tenant != null) {
          TenantService().fetchMenuData(tenant.id);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Coming product deleted successfully!"), backgroundColor: Colors.green),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete coming product"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
