import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  bool busy = false;
  bool queryEnabled = false;
  int retry = 0;
  @override
  void initState() {
    super.initState();
    _loadQueryAvailability();
  }

  Future<void> _loadQueryAvailability() async {
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('vnpayAvailability').call();
      if (mounted) {
        setState(() => queryEnabled = result.data['queryEnabled'] == true);
      }
    } catch (_) {
      if (mounted) setState(() => queryEnabled = false);
    }
  }

  static const pending = 'Chờ xác nhận';
  static const preparing = 'Đang pha chế';
  static const delivering = 'Đang giao';
  static const complete = 'Hoàn thành';
  static const cancelled = 'Hủy';
  static const next = <String, List<String>>{
    pending: [preparing, cancelled],
    preparing: [delivering, cancelled],
    delivering: [complete, cancelled],
    complete: [],
    cancelled: [],
  };
  String statusOf(Map<String, dynamic> order) {
    final value = order['orderStatus'] ?? order['status'] ?? pending;
    return {
          'processing': pending,
          'completed': complete,
          'cancelled': cancelled,
        }[value] ??
        value.toString();
  }

  String money(num amount) =>
      '${NumberFormat('#,##0', 'vi_VN').format(amount)}đ';
  Future<void> call(String function, Map<String, dynamic> payload) async {
    setState(() => busy = true);
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable(function).call(payload);
      if (mounted) {
        final pending =
            function == 'reconcileVnpayPayment' &&
            result.data is Map &&
            result.data['paymentStatus'] == 'pending';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pending
                  ? 'VNPay chưa xác nhận thanh toán; đơn vẫn đang chờ'
                  : 'Đã cập nhật đơn hàng',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể cập nhật: $error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey(retry),
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tải được đơn hàng'),
                TextButton(
                  onPressed: () => setState(() => retry++),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.data!.exists) {
          return const Center(child: Text('Đơn hàng không tồn tại'));
        }
        final order = snapshot.data!.data()!;
        final status = statusOf(order);
        final method = order['paymentMethod']?.toString() ?? 'COD';
        final payment =
            order['paymentStatus']?.toString() ??
            (order['isPaid'] == true ? 'paid' : 'unpaid');
        final paid = payment == 'paid';
        final transitions = next[status] ?? [];
        final allowed = method != 'COD' && !paid
            ? payment == 'pending'
                  ? <String>[]
                  : transitions.where((s) => s == cancelled).toList()
            : paid
            ? transitions.where((s) => s != cancelled).toList()
            : transitions;
        final address = order['deliveryAddress'] as Map<String, dynamic>?;
        final items = order['items'] as List<dynamic>? ?? [];
        final createdAt = order['createdAt'];
        final paidAt = order['paidAt'] ?? order['paymentUpdatedAt'];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Đơn #${widget.orderId}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Khách: ${order['userEmail']?.toString().isNotEmpty == true ? order['userEmail'] : order['userId'] ?? 'Không có thông tin'}',
            ),
            if (createdAt is Timestamp)
              Text(
                'Tạo lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate())}',
              ),
            const SizedBox(height: 12),
            Text('Xử lý đơn: $status'),
            if (allowed.isNotEmpty)
              Wrap(
                spacing: 8,
                children: allowed
                    .map(
                      (s) => OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => call('updateOrderStatus', {
                                'orderId': widget.orderId,
                                'status': s,
                              }),
                        child: Text(s),
                      ),
                    )
                    .toList(),
              ),
            const Divider(),
            Text('Phương thức thanh toán: $method'),
            Text(
              'Trạng thái thanh toán: ${switch (payment) {
                'paid' => 'Đã thu',
                'pending' => 'Đang chờ',
                'failed' => 'Thất bại',
                'canceled' => 'Đã hủy',
                _ => 'Chưa thu',
              }}',
            ),
            if (paid && paidAt is Timestamp)
              Text(
                'Thu lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(paidAt.toDate())}',
              ),
            if (order['paidBy'] is String)
              Text('Nhân viên ghi nhận: ${order['paidBy']}'),
            if (method == 'COD' &&
                !paid &&
                [delivering, complete].contains(status))
              FilledButton(
                onPressed: busy
                    ? null
                    : () => call('collectCodPayment', {
                        'orderId': widget.orderId,
                      }),
                child: const Text('Xác nhận đã thu COD'),
              ),
            if (method == 'VNPAY' && payment == 'pending' && queryEnabled)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => call('reconcileVnpayPayment', {
                        'orderId': widget.orderId,
                      }),
                child: const Text('Kiểm tra trạng thái từ VNPay'),
              ),
            if (method == 'VNPAY' && payment == 'pending' && !queryEnabled)
              const Text('Đang chờ IPN; đối soát tự động chưa được cấu hình.'),
            const Divider(),
            Text(
              order['isDelivery'] == true ? 'Giao tận nơi' : 'Khách đến lấy',
            ),
            if (address != null)
              Text(
                'Địa chỉ: ${address['fullAddress'] ?? '${address['detailedAddress'] ?? ''}, ${address['city'] ?? ''}'}',
              ),
            const SizedBox(height: 12),
            Text('Sản phẩm', style: Theme.of(context).textTheme.titleMedium),
            if (items.isEmpty) const Text('Không có dữ liệu sản phẩm'),
            for (final raw in items)
              if (raw is Map)
                ListTile(
                  title: Text(raw['productName']?.toString() ?? 'Sản phẩm'),
                  subtitle: Text(
                    'Size ${raw['size'] ?? '—'} • ${raw['quantity'] ?? 0} × ${money((raw['price'] as num?) ?? 0)}',
                  ),
                  trailing: Text(
                    money(
                      ((raw['price'] as num?) ?? 0) *
                          ((raw['quantity'] as num?) ?? 0),
                    ),
                  ),
                ),
            const Divider(),
            Text(
              'Tổng tiền snapshot: ${money((order['amount'] as num?) ?? 0)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        );
      },
    ),
  );
}
