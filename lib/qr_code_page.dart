import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class QRCodePage extends StatefulWidget {
  const QRCodePage({Key? key}) : super(key: key);

  @override
  State<QRCodePage> createState() => _QRCodePageState();
}

class _QRCodePageState extends State<QRCodePage> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  String _qrData = '';
  bool _isLoading = false;
  Map<String, dynamic>? _productData;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateQR() async {
    if (_controller.text.trim().isEmpty) {
      _showToast('Please enter product ID or SKU', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    final String input = _controller.text.trim();

    try {
      QuerySnapshot productSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('productId', isEqualTo: input)
          .limit(1)
          .get();

      if (productSnapshot.docs.isEmpty) {
        productSnapshot = await FirebaseFirestore.instance
            .collection('products')
            .where('sku', isEqualTo: input)
            .limit(1)
            .get();
      }

      if (productSnapshot.docs.isEmpty) {
        productSnapshot = await FirebaseFirestore.instance
            .collection('products')
            .where('id', isEqualTo: input)
            .limit(1)
            .get();
      }

      if (productSnapshot.docs.isNotEmpty) {
        final productDoc = productSnapshot.docs.first;
        final productData = productDoc.data() as Map<String, dynamic>;
        
        String productId = productData['productId'] ?? 
                          productData['id'] ?? 
                          productDoc.id;
        
        final String deepLink = 'myapp://product/$productId';
        
        setState(() {
          _qrData = deepLink;
          _productData = productData;
          _isLoading = false;
        });

        String productName = productData['name'] ?? 
                            productData['title'] ?? 
                            'Product';
        
        _showToast('✅ QR generated for: $productName', Colors.green);
      } else {
        setState(() => _isLoading = false);
        _showToast('❌ No product found with ID/SKU: $input', Colors.red);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showToast('Error: $e', Colors.red);
    }
  }

  Future<void> _shareQR() async {
    if (_qrData.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final qrPainter = QrPainter(
        data: _qrData,
        version: QrVersions.auto,
        gapless: true,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final qrSize = 400.0;
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(qrSize, qrSize);
      
      qrPainter.paint(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(qrSize.toInt(), qrSize.toInt());
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      
      if (byteData == null) throw Exception('Failed to generate image');

      final bytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      String shareText = '📦 *Check out this product!*\n\n';
      if (_productData != null) {
        String productName = _productData!['name'] ?? 
                            _productData!['title'] ?? 
                            'Product';
        shareText += '**Product:** $productName\n';
        shareText += '**Price:** \$${_productData!['price'] ?? 'N/A'}\n\n';
      }
      shareText += '🔗 Scan QR code to open in app';

      await Share.shareXFiles(
        [XFile(filePath)],
        text: shareText,
      );

      setState(() => _isLoading = false);
      _showToast('✅ QR Code shared successfully', Colors.green);
    } catch (e) {
      setState(() => _isLoading = false);
      _showToast('❌ Error sharing QR: $e', Colors.red);
    }
  }

  void _clearAll() {
    setState(() {
      _controller.clear();
      _qrData = '';
      _productData = null;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _showToast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : 
              color == Colors.orange ? Icons.warning : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔥 FIX: Keyboard handling
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'QR Code Generator',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_qrData.isNotEmpty && !_isLoading) ...[
            Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _clearAll,
                tooltip: 'New QR Code',
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareQR,
                tooltip: 'Share QR Code',
              ),
            ),
          ],
        ],
      ),
      body: SafeArea( // 🔥 Added SafeArea
        child: LayoutBuilder( // 🔥 LayoutBuilder for responsive height
          builder: (context, constraints) {
            return SingleChildScrollView( // 🔥 Now properly scrolls with keyboard
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Premium Input Field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  decoration: InputDecoration(
                                    labelText: 'Product ID or SKU',
                                    hintText: 'Enter product ID or SKU...',
                                    labelStyle: const TextStyle(color: Color(0xFF1E3C72)),
                                    border: InputBorder.none,
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.qr_code,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  enabled: !_isLoading,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _generateQR,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Generate',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Content Area
                      if (_isLoading)
                        _buildLoadingState()
                      else if (_qrData.isNotEmpty && _productData != null)
                        _buildQRDisplay()
                      else
                        _buildEmptyState(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3C72).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Generating QR Code...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E3C72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.qr_code_2,
              size: 80,
              color: Colors.blue.shade200,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Enter Product ID or SKU',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'to generate QR code',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Use Product ID or SKU',
                  style: TextStyle(color: Colors.blue[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRDisplay() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        children: [
          // Product Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blue.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _productData!['name'] ?? 
                  _productData!['title'] ?? 
                  'Product',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3C72),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_money, color: Colors.green, size: 18),
                          Text(
                            '${_productData!['price']?.toString() ?? '0'}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // QR Code
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 250.0,
              backgroundColor: Colors.white,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Deep Link Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3C72).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.link,
                        color: Color(0xFF1E3C72),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Deep Link:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3C72),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: SelectableText(
                    _qrData,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Share Button
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3C72).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _shareQR,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.share, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Share QR Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // New QR Button
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.refresh),
            label: const Text('Generate New QR'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}