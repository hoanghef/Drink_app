import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/favorites_provider.dart';
import '../services/product_service.dart';
import '../widgets/product_card.dart';
import 'detail_screen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});
  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  int _retry = 0;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Yêu thích')),
      body: _buildBody(favorites),
    );
  }

  Widget _buildBody(FavoritesProvider favorites) {
    if (favorites.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (favorites.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(favorites.errorMessage!),
            TextButton(
              onPressed: favorites.uid == null
                  ? null
                  : () => favorites.loadFavorites(favorites.uid!),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (favorites.uid == null) {
      return const Center(child: Text('Đăng nhập để xem món yêu thích'));
    }
    final ids = favorites.favoriteProductIds;
    if (ids.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có món yêu thích'),
          ],
        ),
      );
    }
    return StreamBuilder<List<Product>>(
      key: ValueKey(_retry),
      stream: ProductService.getProducts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tải được sản phẩm yêu thích'),
                TextButton(
                  onPressed: () => setState(() => _retry++),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data!
            .where((product) => ids.contains(product.id))
            .toList();
        if (products.isEmpty) {
          return const Center(child: Text('Món yêu thích hiện không được bán'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => ProductCard(
            product: products[index],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScreen(product: products[index]),
              ),
            ),
          ),
        );
      },
    );
  }
}
