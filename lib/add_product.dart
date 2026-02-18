import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:http/http.dart' as http;

class AddProduct extends StatefulWidget {
  const AddProduct({Key? key}) : super(key: key);

  @override
  State<AddProduct> createState() => _AddProductState();
}

class _AddProductState extends State<AddProduct> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(); // NEW: Stock quantity
  final _skuController = TextEditingController(); // NEW: SKU/Barcode

  bool _isLoading = false;
  String? _selectedCategory;
  String? _base64Image;
  Uint8List? _imageBytes;
  double _rating = 0.0; // NEW: Product rating
  bool _lowStockAlert = true; // NEW: Low stock notification

  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Electronics',
    'Fashion',
    'Home & Kitchen',
    'Sports & Outdoors',
    'Books & Stationery',
    'Toys & Games',
    'Automotive',
    'Health & Beauty',
    'Grocery & Food',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _generateSKU(); // Auto-generate SKU on load
  }

  // Auto-generate SKU
  Future<void> _generateSKU() async {
    try {
      // Get total product count
      final snapshot = await FirebaseFirestore.instance.collection('products').get();
      final count = snapshot.docs.length + 1;
      
      // Generate SKU: PROD-XXXX format
      final sku = 'PROD-${count.toString().padLeft(4, '0')}';
      
      setState(() {
        _skuController.text = sku;
      });
    } catch (e) {
      // Fallback: Use timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      setState(() {
        _skuController.text = 'PROD-$timestamp';
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  // Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        
        if (bytes.length > 800000) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image too large! Please select a smaller image.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        
        final base64String = base64Encode(bytes);

        setState(() {
          _imageBytes = bytes;
          _base64Image = 'data:image/png;base64,$base64String';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image selected (${(bytes.length / 1024).toStringAsFixed(0)} KB)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show image source dialog
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.orange),
              title: const Text('Image URL'),
              onTap: () {
                Navigator.pop(context);
                _showUrlDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show URL input dialog
  void _showUrlDialog() {
    final urlController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Image URL'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'https://example.com/image.jpg',
            labelText: 'Image URL',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context);
                await _loadImageFromUrl(url);
              }
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  // Load image from URL
  Future<void> _loadImageFromUrl(String url) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        if (bytes.length > 800000) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image too large! Max 800KB allowed.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        final base64String = base64Encode(bytes);

        setState(() {
          _imageBytes = bytes;
          _base64Image = 'data:image/png;base64,$base64String';
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image loaded (${(bytes.length / 1024).toStringAsFixed(0)} KB)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to load image');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addProduct() async {
    if (_formKey.currentState!.validate()) {
      if (_base64Image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an image'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final stockQty = int.tryParse(_stockController.text) ?? 0;
        
        await FirebaseFirestore.instance.collection('products').add({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': _priceController.text.trim(),
          'images': _base64Image,
          'category': _selectedCategory ?? 'Other',
          'rating': _rating, // NEW
          'stock': stockQty, // NEW
          'sku': _skuController.text.trim(), // NEW
          'lowStockAlert': _lowStockAlert, // NEW
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildRatingSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Rating',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () => setState(() => _rating = index + 1.0),
              child: Icon(
                index < _rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          _rating > 0 ? '${_rating.toStringAsFixed(1)} stars' : 'No rating',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Product"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Picker
                    GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[400]!, width: 2),
                        ),
                        child: _imageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 60, color: Colors.grey[600]),
                                  const SizedBox(height: 8),
                                  Text('Tap to add product image', style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Product Title *',
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter product title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(value: category, child: Text(category));
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedCategory = value),
                      validator: (value) => value == null ? 'Please select a category' : null,
                    ),
                    const SizedBox(height: 16),

                    // Price and Stock Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Price *',
                              prefixIcon: const Icon(Icons.attach_money),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter price';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Stock Qty',
                              prefixIcon: const Icon(Icons.inventory_2),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // SKU/Barcode with Auto-generate
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _skuController,
                            readOnly: true, // Make it read-only
                            decoration: InputDecoration(
                              labelText: 'SKU / Barcode (Auto)',
                              prefixIcon: const Icon(Icons.qr_code),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _generateSKU,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Generate New SKU',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Rating
                    _buildRatingSelector(),
                    const SizedBox(height: 16),

                    // Low Stock Alert
                    SwitchListTile(
                      title: const Text('Low Stock Alerts'),
                      subtitle: const Text('Get notified when stock is low'),
                      value: _lowStockAlert,
                      onChanged: (value) => setState(() => _lowStockAlert = value),
                      secondary: const Icon(Icons.notifications),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: const Icon(Icons.description),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _addProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Add Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}