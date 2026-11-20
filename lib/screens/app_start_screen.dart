import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'admin/admin_main_screen.dart';
import 'main_screen.dart';
import 'onboarding_screen.dart';

class AppStartScreen extends StatefulWidget {
  const AppStartScreen({super.key});

  @override
  State<AppStartScreen> createState() => _AppStartScreenState();
}

class _AppStartScreenState extends State<AppStartScreen> {
  late Future<Widget> _destination;

  @override
  void initState() {
    super.initState();
    _destination = _resolveDestination();
  }

  Future<Widget> _resolveDestination() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const OnboardingScreen();
    final provider = context.read<UserProvider>();
    await provider.loadUserData(user.uid);
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      return const OnboardingScreen();
    }
    return provider.isAdmin ? const AdminMainScreen() : const MainScreen();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _destination,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không thể xác minh phiên đăng nhập.'),
                TextButton(
                  onPressed: () => setState(() {
                    _destination = _resolveDestination();
                  }),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return snapshot.data!;
    },
  );
}
