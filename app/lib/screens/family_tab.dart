import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/avatar_picker.dart';
import 'main_navigation.dart';

/// Family tab — leaderboard + family overview. Sorted by level then XP, top 3
/// rendered as a podium, rest as rows.
class FamilyTab extends StatelessWidget {
  const FamilyTab({super.key, required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'משפחת ${data.familyName}',
                style: displayFont(
                    size: 14,
                    color: AppPalette.gold,
                    weight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'לוח המובילים 🏆',
                style: displayFont(size: 26, weight: FontWeight.w900),
              ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore
              .collection('users')
              .where('familyId', isEqualTo: data.familyId)
              .snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child:
                      CircularProgressIndicator(color: AppPalette.gold),
                ),
              );
            }
            final users = userSnap.data?.docs ?? const [];
            if (users.isEmpty) {
              return _empty();
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('wallets')
                  .where('familyId', isEqualTo: data.familyId)
                  .snapshots(),
              builder: (context, walletSnap) {
                final walletByUid = {
                  for (final w in walletSnap.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    w.id: w.data(),
                };
                final entries = users.map((u) {
                  final d = u.data();
                  final wallet = walletByUid[u.id] ?? const {};
                  final avatarMap = (d['avatar'] as Map?)
                          ?.cast<String, dynamic>() ??
                      const {};
                  return _Entry(
                    uid: u.id,
                    name: (d['displayName'] as String?) ?? '',
                    role: (d['role'] as String?) ?? 'kid',
                    avatar: (avatarMap['value'] as String?) ?? '👤',
                    level: (d['level'] as num?)?.toInt() ?? 1,
                    xp: (d['xp'] as num?)?.toInt() ?? 0,
                    lifetimePoints: ((wallet['lifetimeEarned'] as Map?)?[
                                'points'] as num?)
                            ?.toInt() ??
                        0,
                  );
                }).toList();
                entries.sort((a, b) {
                  final byLevel = b.level.compareTo(a.level);
                  if (byLevel != 0) return byLevel;
                  return b.xp.compareTo(a.xp);
                });
                return Column(
                  children: [
                    if (entries.length >= 3)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _Podium(entries: entries),
                      ),
                    if (entries.length >= 3)
                      const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          20, 0, 20, 24),
                      child: Column(
                        children: [
                          for (var i = 0;
                              i < entries.length;
                              i++) ...[
                            _LeaderRow(
                              rank: i + 1,
                              entry: entries[i],
                              isMe: entries[i].uid == data.uid,
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.fromLTRB(40, 32, 40, 80),
        child: Column(
          children: [
            const Text('👥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 14),
            Text(
              'אין עדיין בני משפחה',
              style: displayFont(
                  size: 20, weight: FontWeight.w900),
            ),
          ],
        ),
      );
}

class _Entry {
  const _Entry({
    required this.uid,
    required this.name,
    required this.role,
    required this.avatar,
    required this.level,
    required this.xp,
    required this.lifetimePoints,
  });
  final String uid;
  final String name;
  final String role;
  final String avatar;
  final int level;
  final int xp;
  final int lifetimePoints;
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});
  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF34206B),
            Color(0xFF1A1B3A),
            Color(0xFF3F1A55),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.violet.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
              child: _PodiumStep(
                  entry: entries[1], rank: 2, height: 100)),
          Expanded(
              child: _PodiumStep(
                  entry: entries[0], rank: 1, height: 140)),
          Expanded(
              child: _PodiumStep(
                  entry: entries[2], rank: 3, height: 80)),
        ],
      ),
    );
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({
    required this.entry,
    required this.rank,
    required this.height,
  });
  final _Entry entry;
  final int rank;
  final double height;

  Color get _tone {
    switch (rank) {
      case 1:
        return AppPalette.gold;
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white24;
    }
  }

  String get _medal {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_medal, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 4),
        AvatarBubble(emoji: entry.avatar, size: 54, tone: _tone),
        const SizedBox(height: 4),
        Text(
          entry.name.isEmpty ? '—' : entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: displayFont(size: 13, weight: FontWeight.w800),
        ),
        Text(
          'רמה ${entry.level}',
          style: bodyFont(size: 11, color: Colors.white60),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _tone.withValues(alpha: 0.7),
                _tone.withValues(alpha: 0.15),
              ],
            ),
            border: Border.all(color: _tone.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '$rank',
            style: displayFont(
                size: 28, weight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.entry,
    required this.isMe,
  });
  final int rank;
  final _Entry entry;
  final bool isMe;

  Color get _rankColor {
    switch (rank) {
      case 1:
        return AppPalette.gold;
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white24;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTop = rank <= 3;
    final isParent = entry.role == 'admin';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe
            ? AppPalette.gold.withValues(alpha: 0.18)
            : (isTop
                ? _rankColor.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe
              ? AppPalette.gold
              : (isTop
                  ? _rankColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08)),
          width: isMe || isTop ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: displayFont(
                size: 18,
                weight: FontWeight.w900,
                color: isTop ? _rankColor : Colors.white60,
              ),
            ),
          ),
          const SizedBox(width: 6),
          AvatarBubble(
              emoji: entry.avatar, size: 44, tone: _rankColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.name.isEmpty ? '—' : entry.name,
                      style: displayFont(
                          size: 16, weight: FontWeight.w800),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppPalette.gold,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          'אני',
                          style: displayFont(
                            size: 10,
                            weight: FontWeight.w900,
                            color: AppPalette.bgDeep,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    if (isParent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppPalette.violet.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'הורה',
                          style: bodyFont(
                            size: 10,
                            color: Colors.white,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    _miniTag('LV ${entry.level}', AppPalette.gold),
                    _miniTag(
                        '${entry.xp} XP', AppPalette.violet),
                    _miniTag(
                        '${entry.lifetimePoints} ⭐', AppPalette.green),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: bodyFont(
            size: 11,
            color: Colors.white,
            weight: FontWeight.w800),
      ),
    );
  }
}
