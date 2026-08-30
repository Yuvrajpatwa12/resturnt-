import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class HRMManagementScreen extends StatefulWidget {
  final String mode;
  const HRMManagementScreen({super.key, required this.mode});

  @override
  State<HRMManagementScreen> createState() => _HRMManagementScreenState();
}

class _HRMManagementScreenState extends State<HRMManagementScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  
  // New HRM Fields
  final _phoneController = TextEditingController();
  final _salaryController = TextEditingController(text: "0.00");
  final _cycleController = TextEditingController(text: "30");
  final _currentAddrController = TextEditingController();
  final _permanentAddrController = TextEditingController();
  final _citizenshipController = TextEditingController();
  final _documentController = TextEditingController();

  String _selectedRole = 'Waiter';
  bool _isSubmitting = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];
  String _searchQuery = "";
  
  // Detail/Edit View State
  Map<String, dynamic>? _selectedStaff;
  bool _isEditing = false;
  bool _isPinVisible = false; // Added PIN visibility state

  // Profile Image State
  XFile? _imageFile;
  Uint8List? _imageBytes;
  String? _currentProfileUrl;

  final List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    _loadStaff(); // Always load on init to ensure data is ready
  }

  @override
  void didUpdateWidget(covariant HRMManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if switching to a mode that needs current data
    if (widget.mode != oldWidget.mode) {
      _loadStaff();
    }
  }

  Future<void> _loadStaff() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    
    setState(() => _isLoading = true);
    
    // Clear old data first to avoid confusion
    setState(() => _staffList = []);
    
    final data = await ApiService.fetchStaff(tenant.id);
    
    if (mounted) {
      if (data != null) {
        setState(() {
          _staffList = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitStaff() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are required!")));
      return;
    }

    setState(() => _isSubmitting = true);

    String? uploadedUrl = _currentProfileUrl;
    if (_imageBytes != null && _imageFile != null) {
      uploadedUrl = await ApiService.uploadProfilePicture(_imageBytes!, _imageFile!.name);
    }
    
    bool success;
    if (_isEditing && _selectedStaff != null) {
      // UPDATE EXISTING
      success = await ApiService.updateStaff({
        'user_id': _selectedStaff!['id'],
        'name': _nameController.text.trim(),
        'role': _selectedRole,
        'pin': _pinController.text.trim(),
        'salary_amount': _salaryController.text.trim(),
        'payment_cycle_days': _cycleController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'current_address': _currentAddrController.text.trim(),
        'permanent_address': _permanentAddrController.text.trim(),
        'citizenship_number': _citizenshipController.text.trim(),
        'document_url': _documentController.text.trim(),
        'profile_pic_url': uploadedUrl,
      });
    } else {
      // ADD NEW
      final tenant = TenantService().currentTenant.value;
      success = await ApiService.addStaff({
        'tenant_id': tenant?.id,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'pin': _pinController.text.trim(),
        'salary_amount': _salaryController.text.trim(),
        'payment_cycle_days': _cycleController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'current_address': _currentAddrController.text.trim(),
        'permanent_address': _permanentAddrController.text.trim(),
        'citizenship_number': _citizenshipController.text.trim(),
        'document_url': _documentController.text.trim(),
        'profile_pic_url': uploadedUrl,
      });
    }

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      _clearForm();
      if (_isEditing) {
        setState(() {
          _isEditing = false;
          _selectedStaff = null;
        });
      }
      _loadStaff(); // Reload for both Add and Edit
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? "Updated successfully!" : "Staff member registered!"), backgroundColor: Colors.green));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action failed. Check database or unique email."), backgroundColor: Colors.red));
    }
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _pinController.clear();
    _phoneController.clear();
    _salaryController.text = "0.00";
    _cycleController.text = "30";
    _currentAddrController.clear();
    _permanentAddrController.clear();
    _citizenshipController.clear();
    _documentController.clear();
    _selectedRole = 'Waiter';
    setState(() {
      _imageFile = null;
      _imageBytes = null;
      _currentProfileUrl = null;
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _deleteStaff(dynamic userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Remove Staff?"),
        content: Text("Are you sure you want to remove $name?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("REMOVE", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteStaff(int.parse(userId.toString()));
      if (success && mounted) {
        _loadStaff();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Staff removed.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If a staff is selected, show details or edit form
    if (_selectedStaff != null) {
      return _isEditing ? _buildEditForm() : _buildStaffDetails();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mode == "Add Employee") _buildAddEmployeeForm()
          else if (widget.mode == "Manage Employee") _buildManageEmployeeView()
          else if (widget.mode == "Attendance Form") _buildAttendanceForm()
          else if (widget.mode.contains("Salary")) _buildPayrollView()
          else _buildGenericEmployeeView(),
        ],
      ),
    );
  }

  Widget _buildStaffDetails() {
    final s = _selectedStaff!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => setState(() => _selectedStaff = null), icon: const Icon(Icons.arrow_back)),
              const SizedBox(width: 16),
              const Text("Employee Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: AdminTheme.softShadow),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AdminTheme.royalBlue.withValues(alpha: 0.1),
                  child: Text(s['name'][0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue)),
                ),
                const SizedBox(height: 24),
                Text(s['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(s['role'].toString().toUpperCase(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 24),
                _buildDetailRow(Icons.email_outlined, "Login Email", s['email']),
                _buildDetailRow(
                  Icons.lock_outline, 
                  "Security PIN", 
                  _isPinVisible ? (s['login_pin']?.toString() ?? 'N/A') : "****",
                  trailing: IconButton(
                    icon: Icon(_isPinVisible ? Icons.visibility_off : Icons.visibility, size: 18, color: AdminTheme.royalBlue),
                    onPressed: () => setState(() => _isPinVisible = !_isPinVisible),
                  ),
                ),
                _buildDetailRow(Icons.phone_android_outlined, "Phone Number", s['phone_number'] ?? "N/A"),
                const Divider(),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(child: _buildDetailRow(Icons.payments_outlined, "Monthly Salary", "NPR ${s['salary_amount'] ?? '0.00'}")),
                    Expanded(child: _buildDetailRow(Icons.calendar_month_outlined, "Payment Cycle", "${s['payment_cycle_days'] ?? '30'} Days")),
                  ],
                ),
                _buildDetailRow(Icons.badge_outlined, "Citizenship No.", s['citizenship_number'] ?? "N/A"),
                _buildDetailRow(Icons.location_on_outlined, "Current Address", s['current_address'] ?? "N/A"),
                _buildDetailRow(Icons.home_outlined, "Permanent Address", s['permanent_address'] ?? "N/A"),
                _buildDetailRow(Icons.description_outlined, "Document URL / Ref", s['document_url'] ?? "No documents linked"),
                
                _buildDetailRow(Icons.info_outline, "Account Status", s['status'] ?? "Active"),
                const SizedBox(height: 48),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _nameController.text = s['name'] ?? '';
                            _emailController.text = s['email'] ?? '';
                            _pinController.text = s['login_pin']?.toString() ?? '';
                            _phoneController.text = s['phone_number'] ?? '';
                            _salaryController.text = s['salary_amount']?.toString() ?? '0.00';
                            _cycleController.text = s['payment_cycle_days']?.toString() ?? '30';
                            _currentAddrController.text = s['current_address'] ?? '';
                            _permanentAddrController.text = s['permanent_address'] ?? '';
                            _citizenshipController.text = s['citizenship_number'] ?? '';
                            _documentController.text = s['document_url'] ?? '';
                            _selectedRole = s['role'];
                            _currentProfileUrl = s['profile_pic_url'];
                            _isEditing = true;
                          });
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text("EDIT PROFILE"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _deleteStaff(s['id'], s['name']),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text("REMOVE STAFF"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String val, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => setState(() => _isEditing = false), icon: const Icon(Icons.close)),
              const SizedBox(width: 16),
              const Text("Edit Team Member", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 32),
          _buildAddEmployeeForm(), // Reusing the form widget
        ],
      ),
    );
  }

  Widget _buildAddEmployeeForm() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEditing ? "Update Profile Details" : "Add New Team Member", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(_isEditing ? "Changes will take effect instantly." : "Create a detailed digital file for your employee.", style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 32),
          
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AdminTheme.royalBlue.withValues(alpha: 0.1),
                  backgroundImage: _imageBytes != null 
                    ? MemoryImage(_imageBytes!) 
                    : (_currentProfileUrl != null ? NetworkImage(_currentProfileUrl!) : null),
                  child: (_imageBytes == null && _currentProfileUrl == null)
                    ? const Icon(Icons.person_outline, size: 40, color: AdminTheme.royalBlue)
                    : null,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AdminTheme.royalBlue, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // --- SECTION 1: AUTHENTICATION ---
          _buildFormHeader("1. Authentication & Role"),
          _buildTextField("Full Name", _nameController, hint: "e.g. Kiran Magar"),
          const SizedBox(height: 16),
          if (!_isEditing) _buildTextField("Email Address (Login ID)", _emailController, hint: "kiran@yourcafe.com")
          else Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text("Email: ${_emailController.text}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("System Role", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        filled: true, fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: ['Waiter', 'Kitchen', 'Cashier', 'Admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField("Login PIN (Numeric)", _pinController, hint: "4-6 digits")),
            ],
          ),
          
          const SizedBox(height: 40),
          // --- SECTION 2: FINANCE ---
          _buildFormHeader("2. Financial Details"),
          Row(
            children: [
              Expanded(child: _buildTextField("Monthly Salary (NPR)", _salaryController, hint: "e.g. 25000")),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField("Payment Cycle (Days)", _cycleController, hint: "e.g. 30")),
            ],
          ),
          
          const SizedBox(height: 40),
          // --- SECTION 3: PERSONAL INFO ---
          _buildFormHeader("3. Personal Information"),
          _buildTextField("Contact Phone Number", _phoneController, hint: "98XXXXXXXX"),
          const SizedBox(height: 16),
          _buildTextField("Citizenship / ID Number", _citizenshipController, hint: "Reg. No / Passport No"),
          const SizedBox(height: 16),
          _buildTextField("Current Residence Address", _currentAddrController, hint: "Street, City"),
          const SizedBox(height: 16),
          _buildTextField("Permanent / Home Address", _permanentAddrController, hint: "District, Region"),
          const SizedBox(height: 16),
          _buildTextField("Document / File Link", _documentController, hint: "Google Drive / Dropbox Link"),
          
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitStaff,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5C00), padding: const EdgeInsets.symmetric(vertical: 18)),
              child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isEditing ? "SAVE PROFILE CHANGES" : "REGISTER STAFF MEMBER"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AdminTheme.royalBlue, letterSpacing: 1)),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildManageEmployeeView() {
    final filteredList = _staffList.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return (s['name']?.toString().toLowerCase().contains(q) ?? false) ||
             (s['role']?.toString().toLowerCase().contains(q) ?? false) ||
             (s['email']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Team Directory", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text("Total Team: ${_staffList.length} Members • ID: ${TenantService().currentTenant.value?.id}", 
                  style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
            IconButton(onPressed: _loadStaff, icon: const Icon(Icons.refresh, color: AdminTheme.royalBlue)),
          ],
        ),
        const SizedBox(height: 24),
        
        // --- SEARCH BAR ---
        Container(
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: "Search by Name, Role or Email...",
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(Icons.search_rounded, color: AdminTheme.royalBlue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 32),

        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (_staffList.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No staff members found in database.")))
        else if (filteredList.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No members match your search.")))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final s = filteredList[index];
              return _buildEmployeeRow(s);
            },
          ),
      ],
    );
  }

  Widget _buildEmployeeRow(Map<String, dynamic> s) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStaff = s;
            _isEditing = false;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(20), 
            boxShadow: AdminTheme.softShadow,
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AdminTheme.royalBlue.withValues(alpha: 0.1),
                backgroundImage: (s['profile_pic_url'] != null && s['profile_pic_url'].isNotEmpty)
                  ? NetworkImage(s['profile_pic_url'])
                  : null,
                child: (s['profile_pic_url'] == null || s['profile_pic_url'].isEmpty)
                  ? Text(
                      (s['name'] ?? 'U')[0].toUpperCase(), 
                      style: const TextStyle(color: AdminTheme.royalBlue, fontWeight: FontWeight.bold)
                    )
                  : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("${s['role']} • ${s['email']}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenericEmployeeView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text("Select 'Manage Employee' to see real data.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAttendanceForm() {
    return const Center(child: Text("Attendance system ready."));
  }

  Widget _buildPayrollView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Payroll & Salary Hub", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text("Live cycle tracking and payment estimations.", style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            IconButton(onPressed: _loadStaff, icon: const Icon(Icons.refresh, color: AdminTheme.royalBlue)),
          ],
        ),
        const SizedBox(height: 32),
        if (_staffList.isEmpty) const Center(child: Text("No staff data found."))
        else ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _staffList.length,
          itemBuilder: (context, index) {
            final s = _staffList[index];
            final double salary = double.tryParse(s['salary_amount']?.toString() ?? '0') ?? 0;
            final int cycle = int.tryParse(s['payment_cycle_days']?.toString() ?? '30') ?? 30;
            
            // PAYROLL LOGIC
            DateTime joinDate = DateTime.tryParse(s['created_at']?.toString() ?? '') ?? DateTime.now();
            final now = DateTime.now();
            final daysSinceJoining = now.difference(joinDate).inDays;
            final daysPassed = daysSinceJoining % cycle;
            final daysRemaining = cycle - daysPassed;
            final double progress = daysPassed / cycle;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(24), 
                boxShadow: AdminTheme.softShadow,
                border: Border.all(color: Colors.grey[100]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AdminTheme.royalBlue.withValues(alpha: 0.1),
                        backgroundImage: (s['profile_pic_url'] != null && s['profile_pic_url'].isNotEmpty) 
                          ? NetworkImage(s['profile_pic_url']) 
                          : null,
                        child: (s['profile_pic_url'] == null || s['profile_pic_url'].isEmpty) 
                          ? Text(s['name'][0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.royalBlue))
                          : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['name'] ?? 'Staff', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(s['role'] ?? 'Employee', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Text("P", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPayrollStat("DATE", "${now.day} ${_months[now.month-1]} ${now.year}"),
                      _buildPayrollStat("STATUS", "Active Cycle", isStatus: true),
                      _buildPayrollStat("SALARY", "NPR ${salary.toStringAsFixed(0)}"),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 60, width: 60,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              backgroundColor: Colors.grey[100],
                              color: AdminTheme.royalBlue,
                            ),
                          ),
                          Text("${(progress * 100).toInt()}%", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Day $daysPassed of $cycle", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text("$daysRemaining days until next payment", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("EST. PAYOUT", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text("NPR ${salary.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, color: AdminTheme.royalBlue, fontSize: 18)),
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
  }

  Widget _buildPayrollStat(String label, String val, {bool isStatus = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isStatus ? Colors.green : Colors.black)),
      ],
    );
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
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
