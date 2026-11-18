import 'dart:async';
import 'package:coffee_app/providers/favorites_provider.dart';
import 'package:coffee_app/screens/favorite_screen.dart';
import 'package:coffee_app/services/favorites_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeFavoritesStore implements FavoritesStore {
  final data = <String, List<String>>{};
  final delayed = <String, Completer<List<String>>>{};
  final delayedSaves = <String, Completer<void>>{};
  final failLoads = <String>{};
  bool failSave = false;

  @override
  Future<List<String>> load(String uid) async {
    if (failLoads.contains(uid)) throw StateError('Simulated load failure');
    final pending = delayed[uid];
    if (pending != null) return pending.future;
    return List<String>.from(data[uid] ?? []);
  }

  @override
  Future<void> save(String uid, List<String> productIds) async {
    final pending = delayedSaves[uid];
    if (pending != null) await pending.future;
    if (failSave) throw StateError('Simulated Firestore failure');
    data[uid] = List<String>.from(productIds);
  }
}

void main() {
  test('A signs out; B without a document starts and stays empty', () async {
    final store = FakeFavoritesStore()..data['A'] = ['coffee'];
    final favorites = FavoritesProvider(store: store);
    await favorites.loadFavorites('A');
    expect(favorites.favoriteProductIds, ['coffee']);
    favorites.clearFavorites();
    expect(favorites.uid, isNull);
    expect(favorites.favoriteProductIds, isEmpty);
    await favorites.loadFavorites('B');
    expect(favorites.uid, 'B');
    expect(favorites.favoriteProductIds, isEmpty);
    expect(await favorites.toggleFavorite('tea', 'A'), isFalse);
    expect(store.data['B'], isNull);
    favorites.dispose();
  });

  test('A and B favorites are separate, including writes', () async {
    final store = FakeFavoritesStore()
      ..data['A'] = ['coffee']
      ..data['B'] = ['tea'];
    final favorites = FavoritesProvider(store: store);
    await favorites.loadFavorites('A');
    expect(favorites.favoriteProductIds, ['coffee']);
    await favorites.loadFavorites('B');
    expect(favorites.favoriteProductIds, ['tea']);
    expect(await favorites.toggleFavorite('milk', 'B'), isTrue);
    expect(store.data['B'], ['tea', 'milk']);
    expect(store.data['A'], ['coffee']);
    favorites.dispose();
  });

  test('late response for A cannot replace B state', () async {
    final store = FakeFavoritesStore()
      ..data['B'] = ['tea']
      ..delayed['A'] = Completer<List<String>>();
    final favorites = FavoritesProvider(store: store);
    final loadingA = favorites.loadFavorites('A');
    expect(favorites.isLoading, isTrue);
    await favorites.loadFavorites('B');
    expect(favorites.favoriteProductIds, ['tea']);
    store.delayed['A']!.complete(['coffee']);
    await loadingA;
    expect(favorites.uid, 'B');
    expect(favorites.favoriteProductIds, ['tea']);
    expect(favorites.isLoading, isFalse);
    favorites.dispose();
  });

  test(
    'load error shows no prior IDs and retry loads current account',
    () async {
      final store = FakeFavoritesStore()
        ..data['A'] = ['coffee']
        ..data['B'] = ['tea']
        ..failLoads.add('B');
      final favorites = FavoritesProvider(store: store);
      await favorites.loadFavorites('A');
      await favorites.loadFavorites('B');
      expect(favorites.favoriteProductIds, isEmpty);
      expect(favorites.errorMessage, isNotNull);
      expect(favorites.isLoading, isFalse);
      store.failLoads.clear();
      await favorites.loadFavorites('B');
      expect(favorites.favoriteProductIds, ['tea']);
      expect(favorites.errorMessage, isNull);
      favorites.dispose();
    },
  );

  test('failed save leaves UI state equal to stored data', () async {
    final store = FakeFavoritesStore()..data['A'] = ['coffee'];
    final favorites = FavoritesProvider(store: store);
    await favorites.loadFavorites('A');
    store.failSave = true;
    expect(await favorites.toggleFavorite('tea', 'A'), isFalse);
    expect(favorites.favoriteProductIds, ['coffee']);
    expect(store.data['A'], ['coffee']);
    expect(favorites.errorMessage, isNotNull);
    store.failSave = false;
    expect(await favorites.toggleFavorite('tea', 'A'), isTrue);
    expect(favorites.favoriteProductIds, store.data['A']);
    favorites.dispose();
  });

  test('in-flight save for A cannot change B memory or document', () async {
    final store = FakeFavoritesStore()
      ..data['A'] = ['coffee']
      ..data['B'] = ['tea']
      ..delayedSaves['A'] = Completer<void>();
    final favorites = FavoritesProvider(store: store);
    await favorites.loadFavorites('A');
    final savingA = favorites.toggleFavorite('milk', 'A');
    expect(favorites.favoriteProductIds, ['coffee']);
    await favorites.loadFavorites('B');
    store.delayedSaves['A']!.complete();
    expect(await savingA, isFalse);
    expect(favorites.favoriteProductIds, ['tea']);
    expect(store.data['B'], ['tea']);
    expect(store.data['A'], ['coffee', 'milk']);
    favorites.dispose();
  });

  testWidgets('favorite screen hides prior data during account load', (
    tester,
  ) async {
    final store = FakeFavoritesStore()
      ..data['A'] = ['coffee']
      ..delayed['B'] = Completer<List<String>>();
    final favorites = FavoritesProvider(store: store);
    await favorites.loadFavorites('A');
    final loadingB = favorites.loadFavorites('B');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: favorites,
        child: const MaterialApp(home: FavoriteScreen()),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(favorites.favoriteProductIds, isEmpty);
    store.delayed['B']!.complete([]);
    await loadingB;
    await tester.pump();
    expect(find.text('Chưa có món yêu thích'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    favorites.dispose();
  });
}
