import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/building_catalog.dart';
import '../game/city_game.dart';
import '../models/city.dart';
import '../services/city_service.dart';
import '../theme/app_theme.dart';
import 'cash_out_sheet.dart';
import 'main_navigation.dart';

/// The Little City game screen: a Flame isometric city you build by spending
/// tokens (earned from chores). Tapping an empty tile places the selected
/// building; tapping an existing one upgrades it. Both spend tokens and earn
/// XP via [CityService].
class CityScreen extends StatefulWidget {
  const CityScreen({super.key, required this.data});

  final HomeData data;

  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  final CityService _cityService = CityService();
  late final CityGame _game;
  StreamSubscription<City>? _citySub;
  City _city = const City(uid: '', buildings: []);
  String _selectedType = 'house';

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
      if (isUpgrade) {
        await _cityService.upgradeBuilding(
            uid: widget.data.uid, gridX: gx, gridY: gy);
      } else {
        await _cityService.placeBuilding(
            uid: widget.data.uid, typeId: _selectedType, gridX: gx, gridY: gy);
      }
      _toast(isUpgrade ? '⬆️ שודרג!' : '🏗️ נבנה!');
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
        content: Text(msg, textAlign: TextAlign.right),
        backgroundColor: AppPalette.surface,
        duration: const Duration(milliseconds: 1600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: GameWidget(game: _game)),
        Positioned(
          top: 10,
          left: 12,
          right: 12,
          child: _Hud(
            uid: widget.data.uid,
            familyId: widget.data.familyId,
            cityLevel: _city.cityLevel,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: _BuildMenu(
            selected: _selectedType,
            onSelect: (id) => setState(() => _selectedType = id),
          ),
        ),
      ],
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.uid,
    required this.familyId,
    required this.cityLevel,
  });

  final String uid;
  final String familyId;
  final int cityLevel;

  @override
  Widget build(BuildContext context) {
    final walletStream = FirebaseFirestore.instance
        .collection('wallets')
        .doc(uid)
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: walletStream,
      builder: (context, snap) {
        final w = snap.data?.data() ?? const {};
        final tokens = (w['tokens'] as num?)?.toInt() ?? 0;
        final xp = (w['points'] as num?)?.toInt() ?? 0;
        return Row(
          children: [
            _chip('⚡', '$tokens', 'אסימונים', AppPalette.gold),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () =>
                  showCashOutSheet(context, uid: uid, familyId: familyId),
              child: _chip('⭐', '$xp', 'נקודות ↓', AppPalette.pink),
            ),
            const Spacer(),
            _chip('🏙️', 'רמה $cityLevel', '', Colors.white),
          ],
        );
      },
    );
  }

  Widget _chip(String icon, String value, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(value,
              style: displayFont(size: 15, weight: FontWeight.w900)),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label,
                style: bodyFont(
                    size: 10, color: Colors.white.withValues(alpha: 0.6))),
          ],
        ],
      ),
    );
  }
}

class _BuildMenu extends StatelessWidget {
  const _BuildMenu({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: kBuildingCatalog.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final b = kBuildingCatalog[i];
          final isSel = b.id == selected;
          return GestureDetector(
            onTap: () => onSelect(b.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSel
                    ? AppPalette.gold.withValues(alpha: 0.22)
                    : AppPalette.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSel
                      ? AppPalette.gold
                      : Colors.white.withValues(alpha: 0.08),
                  width: isSel ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(b.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(b.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodyFont(
                          size: 9.5,
                          color: Colors.white.withValues(alpha: 0.8))),
                  Text('⚡${b.baseTokenCost}',
                      style: displayFont(
                          size: 11, weight: FontWeight.w800)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
