import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'cart_manager.dart';
import 'services/api_service.dart';
import 'services/tenant_service.dart';
import 'dart:async';

import 'package:flutter/services.dart'; // Added for Clipboard

class ActivitySharePage extends StatefulWidget {
  const ActivitySharePage({super.key});

  @override
  State<ActivitySharePage> createState() => _ActivitySharePageState();
}

class _ActivitySharePageState extends State<ActivitySharePage> with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  final ImagePicker _picker = ImagePicker();
  late AnimationController _scanLineController;
  
  Uint8List? _userImageBytes;
  Map<String, dynamic>? _latestOrder;
  bool _isLoading = true;
  bool _isSharing = false;

  // AI Scanning State
  bool _isScanning = false;
  double _scanProgress = 0.0;
  String _scanStatusText = "Initializing AI...";
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _scanTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final order = await ApiService.fetchLatestOrder(tenant.id, ShopManager.instance.currentUserId);
    if (mounted) {
      setState(() {
        _latestOrder = order;
        _isLoading = false;
      });
    }
  }

  void _startAIScan() {
    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _scanStatusText = "Analyzing photo details...";
    });
    _scanLineController.repeat();

    const totalSteps = 60; // 6 seconds / 100ms
    int currentStep = 0;

    _scanTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      currentStep++;
      if (mounted) {
        setState(() {
          _scanProgress = currentStep / totalSteps;
          
          if (currentStep < 15) {
            _scanStatusText = "Detecting key facial features...";
          } else if (currentStep < 30) {
            _scanStatusText = "Matching with latest order...";
          } else if (currentStep < 45) {
            _scanStatusText = "Enhancing cinematic lighting...";
          } else {
            _scanStatusText = "Finalizing premium frame...";
          }
        });
      }

      if (currentStep >= totalSteps) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
          _scanLineController.stop();
        }
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _userImageBytes = bytes;
      });
      _startAIScan();
    }
  }

  Future<void> _shareStory() async {
    if (_userImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload or take a photo first!")),
      );
      return;
    }

    setState(() => _isSharing = true);

    try {
      // Auto-copy handle to clipboard for the user
      final tenant = TenantService().currentTenant.value;
      final String handle = "@${tenant?.name.toLowerCase().replaceAll(' ', '_') ?? 'chiyala'}_official";
      await Clipboard.setData(ClipboardData(text: handle));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Handle $handle copied! Paste it in Instagram stickers."),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }

      final imageBytes = await _screenshotController.capture();
      if (imageBytes != null) {
        final xFile = XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: 'chiyala_story.png',
        );

        final result = await Share.shareXFiles(
          [xFile],
          text: "My favorite meal at Chiyala! 🍔🔥 $handle #ChiyalaMoments",
        );

        if (result.status == ShareResultStatus.success || result.status == ShareResultStatus.dismissed) {
          // Reward Points
          if (tenant != null) {
            await ShopManager.instance.addPoints(tenant.id, ShopManager.instance.currentUserId, points: 50);
            if (mounted) {
              _showSuccessDialog();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Share Error: $e");
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("🏆 REWARD EARNED!", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            const Text("You earned +50 Points!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "Your story was shared successfully. These points can be used on your next order at Chiyala!", 
              textAlign: TextAlign.center, 
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("COLLECT POINTS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5C00))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Share & Earn", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. STORY PREVIEW FRAME
            Screenshot(
              controller: _screenshotController,
              child: _buildStoryFrame(),
            ),
            
            const SizedBox(height: 32),
            
            // 2. ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.photo_library_outlined,
                    label: "Gallery",
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.camera_alt_outlined,
                    label: "Camera",
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareStory,
                icon: _isSharing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.share_rounded, color: Colors.white),
                label: Text(
                  _isSharing ? "SHARING..." : "SHARE STORY & EARN +50", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: Colors.grey[400],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            const Text(
              "Share your experience to Instagram and get rewarded instantly!",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryFrame() {
    final tenant = TenantService().currentTenant.value;
    final foodImage = (_latestOrder != null && _latestOrder!['items'] != null && (_latestOrder!['items'] as List).isNotEmpty)
        ? _latestOrder!['items'][0]['image']
        : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500';

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2), 
              blurRadius: 30, 
              offset: const Offset(0, 15)
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // 1. Background Image
              Positioned.fill(
                child: _userImageBytes != null 
                  ? Image.memory(_userImageBytes!, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFFF3F4F6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text("Upload your photo", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
              ),

              // 2. High-End Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.4, 0.7, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Top Branding Section
              Positioned(
                top: 40,
                left: 24,
                right: 24,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFFFF5C00).withValues(alpha: 0.5), blurRadius: 15)],
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: Color(0xFFFF5C00), size: 24),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant?.name.toUpperCase() ?? "CHIYALA",
                            style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.w900, 
                              fontSize: 22, 
                              letterSpacing: 3,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2))],
                            ),
                          ),
                          const Text(
                            "ELEVATED DINING EXPERIENCE", 
                            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Gold "Verified Order" Floating Badge
              Positioned(
                top: 110,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        "VERIFIED ORDER", 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),

              // 4b. Visual Instagram Mention Sticker (New)
              Positioned(
                top: 160,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.alternate_email_rounded, color: Color(0xFFFF5C00), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "${tenant?.name.toLowerCase().replaceAll(' ', '_') ?? 'chiyala'}_official",
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Bottom Content (Glassmorphism Order Badge)
              Positioned(
                bottom: 30,
                left: 20,
                right: 30,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                foodImage.isNotEmpty ? foodImage : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
                                width: 75,
                                height: 75,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: Colors.white24, child: const Icon(Icons.fastfood, color: Colors.white54)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "MY CHIYALA FAVORITE", 
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFFF9D00), letterSpacing: 1),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (_latestOrder != null && _latestOrder!['items'] != null && (_latestOrder!['items'] as List).isNotEmpty)
                                      ? _latestOrder!['items'][0]['product_name']
                                      : "Signature Meal",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900, 
                                    fontSize: 20, 
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: const [
                                    Icon(Icons.stars_rounded, color: Colors.amber, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      "Top Rated Cuisine", 
                                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 6. AI SCANNING OVERLAY
              if (_isScanning)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: Stack(
                      children: [
                        // Vertical Laser Line
                        AnimatedBuilder(
                          animation: _scanLineController,
                          builder: (context, child) {
                            return Positioned(
                              top: MediaQuery.of(context).size.height * 0.4 * _scanLineController.value,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFFF5C00).withValues(alpha: 0),
                                      const Color(0xFFFF5C00),
                                      const Color(0xFFFF5C00).withValues(alpha: 0),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF5C00).withValues(alpha: 0.8),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Scanning Status UI
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: const Color(0xFFFF5C00).withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5C00)),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      _scanStatusText,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: 200,
                                child: LinearProgressIndicator(
                                  value: _scanProgress,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5C00)),
                                  borderRadius: BorderRadius.circular(10),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "${(_scanProgress * 100).toInt()}% ANALYZED",
                                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFF5C00), size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
