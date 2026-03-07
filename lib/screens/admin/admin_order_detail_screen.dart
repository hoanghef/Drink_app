import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../themes.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const AdminOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late String _currentStatus;
  bool _isUpdating = false;

  final List<String> _statusOptions = [
    'Chờ xác nhận',
    'Đang pha chế',
    'Đang giao',
    'Hoàn thành',
    'Hủy',
  ];

  @override
  void initState() {
    super.initState();
    // Normalize old status formats if present
    String status = widget.orderData['status'] ?? 'Chờ xác nhận';
    if (status == 'processing') status = 'Chờ xác nhận';
    if (status == 'completed') status = 'Hoàn thành';
    if (status == 'cancelled') status = 'Hủy';

    _currentStatus = _statusOptions.contains(status) ? status : 'Chờ xác nhận';
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(amount)}đ';
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'status': newStatus});

      setState(() {
        _currentStatus = newStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật trạng thái thành công'),
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
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.orderData['items'] as List<dynamic>? ?? [];
    final amount = widget.orderData['amount'] ?? 0.0;
    final deliveryAddress =
        widget.orderData['deliveryAddress'] as Map<String, dynamic>?;
    final isDelivery = widget.orderData['isDelivery'] ?? true;
    final note = widget.orderData['note'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn hàng'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Update Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Trạng thái:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _isUpdating
                        ? const CircularProgressIndicator()
                        : DropdownButton<String>(
                            value: _currentStatus,
                            items: _statusOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null &&
                                  newValue != _currentStatus) {
                                _updateOrderStatus(newValue);
                              }
                            },
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Order Info
            Text(
              'Mã đơn: #${widget.orderId}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(isDelivery ? Icons.delivery_dining : Icons.store),
                const SizedBox(width: 8),
                Text(
                  isDelivery ? 'Giao hàng tận nơi' : 'Khách tự đến lấy',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Ghi chú: $note',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 16),

            // Payment Info
            Row(
              children: [
                const Icon(Icons.payment),
                const SizedBox(width: 8),
                Text(
                  'Thanh toán: ${widget.orderData['paymentMethod'] ?? 'COD'}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  (widget.orderData['isPaid'] ?? false)
                      ? Icons.check_circle
                      : Icons.pending,
                  color: (widget.orderData['isPaid'] ?? false)
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  (widget.orderData['isPaid'] ?? false)
                      ? 'Đã thanh toán'
                      : 'Chưa thanh toán',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: (widget.orderData['isPaid'] ?? false)
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Delivery Address
            if (deliveryAddress != null) ...[
              const Text(
                'Địa chỉ giao hàng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(deliveryAddress['fullAddress'] ?? ''),
              ),
              const SizedBox(height: 24),
            ],

            // Items
            const Text(
              'Danh sách sản phẩm',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            image: item['imageUrl'] != null
                                ? DecorationImage(
                                    image:
                                        item['imageUrl'].toString().startsWith(
                                          'http',
                                        )
                                        ? NetworkImage(item['imageUrl'])
                                              as ImageProvider
                                        : AssetImage(item['imageUrl']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: item['imageUrl'] == null
                              ? const Icon(Icons.coffee)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['productName'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Size: ${item['size']} | Ice: ${item['ice']} | Sugar: ${item['sugar']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'x${item['quantity']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatCurrency(
                            (item['price'] ?? 0) * (item['quantity'] ?? 1),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Total Block
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppThemes.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng thanh toán',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    formatCurrency(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: AppThemes.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
