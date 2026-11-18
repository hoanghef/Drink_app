import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/admin_metrics.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int retry = 0;
  String money(int amount) =>
      '${NumberFormat('#,##0', 'vi_VN').format(amount)}đ';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tổng quan Admin')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey(retry),
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tải được thống kê'),
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
        final orders = snapshot.data!.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          final created = data['createdAt'];
          if (created is Timestamp) data['createdAt'] = created.toDate();
          return data;
        }).toList();
        final metrics = AdminMetrics.fromOrders(orders, DateTime.now());
        if (orders.isEmpty) {
          return const Center(child: Text('Chưa có đơn hàng để thống kê'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              'Tiền đã thu (đơn chưa hủy)',
              money(metrics.collected),
              'Chỉ gồm thanh toán online đã xác nhận và COD đã ghi nhận',
            ),
            _card(
              'Giá trị đơn chưa hủy',
              money(metrics.orderValue),
              'Bao gồm cả đơn chưa thu tiền',
            ),
            if (metrics.unknownPayment > 0)
              Text(
                '${metrics.unknownPayment} đơn cũ thiếu paymentStatus; chưa tính là đã thu.',
              ),
            const SizedBox(height: 16),
            _card(
              'Số đơn hôm nay',
              '${metrics.today}',
              'Theo thời điểm tạo đơn',
            ),
            _card(
              'Số đơn tháng này',
              '${metrics.thisMonth}',
              'Theo thời điểm tạo đơn',
            ),
            _card('Tổng số đơn', '${metrics.totalOrders}', 'Mọi trạng thái'),
            const SizedBox(height: 12),
            Text(
              'Theo trạng thái',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final entry in metrics.byStatus.entries)
              ListTile(
                title: Text(entry.key),
                trailing: Text('${entry.value}'),
              ),
          ],
        );
      },
    ),
  );
  Widget _card(String title, String value, String detail) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 26)),
          Text(detail, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    ),
  );
}
