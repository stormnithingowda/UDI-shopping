import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'api_service.dart';
import 'orders_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.onOrderCreated});

  final VoidCallback onOrderCreated;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late final Razorpay _razorpay;
  late Future<List<Map<String, dynamic>>> _addresses;
  int? _selectedAddressId;
  int? _activeOrderId;
  bool _busy = false;
  String? _paymentMessage;

  @override
  void initState() {
    super.initState();
    _addresses = ApiService.instance.addresses();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _reloadAddresses() async {
    setState(() {
      _addresses = ApiService.instance.addresses();
      _selectedAddressId = null;
    });
  }

  Future<void> _addAddress() async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddressDialog(),
    );
    if (data == null) return;
    try {
      final created = await ApiService.instance.createAddress(data);
      if (!mounted) return;
      setState(() {
        _selectedAddressId = created['id'] as int;
        _addresses = ApiService.instance.addresses();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery address saved')),
      );
    } catch (e) {
      if (mounted) _showMessage('Could not save address: $e');
    }
  }

  Future<void> _editAddress(Map<String, dynamic> address) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddressDialog(initial: address),
    );
    if (data == null) return;
    try {
      await ApiService.instance.updateAddress(address['id'] as int, data);
      if (!mounted) return;
      setState(() => _addresses = ApiService.instance.addresses());
      _showMessage('Address updated');
    } catch (e) {
      if (mounted) _showMessage('Could not update address: $e');
    }
  }

  Future<void> _deleteAddress(Map<String, dynamic> address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete address?'),
        content: const Text('This address will be removed from your saved addresses.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance.deleteAddress(address['id'] as int);
      if (!mounted) return;
      if (_selectedAddressId == address['id']) _selectedAddressId = null;
      setState(() => _addresses = ApiService.instance.addresses());
      _showMessage('Address deleted');
    } catch (e) {
      if (mounted) _showMessage('Could not delete address: $e');
    }
  }

  Future<void> _placeOrder() async {
    final addressId = _selectedAddressId;
    if (addressId == null) {
      _showMessage('Choose a delivery address first.');
      return;
    }
    setState(() {
      _busy = true;
      _paymentMessage = null;
    });
    try {
      final order = await ApiService.instance.checkout(addressId);
      final orderId = order['id'] as int;
      _activeOrderId = orderId;
      widget.onOrderCreated();

      final payment = await ApiService.instance.createPayment(orderId);
      if (!mounted) return;
      final keyId = payment['key_id']?.toString() ?? '';
      final gatewayOrderId = payment['razorpay_order_id']?.toString() ?? '';
      final amount = payment['amount'];
      if (keyId.isEmpty || gatewayOrderId.isEmpty || amount == null) {
        throw Exception('The payment service returned incomplete checkout details.');
      }

      _razorpay.open({
        'key': keyId,
        'amount': amount,
        'currency': payment['currency'] ?? 'INR',
        'order_id': gatewayOrderId,
        'name': 'UDI Shopping',
        'description': 'Order #$orderId',
        'theme': {'color': '#26734D'},
      });
      setState(() => _paymentMessage =
          'Order #$orderId is created. Complete payment in the secure Razorpay checkout.');
    } catch (e) {
      if (mounted) {
        _showMessage('Checkout could not continue: $e');
        setState(() => _paymentMessage =
            _activeOrderId == null
                ? null
                : 'Order #$_activeOrderId is awaiting payment. You can review its status in Orders.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = _activeOrderId;
    final paymentId = response.paymentId;
    final gatewayOrderId = response.orderId;
    final signature = response.signature;
    if (orderId == null || paymentId == null || gatewayOrderId == null || signature == null) {
      _showMessage('Payment response is incomplete. Check the order status before trying again.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ApiService.instance.verifyPayment(orderId, {
        'razorpay_payment_id': paymentId,
        'razorpay_order_id': gatewayOrderId,
        'razorpay_signature': signature,
      });
      if (!mounted) return;
      if (result['status'] == 'confirmed') {
        widget.onOrderCreated();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: orderId)),
        );
      } else {
        setState(() => _paymentMessage =
            'Payment details were received, but the server has not confirmed capture. Check Orders for the verified status.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _paymentMessage =
            'The payment response was received, but server verification is not complete: $e. Check Orders before retrying.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _paymentMessage =
          'Razorpay did not complete the payment (${response.code}): ${response.message ?? 'Please try again'}. The order remains pending until the server receives a verified payment event.';
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showMessage('Selected wallet: ${response.walletName ?? 'External wallet'}');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _addresses,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load addresses: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _reloadAddresses,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          final addresses = snapshot.data ?? [];
          if (_selectedAddressId == null && addresses.isNotEmpty) {
            final preferred = addresses.where((a) => a['is_default'] == true);
            _selectedAddressId =
                (preferred.isNotEmpty ? preferred.first : addresses.first)['id'] as int;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Delivery address',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (addresses.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Add a delivery address to continue.'),
                  ),
                ),
              ...addresses.map((address) {
                final id = address['id'] as int;
                final selected = _selectedAddressId == id;
                return Card(
                  child: Column(
                    children: [
                      RadioListTile<int>(
                        value: id,
                        groupValue: _selectedAddressId,
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _selectedAddressId = value),
                        title: Text(address['full_name'].toString()),
                        subtitle: Text(
                          '${address['address_line1']}, ${address['city']}, ${address['state']} - ${address['postal_code']}\n${address['phone']}',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          children: [
                            TextButton.icon(
                              onPressed: _busy ? null : () => _editAddress(address),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                            ),
                            TextButton.icon(
                              onPressed: _busy ? null : () => _deleteAddress(address),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                      if (selected) const Divider(height: 1),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _addAddress,
                icon: const Icon(Icons.add),
                label: const Text('Add new address'),
              ),
              if (_paymentMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_paymentMessage!),
                ),
                if (_activeOrderId != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailPage(orderId: _activeOrderId!),
                      ),
                    ),
                    child: const Text('View order status'),
                  ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy || _selectedAddressId == null ? null : _placeOrder,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(_busy ? 'Please wait...' : 'Place order and pay securely'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Payments use Razorpay test mode. Your order is confirmed only after the server verifies the payment signature and captured status.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _postalCode;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final address = widget.initial ?? {};
    _name = TextEditingController(text: address['full_name']?.toString() ?? '');
    _phone = TextEditingController(text: address['phone']?.toString() ?? '');
    _line1 = TextEditingController(text: address['address_line1']?.toString() ?? '');
    _line2 = TextEditingController(text: address['address_line2']?.toString() ?? '');
    _city = TextEditingController(text: address['city']?.toString() ?? '');
    _state = TextEditingController(text: address['state']?.toString() ?? '');
    _postalCode = TextEditingController(text: address['postal_code']?.toString() ?? '');
    _isDefault = address['is_default'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Edit delivery address' : 'Add delivery address'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'Full name', validator: _required),
                _field(_phone, 'Phone number', keyboard: TextInputType.phone, validator: _required),
                _field(_line1, 'Address line 1', validator: _required),
                _field(_line2, 'Address line 2'),
                _field(_city, 'City', validator: _required),
                _field(_state, 'State', validator: _required),
                _field(_postalCode, 'Postal code', keyboard: TextInputType.number, validator: _required),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isDefault,
                  onChanged: (value) => setState(() => _isDefault = value ?? false),
                  title: const Text('Set as default address'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'full_name': _name.text.trim(),
              'phone': _phone.text.trim(),
              'address_line1': _line1.text.trim(),
              'address_line2': _line2.text.trim(),
              'city': _city.text.trim(),
              'state': _state.text.trim(),
              'postal_code': _postalCode.text.trim(),
              'is_default': _isDefault,
            });
          },
          child: Text(editing ? 'Save changes' : 'Save address'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
