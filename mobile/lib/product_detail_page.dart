import 'package:flutter/material.dart';

import 'api_service.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.slug,
    required this.onCartChanged,
  });

  final String slug;
  final VoidCallback onCartChanged;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Future<Map<String, dynamic>> _product =
      ApiService.instance.productDetail(widget.slug);
  bool _busy = false;

  Future<void> _addToCart(Map<String, dynamic> product) async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.addToCart(product['id'] as int, '1');
      if (!mounted) return;
      widget.onCartChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add product: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(Map<String, dynamic> product) async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.addToWishlist(product['id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to wishlist')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save product: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _product = ApiService.instance.productDetail(widget.slug));
    await _product;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _product,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load product: ${snapshot.error}'),
                  OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }
          final product = snapshot.data ?? {};
          final imageUrl = product['image_url']?.toString() ?? '';
          final stock = double.tryParse(product['stock_quantity'].toString()) ?? 0;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    imageUrl,
                    height: 240,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  ),
                )
              else
                _imagePlaceholder(),
              const SizedBox(height: 20),
              Text(
                product['name'].toString(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${product['price']} / ${product['unit']}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                stock > 0 ? 'In stock: ${product['stock_quantity']} ${product['unit']}' : 'Out of stock',
                style: TextStyle(color: stock > 0 ? Colors.green.shade700 : Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                product['description']?.toString().trim().isNotEmpty == true
                    ? product['description'].toString()
                    : 'No product description has been added yet.',
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 12),
              Text('SKU: ${product['sku']}'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy || stock <= 0 ? null : () => _addToCart(product),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_shopping_cart),
                label: const Text('Add to cart'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _save(product),
                icon: const Icon(Icons.favorite_border),
                label: const Text('Save to wishlist'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Icon(Icons.eco_outlined, size: 64, color: Color(0xFF26734D)),
        ),
      );
}
