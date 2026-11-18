import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../providers/category_provider.dart';

class AdminCategoryScreen extends StatefulWidget {
  const AdminCategoryScreen({super.key});
  @override
  State<AdminCategoryScreen> createState() => _AdminCategoryScreenState();
}

class _AdminCategoryScreenState extends State<AdminCategoryScreen> {
  int _retry = 0;

  Future<void> _edit(CategoryModel? category) async {
    if (category != null && category.id != category.name) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Danh mục cũ có ID khác key; chạy seed catalog để chuyển dữ liệu.',
          ),
        ),
      );
      return;
    }
    final key = TextEditingController(text: category?.name ?? '');
    final name = TextEditingController(text: category?.displayName ?? '');
    final order = TextEditingController(text: '${category?.order ?? 0}');
    final form = GlobalKey<FormState>();
    bool active = category?.isActive ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(category == null ? 'Thêm danh mục' : 'Sửa danh mục'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: key,
                  enabled: category == null,
                  decoration: const InputDecoration(
                    labelText: 'Key ổn định (a-z, 0-9, -)',
                  ),
                  validator: (v) =>
                      RegExp(r'^[a-z][a-z0-9-]{1,39}$').hasMatch(v ?? '')
                      ? null
                      : 'Key phải dài 2–40 ký tự, bắt đầu bằng chữ thường',
                ),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                  validator: (v) =>
                      (v?.trim().isNotEmpty ?? false) && v!.trim().length <= 80
                      ? null
                      : 'Nhập tên tối đa 80 ký tự',
                ),
                TextFormField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Thứ tự'),
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Nhập số nguyên' : null,
                ),
                SwitchListTile(
                  title: const Text('Hiển thị'),
                  subtitle: const Text(
                    'Ẩn sẽ ngừng bán các sản phẩm thuộc danh mục',
                  ),
                  value: active,
                  onChanged: (value) => refresh(() => active = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                try {
                  final doc = FirebaseFirestore.instance
                      .collection('categories')
                      .doc(category?.id ?? key.text.trim());
                  final data = {
                    'name': key.text.trim(),
                    'displayName': name.text.trim(),
                    'order': int.parse(order.text),
                    'isActive': active,
                  };
                  if (category == null) {
                    final existingKey = await FirebaseFirestore.instance
                        .collection('categories')
                        .where('name', isEqualTo: key.text.trim())
                        .limit(1)
                        .get();
                    if (existingKey.docs.isNotEmpty ||
                        (await doc.get()).exists) {
                      throw StateError('Key danh mục đã tồn tại');
                    }
                    await doc.set(data);
                  } else {
                    if (category.isActive && !active) {
                      final products = await FirebaseFirestore.instance
                          .collection('products')
                          .where('category', isEqualTo: category.name)
                          .get();
                      for (
                        var start = 0;
                        start < products.docs.length;
                        start += 450
                      ) {
                        final batch = FirebaseFirestore.instance.batch();
                        for (final product
                            in products.docs.skip(start).take(450)) {
                          batch.update(product.reference, {
                            'isAvailable': false,
                          });
                        }
                        await batch.commit();
                      }
                    }
                    await doc.update(data);
                  }
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Không thể lưu danh mục: $error')),
                    );
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    key.dispose();
    name.dispose();
    order.dispose();
    if (saved == true && mounted) {
      context.read<CategoryProvider>().loadCategories(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Danh mục')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey(_retry),
      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tải được danh mục'),
                TextButton(
                  onPressed: () => setState(() => _retry++),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final categories =
            snapshot.data!.docs
                .map((d) => CategoryModel.fromFirestore(d.data(), d.id))
                .toList()
              ..sort((a, b) => a.order.compareTo(b.order));
        if (categories.isEmpty) {
          return const Center(child: Text('Chưa có danh mục'));
        }
        return ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, i) {
            final c = categories[i];
            return ListTile(
              title: Text(c.displayName),
              subtitle: Text(
                c.id == c.name
                    ? '${c.name} • thứ tự ${c.order} • ${c.isActive ? 'Hiển thị' : 'Đã ẩn'}'
                    : '${c.name} • ID cũ ${c.id} • cần chuyển dữ liệu',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _edit(c),
              ),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _edit(null),
      child: const Icon(Icons.add),
    ),
  );
}
