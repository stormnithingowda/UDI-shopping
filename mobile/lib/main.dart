import 'package:flutter/material.dart';
import 'api_service.dart';
import 'checkout_page.dart';
import 'orders_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UdiShoppingApp());
}

class UdiShoppingApp extends StatelessWidget {
  const UdiShoppingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UDI Shopping',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF26734D)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8F5),
          foregroundColor: Color(0xFF183D2B),
          centerTitle: false,
        ),
      ),
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<void> _restore = ApiService.instance.restoreSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return ApiService.instance.isSignedIn ? const StorePage() : const AuthPage();
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_register) {
        await ApiService.instance.register(_username.text.trim(), _email.text.trim(), _password.text);
      } else {
        await ApiService.instance.login(_username.text.trim(), _password.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StorePage()));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 62, color: Color(0xFF26734D)),
                    const SizedBox(height: 12),
                    const Text('UDI Shopping', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_register ? 'Create your customer account' : 'Sign in to continue',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
                    ),
                    if (_register) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _busy ? const CircularProgressIndicator() : Text(_register ? 'Create account' : 'Login'),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() { _register = !_register; _error = null; }),
                      child: Text(_register ? 'Already have an account? Login' : 'New to UDI? Create account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StorePage extends StatefulWidget {
  const StorePage({super.key});
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  int _tab = 0;
  int _refresh = 0;

  Future<void> _logout() async {
    await ApiService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()), (_) => false,
    );
  }

  void _changed() => setState(() => _refresh++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UDI Shopping', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _logout, tooltip: 'Logout', icon: const Icon(Icons.logout))],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          ProductPage(key: ValueKey('products$_refresh'), onCartChanged: _changed),
          CartPage(key: ValueKey('cart$_refresh'), onChanged: _changed),
          WishlistPage(key: ValueKey('wishlist$_refresh'), onChanged: _changed),
          OrdersPage(key: ValueKey('orders$_refresh')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Shop'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Cart'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
        ],
      ),
    );
  }
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.onCartChanged});
  final VoidCallback onCartChanged;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late Future<List<Map<String, dynamic>>> _products = ApiService.instance.products();

  Future<void> _save(Map<String, dynamic> product) async {
    try {
      await ApiService.instance.addToWishlist(product['id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to wishlist')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _add(Map<String, dynamic> product) async {
    try {
      await ApiService.instance.addToCart(product['id'] as int, '1');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product['name']} added to cart')));
      widget.onCartChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _products = ApiService.instance.products()),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _products,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Could not load products: ${snapshot.error}'));
          final products = snapshot.data ?? [];
          if (products.isEmpty) return const Center(child: Text('No products are available yet.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Fresh finds for everyday living', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Browse products and add your favourites to the cart.'),
              const SizedBox(height: 16),
              ...products.map((product) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if ((product['image_url'] ?? '').toString().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(product['image_url'], width: 88, height: 88, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder()),
                        )
                      else
                        _placeholder(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(product['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('₹${product['price']} / ${product['unit']}'),
                          Text('Available: ${product['stock_quantity']} ${product['unit']}', style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 8),
                          Align(alignment: Alignment.centerLeft,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              FilledButton.tonal(
                                onPressed: (double.tryParse(product['stock_quantity'].toString()) ?? 0) > 0 ? () => _add(product) : null,
                                child: const Text('Add to cart'),
                              ),
                              IconButton(onPressed: () => _save(product), icon: const Icon(Icons.favorite_border), tooltip: 'Save'),
                            ]),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 88, height: 88, decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
    child: const Icon(Icons.eco_outlined, size: 34, color: Color(0xFF26734D)),
  );
}

class CartPage extends StatefulWidget {
  const CartPage({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late Future<Map<String, dynamic>> _cart = ApiService.instance.cart();

  Future<void> _reload() async => setState(() => _cart = ApiService.instance.cart());

  Future<void> _changeQuantity(int id, double quantity) async {
    if (quantity <= 0) return;
    try {
      await ApiService.instance.updateCartItem(id, quantity.toStringAsFixed(3));
      await _reload();
      widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _remove(int id) async {
    try {
      await ApiService.instance.removeCartItem(id);
      await _reload();
      widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _cart,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Could not load cart: ${snapshot.error}'));
        final data = snapshot.data ?? {};
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        if (items.isEmpty) return const Center(child: Text('Your cart is empty.'));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...items.map((item) {
              final product = Map<String, dynamic>.from(item['product']);
              return Card(
                child: ListTile(
                  title: Text(product['name'].toString()),
                  subtitle: Text('₹${product['price']} × ${item['quantity']} ${product['unit']}'),
                  trailing: Wrap(mainAxisSize: MainAxisSize.min, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _changeQuantity(item['id'] as int, (double.tryParse(item['quantity'].toString()) ?? 1) - 1)),
                    Text(item['quantity'].toString()),
                    IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _changeQuantity(item['id'] as int, (double.tryParse(item['quantity'].toString()) ?? 0) + 1)),
                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _remove(item['id'] as int)),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 12),
            Text('Cart total: ₹${data['total']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CheckoutPage(onOrderCreated: widget.onChanged),
                ),
              ),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Continue to checkout'),
            ),
          ],
        );
      },
    );
  }
}


class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  late Future<List<Map<String, dynamic>>> _items = ApiService.instance.wishlist();

  Future<void> _reload() async => setState(() => _items = ApiService.instance.wishlist());

  Future<void> _move(Map<String, dynamic> item) async {
    try {
      await ApiService.instance.moveWishlistItemToCart(item['id'] as int, '1');
      await ApiService.instance.removeWishlistItem(item['id'] as int);
      await _reload();
      widget.onChanged();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moved to cart')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _remove(int id) async {
    try {
      await ApiService.instance.removeWishlistItem(id);
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Could not load saved products: ${snapshot.error}'));
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const Center(child: Text('Your wishlist is empty.'));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: items.map((item) {
            final product = Map<String, dynamic>.from(item['product']);
            return Card(
              child: ListTile(
                title: Text(product['name'].toString()),
                subtitle: Text('₹${product['price']} / ${product['unit']}'),
                trailing: Wrap(children: [
                  IconButton(tooltip: 'Move to cart', icon: const Icon(Icons.add_shopping_cart), onPressed: () => _move(item)),
                  IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: () => _remove(item['id'] as int)),
                ]),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
