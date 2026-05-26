import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/building_catalog.dart';
import '../game/city_game.dart';
import '../game/economy_config.dart';
import '../models/city.dart';
import '../models/quest_instance.dart';
import '../services/city_service.dart';
import '../services/quest_instance_service.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
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
  bool _trayOpen = false; // building menu visible
  String? _armedType; // a type armed for placement (tap a tile to place)
  ({int x, int y})? _selectedCell; // a building selected for upgrade
  ({int x, int y})? _movingCell; // a building being relocated
  bool _dragging = false; // dragging the selected building to a new tile
  bool _dailyAvailable = false; // daily reward ready to claim
  int _lastCityLevel = -1;
  int? _levelUpBanner;
  Timer? _levelUpTimer;

  bool get _isAdmin => widget.data.role == 'admin';

  @override
  void initState() {
    super.initState();
    _game = CityGame(onCellTapped: _onCellTapped);
    _citySub = _cityService.watchCity(widget.data.uid).listen((city) {
      _city = city;
      _game.setBuildings(city.buildings);
      // If the selected building vanished (e.g. data change), clear it.
      if (_selectedCell != null &&
          !city.isOccupied(_selectedCell!.x, _selectedCell!.y)) {
        _selectedCell = null;
        _game.setSelected(null, null);
      }
      // Celebrate when the city reaches a new level.
      final level = city.cityLevel;
      if (_lastCityLevel >= 0 && level > _lastCityLevel) {
        _levelUpBanner = level;
        _game.burstConfetti();
        _levelUpTimer?.cancel();
        _levelUpTimer = Timer(const Duration(milliseconds: 2600), () {
          if (mounted) setState(() => _levelUpBanner = null);
        });
      }
      _lastCityLevel = level;
      if (mounted) setState(() {});
    });
    // Surface the daily reward if it hasn't been claimed today.
    _cityService.isDailyRewardAvailable(widget.data.uid).then((available) {
      if (available && mounted) setState(() => _dailyAvailable = true);
    });
  }

  Future<void> _claimDaily() async {
    try {
      final amount = await _cityService.claimDailyReward(widget.data.uid);
      if (!mounted) return;
      setState(() => _dailyAvailable = false);
      if (amount > 0) {
        _game.burstConfetti();
        HapticFeedback.mediumImpact();
        _toast('🎁 בונוס יומי · +$amount אסימונים');
      }
    } catch (_) {
      if (mounted) setState(() => _dailyAvailable = false);
    }
  }

  @override
  void dispose() {
    _levelUpTimer?.cancel();
    _citySub?.cancel();
    super.dispose();
  }

  void _onCellTapped(int gx, int gy) {
    // Relocation mode: the next empty tile becomes the new home.
    if (_movingCell != null) {
      if (_city.isOccupied(gx, gy)) {
        _toast('המשבצת תפוסה');
      } else {
        final from = _movingCell!;
        _movingCell = null;
        _game.setBuildMode(false);
        setState(() {});
        _move(from.x, from.y, gx, gy);
      }
      return;
    }
    if (_city.isOccupied(gx, gy)) {
      // Tapping a building selects it (toggle) — the upgrade popup appears
      // above it. Selecting clears any armed placement.
      final already = _selectedCell?.x == gx && _selectedCell?.y == gy;
      setState(() {
        _selectedCell = already ? null : (x: gx, y: gy);
        _armedType = null;
        _game.setBuildMode(false);
        _game.setSelected(_selectedCell?.x, _selectedCell?.y);
      });
      return;
    }
    // Empty tile: place the armed building, or clear the selection.
    if (_armedType != null) {
      _place(_armedType!, gx, gy);
    } else if (_selectedCell != null) {
      setState(() {
        _selectedCell = null;
        _game.setSelected(null, null);
      });
    }
  }

  Future<void> _place(String typeId, int gx, int gy) async {
    try {
      final result = await _cityService.placeBuilding(
          uid: widget.data.uid, typeId: typeId, gridX: gx, gridY: gy);
      HapticFeedback.mediumImpact();
      _game.celebrate(gx, gy,
          xpGained: result.xpGained, bonusTokens: result.bonusTokens);
    } on StateError catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('שגיאה: $e');
    }
  }

  void _startMove() {
    final cell = _selectedCell;
    if (cell == null) return;
    setState(() {
      _movingCell = cell;
      _selectedCell = null;
      _game.setSelected(null, null);
      _game.setBuildMode(true); // highlight empty tiles to drop onto
    });
  }

  Future<void> _move(int fromX, int fromY, int toX, int toY) async {
    try {
      await _cityService.moveBuilding(
          uid: widget.data.uid, fromX: fromX, fromY: fromY, toX: toX, toY: toY);
      HapticFeedback.selectionClick();
      _game.celebrate(toX, toY, xpGained: 0);
    } on StateError catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('שגיאה: $e');
    }
  }

  Future<void> _removeSelected() async {
    final cell = _selectedCell;
    if (cell == null) return;
    final idx = _city.indexAt(cell.x, cell.y);
    if (idx < 0) return;
    final b = _city.buildings[idx];
    final type = buildingTypeById(b.typeId);
    final refund = type == null ? 0 : type.valueAtLevel(b.level) ~/ 2;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppPalette.surface,
          title: Text('להסיר את המבנה?', style: displayFont(size: 18)),
          content: Text('יוחזרו לך $refund אסימונים.',
              style: bodyFont(size: 15, color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('ביטול', style: bodyFont(color: Colors.white60)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('הסרה', style: bodyFont(color: AppPalette.pink)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final refunded = await _cityService.removeBuilding(
          uid: widget.data.uid, gridX: cell.x, gridY: cell.y);
      HapticFeedback.mediumImpact();
      _deselect();
      _toast('המבנה הוסר · +$refunded אסימונים');
    } on StateError catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('שגיאה: $e');
    }
  }

  Future<void> _upgradeSelected() async {
    final cell = _selectedCell;
    if (cell == null) return;
    try {
      final result = await _cityService.upgradeBuilding(
          uid: widget.data.uid, gridX: cell.x, gridY: cell.y);
      HapticFeedback.mediumImpact();
      _game.celebrate(cell.x, cell.y,
          xpGained: result.xpGained, bonusTokens: result.bonusTokens);
    } on StateError catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('שגיאה: $e');
    }
  }

  void _toggleTray() {
    setState(() {
      if (_trayOpen || _armedType != null || _movingCell != null) {
        // Cancel everything (placement / moving / tray).
        _trayOpen = false;
        _armedType = null;
        _movingCell = null;
        _game.setBuildMode(false);
      } else {
        _trayOpen = true;
        _selectedCell = null;
        _game.setSelected(null, null);
      }
    });
  }

  void _armType(String id) {
    setState(() {
      _selectedType = id;
      _armedType = id;
      _trayOpen = false;
      _selectedCell = null;
      _game.setSelected(null, null);
      _game.setBuildMode(true);
    });
  }

  void _closeTray() {
    if (!_trayOpen) return;
    setState(() => _trayOpen = false);
  }

  void _deselect() {
    if (_selectedCell == null) return;
    setState(() {
      _selectedCell = null;
      _game.setSelected(null, null);
    });
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

  /// Tapping the city card opens a stats panel (with a rename action).
  void _showCityPanel() {
    final buildings = _city.buildings;
    final counts = <String, int>{};
    for (final b in buildings) {
      counts[b.typeId] = (counts[b.typeId] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      isScrollControlled: true, // landscape is short — allow a tall, scrollable sheet
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.86),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_city.displayName,
                          style: displayFont(size: 22, weight: FontWeight.w900)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          color: AppPalette.gold),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _renameCity();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat('רמה', '${_city.cityLevel}', AppPalette.gold),
                    _stat('ערך העיר', '${_city.cityValue}', AppPalette.green),
                    _stat('מבנים', '${buildings.length}', AppPalette.sky),
                  ],
                ),
                if (entries.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('המבנים שלך',
                      style: bodyFont(size: 13, color: Colors.white60)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in entries)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${buildingTypeById(e.key)?.icon ?? '🏠'} '
                            '${buildingTypeById(e.key)?.displayName ?? e.key} '
                            '×${e.value}',
                            style: bodyFont(size: 13),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value,
                style: displayFont(
                    size: 22, weight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: bodyFont(size: 11, color: Colors.white60)),
          ],
        ),
      ),
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

        // While a building is selected: a tap anywhere deselects it, and a
        // drag that starts on the selected building relocates it (dropping on
        // an empty tile). The upgrade popup sits above and keeps its taps.
        if (_selectedCell != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _deselect,
              onPanStart: (d) {
                final t = _game.tileAt(d.localPosition.dx, d.localPosition.dy);
                final sel = _selectedCell;
                if (t != null && sel != null && t.x == sel.x && t.y == sel.y) {
                  setState(() => _dragging = true);
                  _game.beginDrag();
                  _game.updateDrag(d.localPosition.dx, d.localPosition.dy);
                }
              },
              onPanUpdate: (d) {
                if (_dragging) {
                  _game.updateDrag(d.localPosition.dx, d.localPosition.dy);
                }
              },
              onPanEnd: (_) {
                if (!_dragging) return;
                final from = _selectedCell;
                final target = _game.endDrag();
                final valid = from != null &&
                    target != null &&
                    (target.x != from.x || target.y != from.y) &&
                    !_city.isOccupied(target.x, target.y);
                setState(() {
                  _dragging = false;
                  if (valid) {
                    _selectedCell = null;
                    _game.setSelected(null, null);
                  }
                });
                if (valid) _move(from.x, from.y, target.x, target.y);
              },
            ),
          ),

        // Upgrade popup is in the OUTER stack so its position matches the
        // game's (untransformed, full-screen) coordinates exactly. Hidden
        // while dragging the building.
        if (_selectedCell != null && !_dragging) _upgradePopup(context),
      ],
    );
  }

  /// A small popup above the selected building: its level + an upgrade button.
  Widget _upgradePopup(BuildContext context) {
    final cell = _selectedCell!;
    final idx = _city.indexAt(cell.x, cell.y);
    if (idx < 0) return const SizedBox.shrink();
    final b = _city.buildings[idx];
    final type = buildingTypeById(b.typeId);
    final nextCost = type?.tokenCostForLevel(b.level + 1) ?? 0;
    final anchor = _game.anchorAbove(cell.x, cell.y);
    const w = 240.0;
    return Positioned(
      left: anchor.dx - w / 2,
      top: anchor.dy - 78,
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            // absorb taps on the card so only the button acts (and the
            // surrounding barrier handles deselect)
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _Chrome.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${type?.displayName ?? ''} · רמה ${b.level}',
                    style: displayFont(
                        size: 13,
                        weight: FontWeight.w900,
                        color: _Chrome.ink)),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _upgradeSelected,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppPalette.gold, AppPalette.goldDeep]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('שדרוג',
                                style: displayFont(
                                    size: 13,
                                    weight: FontWeight.w900,
                                    color: Colors.white)),
                            const SizedBox(width: 6),
                            const Icon(Icons.bolt_rounded,
                                size: 14, color: Colors.white),
                            Text('$nextCost',
                                style: displayFont(
                                    size: 13,
                                    weight: FontWeight.w900,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _startMove,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EBF6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.open_with_rounded,
                            size: 18, color: _Chrome.avatar),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _removeSelected,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE7EC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppPalette.pink),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
          // little pointer
          CustomPaint(size: const Size(16, 8), painter: _DownTriangle()),
        ],
      ),
    );
  }

  Widget _chrome(BuildContext context) {
    return Stack(
      children: [
        // Level-up celebration banner.
        if (_levelUpBanner != null)
          Positioned(
            left: 0,
            right: 0,
            top: 70,
            child: IgnorePointer(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppPalette.gold, AppPalette.goldDeep]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: AppPalette.goldDeep.withValues(alpha: 0.5),
                            blurRadius: 18,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🎉 רמה $_levelUpBanner!',
                            style: displayFont(
                                size: 20,
                                weight: FontWeight.w900,
                                color: Colors.white)),
                        Text('העיר שלך גדלה!',
                            style: bodyFont(
                                size: 12, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Empty-state onboarding: nudge brand-new cities toward building.
        if (_city.buildings.isEmpty && _armedType == null && !_trayOpen)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔨', style: TextStyle(fontSize: 34)),
                      const SizedBox(height: 8),
                      Text('בנו את העיר הראשונה שלכם!',
                          style: displayFont(
                              size: 17, weight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('הקישו על «בנייה» ואז על משבצת ריקה',
                          style: bodyFont(size: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Daily reward: a tappable banner to collect once per day.
        if (_dailyAvailable && _movingCell == null && _selectedCell == null)
          Positioned(
            left: 0,
            right: 0,
            top: 70,
            child: Center(
              child: ScaleTap(
                onTap: _claimDaily,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppPalette.green, AppPalette.sky]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: AppPalette.green.withValues(alpha: 0.5),
                          blurRadius: 14,
                          offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎁', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text('בונוס יומי! הקישו לאיסוף',
                          style: displayFont(
                              size: 14,
                              weight: FontWeight.w900,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Moving-mode hint.
        if (_movingCell != null)
          Positioned(
            left: 0,
            right: 0,
            top: 70,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('בחרו משבצת ריקה להעברת המבנה',
                      style: bodyFont(
                          size: 13, weight: FontWeight.w700)),
                ),
              ),
            ),
          ),

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
            onTap: _showCityPanel,
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

        // Dismiss barrier: while the tray is open, a tap anywhere closes it
        // (the tray + build button below sit above this and keep their taps).
        if (_trayOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeTray,
            ),
          ),

        // Placement indicator: what you're about to place.
        if (_armedType != null && !_trayOpen)
          Positioned(
            left: 14,
            bottom: 90,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(buildingTypeById(_armedType!)?.icon ?? '🏠',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                        'מציב: ${buildingTypeById(_armedType!)?.displayName ?? ''}',
                        style: bodyFont(
                            size: 12,
                            weight: FontWeight.w800,
                            color: _Chrome.ink)),
                  ],
                ),
              ),
            ),
          ),

        // Bottom-left: build button (hammer to open, ✕ to cancel).
        Positioned(
          left: 14,
          bottom: _trayOpen ? 132 : 18,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            offset: Offset.zero,
            child: _BuildButton(
              active: _trayOpen || _armedType != null || _movingCell != null,
              onTap: _toggleTray,
            ),
          ),
        ),

        // Bottom: building tray (slides up when open).
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
            child: _trayOpen
                ? _BuildTray(
                    key: const ValueKey('tray'),
                    selected: _selectedType,
                    onSelect: _armType,
                  )
                : const SizedBox.shrink(key: ValueKey('no-tray')),
          ),
        ),
      ],
    );
  }
}

/// Small downward triangle pointer under the upgrade popup.
class _DownTriangle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = _Chrome.card);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
                    formatCount(v.round()),
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
