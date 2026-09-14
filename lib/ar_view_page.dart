import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'models.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class ARViewPage extends StatefulWidget {
  final Product product;
  const ARViewPage({super.key, required this.product});

  @override
  State<ARViewPage> createState() => _ARViewPageState();
}

class _ARViewPageState extends State<ARViewPage> {
  late String _viewId;
  bool _showDirectAR = false;
  Timer? _loadTimer;

  @override
  void initState() {
    super.initState();
    _viewId = 'model-viewer-${widget.product.title.hashCode}';
    
    // Register the model-viewer element directly in the browser
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final element = web.document.createElement('model-viewer') as web.HTMLElement;
        
        // Android / Web GLB
        if (widget.product.modelUrl != null && widget.product.modelUrl!.isNotEmpty) {
          element.setAttribute('src', widget.product.modelUrl!);
        }
        
        // iOS USDZ (Critical for AR Quick Look on Apple devices)
        if (widget.product.iosModelUrl != null && widget.product.iosModelUrl!.isNotEmpty) {
          element.setAttribute('ios-src', widget.product.iosModelUrl!);
        }

        element.setAttribute('ar', '');
        element.setAttribute('ar-modes', 'webxr scene-viewer quick-look');
        element.setAttribute('camera-controls', '');
        element.setAttribute('auto-rotate', '');
        element.setAttribute('shadow-intensity', '1');
        element.style.width = '100%';
        element.style.height = '100%';
        
        // Set white background to cover the spinner once the component is ready
        element.style.backgroundColor = 'white'; 
        
        return element;
      },
    );

    _loadTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showDirectAR = true);
    });
  }

  Future<void> _launchNativeAR() async {
    // Detect if we are on Web
    const bool isWeb = kIsWeb;
    final bool isMobile = Theme.of(context).platform == TargetPlatform.iOS || 
                          Theme.of(context).platform == TargetPlatform.android;

    if (isWeb && !isMobile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fast AR is only available on Mobile Devices (iOS/Android)."))
      );
      return;
    }

    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    try {
      if (isIOS) {
        final String? iosUrl = widget.product.iosModelUrl;
        if (iosUrl == null || iosUrl.isEmpty) {
          throw "USDZ model missing for iPhone AR.";
        }
        
        final Uri uri = Uri.parse(iosUrl);
        // Use externalApplication for native AR launch
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final String? glbUrl = widget.product.modelUrl;
        if (glbUrl == null || glbUrl.isEmpty) {
          throw "GLB model missing for Android AR.";
        }

        final String encodedUrl = Uri.encodeComponent(glbUrl);
        final String title = Uri.encodeComponent(widget.product.title);
        final String intentUrl = "https://arvr.google.com/scene-viewer/1.0?file=$encodedUrl&mode=ar_only&title=$title";
        
        debugPrint("AR Launch (Android): $intentUrl");
        await launchUrl(Uri.parse(intentUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Launch Error: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasModel = widget.product.modelUrl != null && widget.product.modelUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "3D PREVIEW: ${widget.product.title.toUpperCase()}",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (!hasModel)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.view_in_ar_rounded, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 24),
                    const Text(
                      "3D Model Coming Soon!",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "We are currently working on a high-quality 3D scan of ${widget.product.title}. Check back later!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], height: 1.5),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5C00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("GO BACK"),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Background Loading State
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF5C00)),
                  SizedBox(height: 24),
                  Text("Initializing 3D Engine...", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // The Direct HTML View
            HtmlElementView(viewType: _viewId),

            // Bottom Action Bar
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  if (_showDirectAR) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
                      child: const Text(
                        "Is the preview slow? Try launching native AR directly.",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _launchNativeAR,
                          icon: const Icon(Icons.view_in_ar_rounded, size: 20),
                          label: const Text("Launch Fast AR", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5C00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
