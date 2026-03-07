import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  late TextEditingController _categoryController;

  bool _isLoading = false;
  File? _imageFile;
  String? _existingImageUrl;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
      text: widget.product != null ? widget.product!.price.toString() : '',
    );
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.product?.category ?? '',
    );

    _existingImageUrl = widget.product?.imageUrl;
    _isAvailable = widget.product?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String productId) async {
    if (_imageFile == null) return _existingImageUrl;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('products')
          .child('$productId.jpg');

      await storageRef.putFile(_imageFile!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null && _existingImageUrl == null) {
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

      if (imageUrl == null) {
        throw Exception('Không thể tải ảnh lên');
      }

      final productData = {
        'name': _nameController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'description': _descriptionController.text.trim(),
        'category': _categoryController.text.trim(),
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
        title: Text(isUpdating ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm mới'),
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
                        if (double.tryParse(value) == null) {
                          return 'Giá phải là số';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Giá (đ)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Field
                    TextFormField(
                      controller: _categoryController,
                      validator: (value) =>
                          value!.isEmpty ? 'Vui lòng nhập loại' : null,
                      decoration: InputDecoration(
                        labelText: 'Loại sản phẩm (vd: Cà phê, Trà...)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
