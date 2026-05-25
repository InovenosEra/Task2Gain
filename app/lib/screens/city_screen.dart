import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/building_catalog.dart';
import '../game/city_game.dart';
import '../game/economy_config.dart';
import '../models/city.dart';
import '../models/quest_instance.dart';
import '../services/city_service.dart';
import '../services/quest_instance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/scale_tap.dart';
import '../widgets/screen_background.dart';
import 'admin_screen.dart';
import 'cash_out_sheet.dart';
import 'family_tab.dart';
import 'home_tab.dart';
import 'main_navigation.dart';
import 'profile_tab.dart';
import 'shop_tab.dart';

/// Bright "Little City" chrome colours — the city is its own sunny world, so
/// the HUD here is light/white (the rest of the app stays dark-themed).
class _Chrome {
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2A2D43);
  static const inkSoft = Color(0xFF8A8FA6);
  static const star = Color(0xFFEF476F);
  static const bolt = Color(0xFFF4B942);
  static const level = Color(0xFFFFA94D);
  static const avatar = Color(0xFF7C83FF);
  static const track = Color(0xFFE6E7EE);
}

/// The Little City game screen, Clash-of-Clans style: a full-bleed isometric
/// city with floating chrome — currency chips + settings (top-left), a city
/// card (top-right), an action rail (right), and a build button (bottom-left)
/// that reveals the building tray. Tapping an empty tile places the selected
/// building; tapping an existing one upgrades it. Both spend tokens, earn XP.
class CityScreen extends StatefulWidget {
  const CityScreen({super.key, required this.data, required this.onSignOut});

  final HomeData data;
  final VoidCallback onSignOut;

  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  final CityService _cityService = CityService();
  late final CityGame _game;
  StreamSubscription<City>? _citySub;
  City _city = const City(uid: '', buildings: []);
  String _selectedType = 'house';
  bool _buildMode = false;

  bool get _isAdmin => widget.data.role == 'admin';

  @override
  void initState() {
    super.initState();
    _game = CityGame(onCellTapped: _onCellTapped);
    _citySub = _cityService.watchCity(widget.data.uid).listen((city) {
      _city = city;
      _game.setBuildings(city.buildings);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _citySub?.cancel();
    super.dispose();
  }

  Future<void> _onCellTapped(int gx, int gy) async {
    final isUpgrade = _city.isOccupied(gx, gy);
    try {
      final result = isUpgrade
          ? await _cityService.upgradeBuilding(
              uid: widget.data.uid, gridX: gx, gridY: gy)
          : await _cityService.placeBuilding(
              uid: widget.data.uid,
              typeId: _selectedType,
              gridX: gx,
              gridY: gy);
      _game.celebrate(gx, gy,
          xpGained: result.xpGained, bonusTokens: result.bonusTokens);
    } on StateError catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('שגיאה: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: _Chrome.ink,
        duration: const Duration(milliseconds: 1600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openScreen(String title, Widget child) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _SubScreen(title: title, child: child)),
    );
  }

  Future<void> _renameCity() async {
    final controller = TextEditingController(text: _city.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppPalette.surface,
          title: Text('שם העיר', style: displayFont(size: 18)),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 24,
            textAlign: TextAlign.right,
            style: bodyFont(size: 16),
            decoration: InputDecoration(
              hintText: _city.displayName,
              hintStyle: bodyFont(size: 16, color: Colors.white38),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('ביטול', style: bodyFont(color: Colors.white60)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text('שמירה', style: bodyFont(color: AppPalette.gold)),
            ),
          ],
        ),
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await _cityService.renameCity(widget.data.uid, name);
    }
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _sheetItem(ctx, Icons.person_rounded, 'הפרופיל שלי', () {
                Navigator.of(ctx).pop();
                _openScreen('פרופיל',
                    ProfileTab(data: widget.data, onSignOut: widget.onSignOut));
              }),
              if (_isAdmin)
                _sheetItem(ctx, Icons.tune_rounded, 'ניהול המשפחה', () {
                  Navigator.of(ctx).pop();
                  _openScreen(
                      'ניהול', AdminScreen(familyId: widget.data.familyId));
                }),
              _sheetItem(ctx, Icons.logout_rounded, 'התנתקות', () {
                Navigator.of(ctx).pop();
                widget.onSignOut();
              }, danger: true),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetItem(BuildContext ctx, IconData icon, String label,
      VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? AppPalette.pink : Colors.white;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: bodyFont(size: 16, color: color)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-bleed city — draws under the notch and screen edges.
        Positioned.fill(child: GameWidget(game: _game)),

        // All floating chrome is inset to the safe area so nothing hides
        // behind the notch / home indicator.
        Positioned.fill(
          child: SafeArea(
            child: Stack(
              children: [
                _chrome(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chrome(BuildContext context) {
    return Stack(
      children: [
        // Top-left: settings + currency chips.
        Positioned(
          top: 8,
          left: 12,
          child: _TopLeftBar(
            uid: widget.data.uid,
            familyId: widget.data.familyId,
            onSettings: _openSettings,
            onEarn: () =>
                _openScreen('משימות', HomeTab(data: widget.data)),
            onCashOut: () => showCashOutSheet(context,
                uid: widget.data.uid, familyId: widget.data.familyId),
          ),
        ),

        // Top-right: city card (name + progress + level + avatar).
        Positioned(
          top: 8,
          right: 12,
          child: _CityCard(
            name: _city.displayName,
            level: _city.cityLevel,
            valueInLevel: _city.cityValue % kCityValuePerLevel,
            step: kCityValuePerLevel,
            onTap: _renameCity,
          ),
        ),

        // Right rail: tasks / shop / family.
        Positioned(
          right: 10,
          top: 92,
          bottom: 92,
          child: Center(
            child: _ActionRail(
              uid: widget.data.uid,
              onTasks: () =>
                  _openScreen('משימות', HomeTab(data: widget.data)),
              onShop: () => _openScreen('חנות', ShopTab(data: widget.data)),
              onFamily: () =>
                  _openScreen('משפחה', FamilyTab(data: widget.data)),
            ),
          ),
        ),

        // Bottom-left: build button.
        Positioned(
          left: 14,
          bottom: _buildMode ? 132 : 18,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            offset: Offset.zero,
            child: _BuildButton(
              active: _buildMode,
              onTap: () => setState(() {
                _buildMode = !_buildMode;
                _game.setBuildMode(_buildMode);
              }),
            ),
          ),
        ),

        // Bottom: building tray (slides up when build mode is on).
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
            child: _buildMode
                ? _BuildTray(
                    key: const ValueKey('tray'),
                    selected: _selectedType,
                    onSelect: (id) => setState(() => _selectedType = id),
                  )
                : const SizedBox.shrink(key: ValueKey('no-tray')),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Top-left: settings gear + animated currency chips.
// ----------------------------------------------------------------------------

class _TopLeftBar extends StatelessWidget {
  const _TopLeftBar({
    required this.uid,
    required this.familyId,
    required this.onSettings,
    required this.onEarn,
    required this.onCashOut,
  });

  final String uid;
  final String familyId;
  final VoidCallback onSettings;
  final VoidCallback onEarn;
  final VoidCallback onCashOut;

  @override
  Widget build(BuildContext context) {
    final walletStream =
        FirebaseFirestore.instance.collection('wallets').doc(uid).snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: walletStream,
      builder: (context, snap) {
        final w = snap.data?.data() ?? const {};
        final tokens = (w['tokens'] as num?)?.toInt() ?? 0;
        final xp = (w['points'] as num?)?.toInt() ?? 0;
        // Force left-to-right ordering so the cluster reads gear → points →
        // tokens like the design, independent of the ambient RTL direction.
        return Row(
          textDirection: TextDirection.ltr,
          children: [
            _GearButton(onTap: onSettings),
            const SizedBox(width: 8),
            _CurrencyChip(
              value: xp,
              label: 'נקודות',
              icon: Icons.star_rounded,
              iconColor: _Chrome.star,
              onPlus: onEarn,
              onTap: onCashOut,
            ),
            const SizedBox(width: 8),
            _CurrencyChip(
              value: tokens,
              label: 'אסימונים',
              icon: Icons.bolt_rounded,
              iconColor: _Chrome.bolt,
              onPlus: onEarn,
            ),
          ],
        );
      },
    );
  }
}

class _GearButton extends StatelessWidget {
  const _GearButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: _Chrome.card,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.settings_rounded,
            color: _Chrome.inkSoft, size: 24),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onPlus,
    this.onTap,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPlus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // RTL row: first child renders on the right. We want the "+" on the left
    // and the coloured icon badge on the right, number/label between.
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: _Chrome.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      // LTR so the layout is always "+ … number/label … icon" like the design.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          _PlusButton(onTap: onPlus),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: value.toDouble()),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  builder: (_, v, _) => Text(
                    v.round().toString(),
                    style: displayFont(
                        size: 17, weight: FontWeight.w900, color: _Chrome.ink),
                  ),
                ),
                Text(label,
                    style: bodyFont(
                        size: 9, color: _Chrome.inkSoft, height: 1.0)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ],
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppPalette.green, AppPalette.sky],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 19),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Top-right: city card.
// ----------------------------------------------------------------------------

class _CityCard extends StatelessWidget {
  const _CityCard({
    required this.name,
    required this.level,
    required this.valueInLevel,
    required this.step,
    required this.onTap,
  });

  final String name;
  final int level;
  final int valueInLevel;
  final int step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final frac = (valueInLevel / step).clamp(0.0, 1.0);
    return ScaleTap(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _Chrome.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _Chrome.avatar,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_city_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: displayFont(
                        size: 16, weight: FontWeight.w900, color: _Chrome.ink),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _LevelPill(level: level),
                      const SizedBox(width: 6),
                      Expanded(child: _ProgressBar(frac: frac)),
                      const SizedBox(width: 4),
                      Text('$valueInLevel/$step',
                          style: bodyFont(
                              size: 9.5, color: _Chrome.inkSoft, height: 1.0)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});
  final int level;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _Chrome.level,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('רמה $level',
          style: displayFont(
              size: 11, weight: FontWeight.w900, color: Colors.white)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.frac});
  final double frac;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          Container(height: 9, color: _Chrome.track),
          FractionallySizedBox(
            widthFactor: frac,
            child: Container(
              height: 9,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_Chrome.bolt, _Chrome.level],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Right rail: tasks / shop / family.
// ----------------------------------------------------------------------------

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.uid,
    required this.onTasks,
    required this.onShop,
    required this.onFamily,
  });

  final String uid;
  final VoidCallback onTasks;
  final VoidCallback onShop;
  final VoidCallback onFamily;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailButton(
          icon: Icons.assignment_rounded,
          label: 'משימות',
          color: _Chrome.star,
          onTap: onTasks,
          badge: _TasksBadge(uid: uid),
        ),
        const SizedBox(height: 10),
        _RailButton(
          icon: Icons.shopping_cart_rounded,
          label: 'חנות',
          color: AppPalette.green,
          onTap: onShop,
        ),
        const SizedBox(height: 10),
        _RailButton(
          icon: Icons.emoji_events_rounded,
          label: 'משפחה',
          color: _Chrome.level,
          onTap: onFamily,
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _Chrome.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 2),
                Text(label,
                    style: bodyFont(
                        size: 10,
                        weight: FontWeight.w700,
                        color: _Chrome.ink,
                        height: 1.0)),
              ],
            ),
          ),
          if (badge != null) Positioned(top: -5, left: -5, child: badge!),
        ],
      ),
    );
  }
}

class _TasksBadge extends StatelessWidget {
  const _TasksBadge({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QuestInstance>>(
      stream: QuestInstanceService().watchMine(uid),
      builder: (context, snap) {
        final count = (snap.data ?? const [])
            .where((q) => q.status == QuestInstanceStatus.inProgress)
            .length;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: _Chrome.star,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Text('$count',
              style: displayFont(
                  size: 11, weight: FontWeight.w900, color: Colors.white)),
        );
      },
    );
  }
}

// ----------------------------------------------------------------------------
// Bottom-left: build button + building tray.
// ----------------------------------------------------------------------------

class _BuildButton extends StatelessWidget {
  const _BuildButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.gold, AppPalette.goldDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.goldDeep.withValues(alpha: 0.5),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
              border: active
                  ? Border.all(color: Colors.white, width: 2.5)
                  : null,
            ),
            child: Icon(active ? Icons.close_rounded : Icons.handyman_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 4),
          Text('בנייה',
              style: displayFont(
                  size: 12,
                  weight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0)),
        ],
      ),
    );
  }
}

class _BuildTray extends StatelessWidget {
  const _BuildTray({super.key, required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Chrome.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 18, offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('בחרו מבנה ואז הקישו על משבצת',
                style: bodyFont(size: 11, color: _Chrome.inkSoft)),
            const SizedBox(height: 6),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: kBuildingCatalog.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final b = kBuildingCatalog[i];
                  return _TrayItem(
                    type: b,
                    selected: b.id == selected,
                    onTap: () => onSelect(b.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrayItem extends StatelessWidget {
  const _TrayItem({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final BuildingType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF3DA) : const Color(0xFFF4F5FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _Chrome.level : const Color(0xFFE6E7EE),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(type.icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 2),
            Text(type.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bodyFont(
                    size: 10, weight: FontWeight.w700, color: _Chrome.ink)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded, size: 12, color: _Chrome.bolt),
                Text('${type.baseTokenCost}',
                    style: displayFont(
                        size: 12, weight: FontWeight.w900, color: _Chrome.ink)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Sub-screen wrapper for pushed tabs (tasks / shop / family / profile / admin).
// ----------------------------------------------------------------------------

class _SubScreen extends StatelessWidget {
  const _SubScreen({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppPalette.bgDeep,
        body: ScreenBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      ScaleTap(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppPalette.surface.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_right_rounded,
                              color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(title,
                          style: displayFont(size: 20, weight: FontWeight.w900)),
                    ],
                  ),
                ),
                // The tab screens were designed portrait. In the landscape
                // frame, centre them in a phone-width column so they read as
                // intentional instead of stretching edge to edge.
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
