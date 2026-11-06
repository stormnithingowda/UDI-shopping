import 'package:flutter/material.dart';

import 'api_service.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<List<Map<String, dynamic>>> _orders =
      ApiService.instance.orders();

  Future<void> _refresh() async {
    setState(() => _orders = ApiService.instance.orders());
    await _orders;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load orders: ${snapshot.error}'),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
              ],
            ),
          );
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(child: Text('Your orders will appear here.'));
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Your orders',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...orders.map((order) {
                final id = order['id'] as int;
                final status = _statusLabel(order['status'].toString());
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.shopping_bag_outlined),
                    ),
                    title: Text('Order #$id'),
                    subtitle: Text(
                      '${order['created_at']}\n$status',
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${order['total_amount']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailPage(orderId: id),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Future<Map<String, dynamic>> _order =
      ApiService.instance.orderDetail(widget.orderId);

  Future<void> _refresh() async {
    setState(() => _order = ApiService.instance.orderDetail(widget.orderId));
    await _order;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Refresh order',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _order,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load order: ${snapshot.error}'),
                  OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }
          final order = snapshot.data ?? {};
          final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
          final history =
              List<Map<String, dynamic>>.from(order['status_history'] ?? []);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusLabel(order['status'].toString()),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Placed: ${order['created_at']}'),
                        const SizedBox(height: 12),
                        Text(
                          'Total: ₹${order['total_amount']} ${order['currency']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ...items.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text(item['product_name'].toString()),
                      subtitle: Text(
                        '${item['quantity']} × ₹${item['unit_price']}',
                      ),
                      trailing: Text('₹${item['line_total']}'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order tracking',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No status updates are available yet.'),
                  ),
                ...history.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF26734D),
                    ),
                    title: Text(_statusLabel(entry['status'].toString())),
                    subtitle: Text(
                      '${entry['note']}\n${entry['created_at']}',
                    ),
                    isThreeLine: true,
                  ),
                ),
                if (order['status'] == 'pending_payment')
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Payment is not confirmed yet. Refresh this page after the payment gateway sends its verified update.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _statusLabel(String value) {
  if (value.isEmpty) return 'Unknown';
  return value
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
