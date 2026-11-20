import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_app/models/user_model.dart';
import 'package:coffee_app/providers/user_provider.dart';

void main() {
  test(
    'admin claim is recognized even when profile document is missing',
    () async {
      final provider = UserProvider(
        claimLoader: (_) async => true,
        profileLoader: (_) async => null,
      );
      await provider.loadUserData('admin-uid');
      expect(provider.isAdmin, isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.currentUser, isNull);
      provider.dispose();
    },
  );

  test('a late claim result cannot grant access to another account', () async {
    final oldClaim = Completer<bool>();
    final provider = UserProvider(
      claimLoader: (uid) =>
          uid == 'old' ? oldClaim.future : Future.value(false),
      profileLoader: (uid) async => UserModel(
        uid: uid,
        email: '$uid@example.test',
        name: uid,
        role: 'user',
        createdAt: DateTime(2026),
      ),
    );
    final oldLoad = provider.loadUserData('old');
    await provider.loadUserData('new');
    oldClaim.complete(true);
    await oldLoad;
    expect(provider.isAdmin, isFalse);
    expect(provider.currentUser?.uid, 'new');
    provider.dispose();
  });

  test(
    'claim lookup failure is reported instead of treating admin as user',
    () async {
      final provider = UserProvider(
        claimLoader: (_) async => throw StateError('offline'),
        profileLoader: (_) async => null,
      );
      await expectLater(provider.loadUserData('uid'), throwsStateError);
      expect(provider.isAdmin, isFalse);
      provider.dispose();
    },
  );
}
