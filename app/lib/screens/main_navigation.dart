import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/quest_instance_service.dart';
import '../services/reward_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/page_routes.dart';
import '../widgets/scale_tap.dart';
import '../widgets/screen_background.dart';
import 'admin_screen.dart';
import 'city_screen.dart';
import 'family_tab.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'shop_tab.dart';
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
  int _tabIndex = 0;

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
          child: SafeArea(
            bottom: false,
            child: FutureBuilder<HomeData>(
              future: _dataFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: AppPalette.gold),
                  );
                }
                if (snap.hasError) {
                  return _ErrorView(
                    message: 'שגיאה: ${snap.error}',
                    onSignOut: _signOut,
                  );
                }
                final data = snap.data!;
                return _TabHost(
                  data: data,
                  tabIndex: _tabIndex,
                  onTabChanged: (i) => setState(() => _tabIndex = i),
                  onSignOut: _signOut,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TabHost extends StatelessWidget {
  const _TabHost({
    required this.data,
    required this.tabIndex,
    required this.onTabChanged,
    required this.onSignOut,
  });

  final HomeData data;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onSignOut;

  bool get _isAdmin => data.role == 'admin';

  List<_TabSpec> get _tabs => [
        _TabSpec(
          icon: Icons.location_city_outlined,
          activeIcon: Icons.location_city_rounded,
          label: 'העיר',
          builder: (ctx) => CityScreen(data: data),
        ),
        _TabSpec(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          label: 'משימות',
          builder: (ctx) => HomeTab(data: data),
        ),
        _TabSpec(
          icon: Icons.card_giftcard_outlined,
          activeIcon: Icons.card_giftcard_rounded,
          label: 'חנות',
          builder: (ctx) => ShopTab(data: data),
        ),
        _TabSpec(
          icon: Icons.emoji_events_outlined,
          activeIcon: Icons.emoji_events_rounded,
          label: 'משפחה',
          builder: (ctx) => FamilyTab(data: data),
        ),
        _TabSpec(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'פרופיל',
          builder: (ctx) => ProfileTab(data: data, onSignOut: onSignOut),
        ),
        if (_isAdmin)
          _TabSpec(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'ניהול',
            builder: (ctx) => AdminScreen(familyId: data.familyId),
            isAdminTab: true,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final safeIndex = tabIndex.clamp(0, tabs.length - 1);
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 88),
            child: IndexedStack(
              index: safeIndex,
              sizing: StackFit.expand,
              children: [
                for (final t in tabs) t.builder(context),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _BottomBar(
            tabs: tabs,
            currentIndex: safeIndex,
            onChanged: onTabChanged,
            familyId: data.familyId,
            isAdmin: _isAdmin,
          ),
        ),
      ],
    );
  }
}

class _TabSpec {
  const _TabSpec({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.builder,
    this.isAdminTab = false,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final WidgetBuilder builder;
  final bool isAdminTab;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tabs,
    required this.currentIndex,
    required this.onChanged,
    required this.familyId,
    required this.isAdmin,
  });

  final List<_TabSpec> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final String familyId;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 22,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _NavItem(
                  spec: tabs[i],
                  selected: i == currentIndex,
                  badge: tabs[i].isAdminTab && isAdmin
                      ? _PendingBadge(familyId: familyId)
                      : null,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? AppPalette.gold.withValues(alpha: 0.18)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppPalette.gold.withValues(alpha: 0.6)
                : Colors.transparent,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  selected ? spec.activeIcon : spec.icon,
                  size: selected ? 25 : 23,
                  color: selected
                      ? AppPalette.gold
                      : Colors.white.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 4),
                Text(
                  spec.label,
                  textAlign: TextAlign.center,
                  style: bodyFont(
                    size: 10,
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
                    weight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -2,
                left: -4,
                child: badge!,
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context) {
    final qStream = QuestInstanceService().watchPendingApprovals(familyId);
    final pStream = RewardService().watchPendingPurchases(familyId);
    final tStream = WalletService().watchPendingTransfers(familyId);
    return StreamBuilder(
      stream: qStream,
      builder: (context, qSnap) {
        return StreamBuilder(
          stream: pStream,
          builder: (context, pSnap) {
            return StreamBuilder(
              stream: tStream,
              builder: (context, tSnap) {
                final count = (qSnap.data?.length ?? 0) +
                    (pSnap.data?.length ?? 0) +
                    (tSnap.data?.length ?? 0);
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppPalette.pink,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.pink.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    '$count',
                    style: displayFont(
                      size: 10,
                      weight: FontWeight.w900,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
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
