import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';

class DeliveryAddressDialog extends StatefulWidget {
  final SavedAddress? address;
  const DeliveryAddressDialog({super.key, this.address});
  static Future<void> show(BuildContext context, {SavedAddress? address}) =>
      showDialog(
        context: context,
        builder: (_) => DeliveryAddressDialog(address: address),
      );
  @override
  State<DeliveryAddressDialog> createState() => _DeliveryAddressDialogState();
}

class _DeliveryAddressDialogState extends State<DeliveryAddressDialog> {
  late final TextEditingController _city;
  late final TextEditingController _detail;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final location = context.read<LocationProvider>();
    _city = TextEditingController(
      text: widget.address?.city ?? location.currentCity,
    );
    _detail = TextEditingController(
      text: widget.address?.detailedAddress ?? '',
    );
  }

  @override
  void dispose() {
    _city.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<LocationProvider>().saveAddress(
        _city.text,
        _detail.text,
        id: widget.address?.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Vui lòng nhập tỉnh/thành và địa chỉ chi tiết hợp lệ',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.address == null ? 'Thêm địa chỉ' : 'Sửa địa chỉ'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _city,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Tỉnh/Thành phố'),
        ),
        TextField(
          controller: _detail,
          maxLength: 300,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Địa chỉ chi tiết'),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      ElevatedButton(
        onPressed: _saving ? null : _save,
        child: const Text('Lưu'),
      ),
    ],
  );
}
