import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/page_routes.dart';
import '../widgets/screen_background.dart';
import 'city_screen.dart';
import 'welcome_screen.dart';

/// Hosts the bottom-nav tabs and gates the optional admin entry behind role.
/// One source of truth for the current user's profile data; all tabs read
/// from the [HomeData] passed down.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late final Future<HomeData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<HomeData> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('not authenticated');
    final firestore = FirebaseFirestore.instance;
    final userSnap = await firestore.collection('users').doc(uid).get();
    if (!userSnap.exists) {
      throw StateError('user document missing for uid $uid');
    }
    final user = userSnap.data()!;
    final familyId = user['familyId'] as String;
    final familySnap =
        await firestore.collection('families').doc(familyId).get();
    final family = familySnap.data() ?? const {};
    final avatarMap =
        (user['avatar'] as Map?)?.cast<String, dynamic>() ?? const {};
    return HomeData(
      uid: uid,
      role: (user['role'] as String?) ?? 'kid',
      displayName: (user['displayName'] as String?) ?? '',
      avatar: (avatarMap['value'] as String?) ?? '👤',
      familyName: (family['name'] as String?) ?? 'משפחה',
      familyId: familyId,
    );
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      FadeUpRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppPalette.bgDeep,
        body: ScreenBackground(
          // No SafeArea here: the Little City draws full-bleed (under the
          // notch/edges). The city screen applies safe-area insets to its own
          // floating chrome instead.
          child: FutureBuilder<HomeData>(
            future: _dataFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppPalette.gold),
                );
              }
              if (snap.hasError) {
                return SafeArea(
                  child: _ErrorView(
                    message: 'שגיאה: ${snap.error}',
                    onSignOut: _signOut,
                  ),
                );
              }
              final data = snap.data!;
              // The Little City is the game-first home shell: it fills the
              // screen and reaches the other sections (tasks/shop/family/
              // profile) via its own floating chrome — no bottom nav bar.
              return CityScreen(data: data, onSignOut: _signOut);
            },
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onSignOut});
  final String message;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: bodyFont(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onSignOut,
            child: Text(
              'התנתק וחזור',
              style: bodyFont(color: AppPalette.gold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile data shared with all tabs.
class HomeData {
  const HomeData({
    required this.uid,
    required this.role,
    required this.displayName,
    required this.avatar,
    required this.familyName,
    required this.familyId,
  });
  final String uid;
  final String role;
  final String displayName;
  final String avatar;
  final String familyName;
  final String familyId;
}
