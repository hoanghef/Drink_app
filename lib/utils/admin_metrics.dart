class AdminMetrics {
  final int totalOrders;
  final int today;
  final int thisMonth;
  final Map<String, int> byStatus;
  final int collected;
  final int orderValue;
  final int unknownPayment;

  const AdminMetrics({
    required this.totalOrders,
    required this.today,
    required this.thisMonth,
    required this.byStatus,
    required this.collected,
    required this.orderValue,
    required this.unknownPayment,
  });

  static AdminMetrics fromOrders(
    List<Map<String, dynamic>> orders,
    DateTime now,
  ) {
    var today = 0, month = 0, collected = 0, value = 0, unknown = 0;
    final statuses = <String, int>{};
    for (final order in orders) {
      final rawStatus = order['orderStatus'] ?? order['status'] ?? 'Không rõ';
      final status =
          {
            'processing': 'Chờ xác nhận',
            'completed': 'Hoàn thành',
            'cancelled': 'Hủy',
          }[rawStatus] ??
          rawStatus.toString();
      statuses[status] = (statuses[status] ?? 0) + 1;
      final created = order['createdAt'];
      if (created is DateTime) {
        if (created.year == now.year && created.month == now.month) {
          month++;
          if (created.day == now.day) today++;
        }
      }
      if (status == 'Hủy') continue;
      final amount = order['amount'];
      if (amount is num && amount >= 0 && amount.isFinite) {
        value += amount.toInt();
        if (order['paymentStatus'] == 'paid') collected += amount.toInt();
        if (order['paymentStatus'] == null) unknown++;
      }
    }
    return AdminMetrics(
      totalOrders: orders.length,
      today: today,
      thisMonth: month,
      byStatus: statuses,
      collected: collected,
      orderValue: value,
      unknownPayment: unknown,
    );
  }
}
