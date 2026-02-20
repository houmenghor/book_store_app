import 'package:flutter/material.dart';

import '../../../../shared/widgets/loading_view.dart';
import '../../state/product_provider.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.productProvider,
    required this.uuid,
  });

  final ProductProvider productProvider;
  final String uuid;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.productProvider.loadDetail(widget.uuid);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.productProvider,
      builder: (_, __) {
        final provider = widget.productProvider;
        final product = provider.selected;

        return Scaffold(
          appBar: AppBar(title: const Text('Product Detail')),
          body: provider.isLoading
              ? const LoadingView(label: 'Loading detail...')
              : product == null
                  ? Center(child: Text(provider.error ?? 'Product not found.'))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView(
                        children: [
                          if (product.image != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                product.image!,
                                height: 220,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            product.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(product.description),
                          const SizedBox(height: 12),
                          Text('Category: ${product.category?.name ?? 'Unknown'}'),
                          Text('Status: ${product.status}'),
                          Text('Stock: ${product.stock}'),
                          Text('Price: \$${product.price.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}
