import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin_theme.dart';

class ThemeManagementScreen extends StatefulWidget {
  const ThemeManagementScreen({super.key});

  @override
  State<ThemeManagementScreen> createState() => _ThemeManagementScreenState();
}

class _ThemeManagementScreenState extends State<ThemeManagementScreen> {
  Color _primaryColor = AdminTheme.royalBlue;
  bool _isDarkMode = false;
  double _borderRadius = 16.0;
  String _fontFamily = 'Inter';
  String _selectedThemeName = "Default Blue";
  bool _isLoadingSettings = true;

  final List<Map<String, dynamic>> _themePresets = [
    {
      "name": "Default Blue",
      "primary": AdminTheme.royalBlue,
      "secondary": AdminTheme.darkNavy,
      "bg": AdminTheme.pearlWhite,
    },
    {
      "name": "Emerald Garden",
      "primary": const Color(0xFF00A36C),
      "secondary": const Color(0xFF004526),
      "bg": const Color(0xFFF0F7F4),
    },
    {
      "name": "Sunset Orange",
      "primary": const Color(0xFFFF5C00),
      "secondary": const Color(0xFF802F00),
      "bg": const Color(0xFFFFF5F0),
    },
    {
      "name": "Midnight Purple",
      "primary": const Color(0xFF6200EE),
      "secondary": const Color(0xFF3700B3),
      "bg": const Color(0xFFF9F5FF),
    },
    {
      "name": "Royal Gold",
      "primary": const Color(0xFFD4AF37),
      "secondary": const Color(0xFF5C4033),
      "bg": const Color(0xFFFFFDF5),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final colorValue = prefs.getInt('theme_primary_color');
        if (colorValue != null) _primaryColor = Color(colorValue);
        _isDarkMode = prefs.getBool('theme_dark_mode') ?? false;
        _borderRadius = prefs.getDouble('theme_border_radius') ?? 16.0;
        _fontFamily = prefs.getString('theme_font_family') ?? 'Inter';
        _selectedThemeName = prefs.getString('theme_name') ?? "Default Blue";
        _isLoadingSettings = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_primary_color', _primaryColor.value);
    await prefs.setBool('theme_dark_mode', _isDarkMode);
    await prefs.setDouble('theme_border_radius', _borderRadius);
    await prefs.setString('theme_font_family', _fontFamily);
    await prefs.setString('theme_name', _selectedThemeName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Theme settings saved and applied!"),
          backgroundColor: AdminTheme.emeraldGreen,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSettings) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Appearance & Personalization", 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                  Text("Customize your restaurant's digital identity and interface.", 
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text("APPLY CHANGES"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          LayoutBuilder(builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 900;
            return Column(
              children: [
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildControlsSection()),
                      const SizedBox(width: 32),
                      Expanded(flex: 2, child: _buildPreviewSection()),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildPreviewSection(),
                      const SizedBox(height: 32),
                      _buildControlsSection(),
                    ],
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: "Brand Colors",
          subtitle: "Choose a primary color for your app's branding.",
          icon: Icons.color_lens_outlined,
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _themePresets.map((t) => _buildThemeChip(t)).toList(),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text("Custom Primary Color: ", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!, width: 2)
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(onPressed: _showColorPicker, child: const Text("PICK COLOR")),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: "Interface Style",
          subtitle: "Adjust how components look across the dashboard.",
          icon: Icons.auto_awesome_mosaic_outlined,
          child: Column(
            children: [
              _buildToggleOption(
                "Dark Mode", 
                "Reduce eye strain in low light.", 
                _isDarkMode, 
                (v) => setState(() => _isDarkMode = v)
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Component Roundness", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("${_borderRadius.toInt()}px", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _borderRadius,
                      min: 0,
                      max: 32,
                      activeColor: _primaryColor,
                      onChanged: (v) => setState(() => _borderRadius = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: "Typography",
          subtitle: "Choose a font that matches your restaurant's personality.",
          icon: Icons.font_download_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _fontFamily,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: ['Inter', 'Roboto', 'Poppins', 'Lato', 'Open Sans', 'Serif', 'Monospace']
                    .map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) => setState(() => _fontFamily = v!),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Aa - Quick Brown Fox", 
                      style: TextStyle(fontFamily: _fontFamily, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("This is how your menu and dashboard text will look.", 
                      style: TextStyle(fontFamily: _fontFamily, fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeChip(Map<String, dynamic> t) {
    bool isSelected = _selectedThemeName == t['name'];
    return GestureDetector(
      onTap: () => setState(() {
        _selectedThemeName = t['name'];
        _primaryColor = t['primary'];
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? _primaryColor : Colors.grey[200]!, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: _primaryColor.withValues(alpha: 0.1), blurRadius: 10)] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: t['primary'], shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(t['name'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("LIVE PREVIEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF161621) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AdminTheme.softShadow,
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Column(
            children: [
              // Fake App Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 80, height: 12, decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4))),
                  CircleAvatar(radius: 12, backgroundColor: _primaryColor),
                ],
              ),
              const SizedBox(height: 32),
              
              // Fake Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF1E1E2C) : AdminTheme.pearlWhite,
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(8))),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 100, height: 8, color: _isDarkMode ? Colors.white24 : Colors.grey[300]),
                            const SizedBox(height: 4),
                            Container(width: 60, height: 6, color: _isDarkMode ? Colors.white12 : Colors.grey[200]),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Fake Button
              Container(
                width: double.infinity,
                height: 40,
                decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(_borderRadius)),
                child: Center(child: Text("ORDER NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, fontFamily: _fontFamily))),
              ),
              const SizedBox(height: 16),
              
              // Fake Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniTab("Home", true),
                  _buildMiniTab("Menu", false),
                  _buildMiniTab("Staff", false),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text("Current Font: $_fontFamily", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryColor, fontFamily: _fontFamily)),
        const Text("This preview reflects how your SaaS dashboard will appear to your specific restaurant account.", 
          style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildMiniTab(String label, bool active) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: active ? _primaryColor : Colors.grey, fontFamily: _fontFamily)),
        const SizedBox(height: 4),
        if (active) Container(width: 20, height: 2, color: _primaryColor),
      ],
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pick Brand Color"),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: Colors.primaries.map((c) => GestureDetector(
              onTap: () {
                setState(() {
                  _primaryColor = c;
                  _selectedThemeName = "Custom";
                });
                Navigator.pop(ctx);
              },
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: c, 
                  shape: BoxShape.circle, 
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: AdminTheme.softShadow
                ),
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required String subtitle, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AdminTheme.softShadow
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: _primaryColor, size: 20)
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildToggleOption(String title, String sub, bool val, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          Switch(value: val, onChanged: onChanged, activeColor: _primaryColor),
        ],
      ),
    );
  }
}
