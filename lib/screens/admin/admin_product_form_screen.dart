import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../models/product_model.dart';
import '../../themes.dart';
import '../../widgets/custom_button.dart';

class AdminProductFormScreen extends StatefulWidget {
  final Product? product;

  const AdminProductFormScreen({super.key, this.product});

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  String? _categoryKey;

  bool _isLoading = false;
  File? _imageFile;
  String? _existingImageUrl;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
      text: widget.product != null
          ? widget.product!.price
                .toStringAsFixed(0)
                .replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')
          : '',
    );
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _categoryKey = widget.product?.category;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CategoryProvider>().loadCategories(forceRefresh: true);
      }
    });

    _existingImageUrl = widget.product?.imageUrl;
    _isAvailable = widget.product?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final file = File(pickedFile.path);
        final bytes = await file.openRead(0, 3).first;
        final jpeg =
            bytes.length == 3 &&
            bytes[0] == 0xff &&
            bytes[1] == 0xd8 &&
            bytes[2] == 0xff;
        if (!jpeg || await file.length() >= 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chỉ chọn ảnh JPEG nhỏ hơn 5 MB')),
            );
          }
          return;
        }
        if (mounted) setState(() => _imageFile = file);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Không đọc được ảnh: $error')));
        }
      }
    }
  }

  Future<String?> _uploadImage(String productId) async {
    if (_imageFile == null) return _existingImageUrl;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('products')
          .child('${productId}_${DateTime.now().microsecondsSinceEpoch}.jpg');

      await storageRef.putFile(
        _imageFile!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw Exception('Lỗi Storage: $e');
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    QuerySnapshot<Map<String, dynamic>> categoryDocs;
    try {
      categoryDocs = await FirebaseFirestore.instance
          .collection('categories')
          .get();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không kiểm tra được danh mục: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    final keys = categoryDocs.docs
        .where(
          (doc) =>
              doc.data()['isActive'] == true && doc.data()['name'] == doc.id,
        )
        .map((doc) => doc.data()['name'] as String?)
        .toSet();
    if (_categoryKey == null || !keys.contains(_categoryKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục hợp lệ')),
      );
      return;
    }

    if (_imageFile == null &&
        (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ảnh sản phẩm')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isUpdating = widget.product != null;
      final docRef = isUpdating
          ? FirebaseFirestore.instance
                .collection('products')
                .doc(widget.product!.id)
          : FirebaseFirestore.instance.collection('products').doc();

      final productId = docRef.id;

      // Upload image
      final imageUrl = await _uploadImage(productId);

      final productData = {
        'name': _nameController.text.trim(),
        'price': int.parse(
          _priceController.text.trim().replaceAll(RegExp(r'[.,]'), ''),
        ),
        'description': _descriptionController.text.trim(),
        'category': _categoryKey,
        'imageURL': imageUrl,
        'imageUrl': imageUrl, // Thêm cả 2 key để tương thích
        'isAvailable': _isAvailable,
        'rating': widget.product?.rating ?? 0.0,
      };

      if (isUpdating) {
        await docRef.update(productData);
      } else {
        await docRef.set(productData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUpdating ? 'Cập nhật thành công' : 'Thêm mới thành công',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpdating = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isUpdating ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm mới',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Picker Section
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[300]!),
                            image: _imageFile != null
                                ? DecorationImage(
                                    image: FileImage(_imageFile!),
                                    fit: BoxFit.cover,
                                  )
                                : (_existingImageUrl != null &&
                                      _existingImageUrl!.isNotEmpty)
                                ? DecorationImage(
                                    image: _existingImageUrl!.startsWith('http')
                                        ? NetworkImage(_existingImageUrl!)
                                              as ImageProvider
                                        : AssetImage(_existingImageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child:
                              _imageFile == null &&
                                  (_existingImageUrl == null ||
                                      _existingImageUrl!.isEmpty)
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Chọn ảnh',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      validator: (value) =>
                          value!.isEmpty ? 'Vui lòng nhập tên' : null,
                      decoration: InputDecoration(
                        labelText: 'Tên sản phẩm',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Price Field
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập giá';
                        }
                        final amount = int.tryParse(
                          value.replaceAll(RegExp(r'[.,]'), ''),
                        );
                        if (amount == null || amount <= 0) {
                          return 'Giá phải là số';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Giá size S (đ)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category key from Firestore; free text is not accepted.
                    Consumer<CategoryProvider>(
                      builder: (context, provider, _) {
                        final categories = provider.categories;
                        final value =
                            categories.any(
                              (c) => c.id == c.name && c.name == _categoryKey,
                            )
                            ? _categoryKey
                            : null;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (provider.isLoading)
                              const LinearProgressIndicator(),
                            if (provider.errorMessage != null)
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Không tải được danh mục'),
                                  ),
                                  TextButton(
                                    onPressed: () => provider.loadCategories(
                                      forceRefresh: true,
                                    ),
                                    child: const Text('Thử lại'),
                                  ),
                                ],
                              ),
                            DropdownButtonFormField<String>(
                              key: ValueKey(value),
                              initialValue: value,
                              decoration: const InputDecoration(
                                labelText: 'Danh mục',
                              ),
                              items: categories
                                  .where((c) => c.id == c.name)
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.name,
                                      child: Text(c.displayName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (key) =>
                                  setState(() => _categoryKey = key),
                              validator: (key) =>
                                  key == null ? 'Chọn danh mục' : null,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      validator: (value) =>
                          value!.isEmpty ? 'Vui lòng nhập mô tả' : null,
                      decoration: InputDecoration(
                        labelText: 'Mô tả',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // isAvailable Switch
                    SwitchListTile(
                      title: const Text('Trạng thái mở bán'),
                      subtitle: Text(_isAvailable ? 'Đang bán' : 'Tạm ẩn'),
                      value: _isAvailable,
                      activeThumbColor: AppThemes.primaryColor,
                      activeTrackColor: AppThemes.primaryColor.withValues(
                        alpha: 0.5,
                      ),
                      onChanged: (bool value) {
                        setState(() {
                          _isAvailable = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    CustomButton(
                      text: isUpdating ? 'Cập nhật' : 'Thêm sản phẩm',
                      onPressed: _saveProduct,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
