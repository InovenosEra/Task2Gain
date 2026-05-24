# Task Arcade — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Task2Gain from an XP/level chore-tracker into the "Task Arcade" base loop: remove XP/levels, make earning instant (auto-approve), add a daily-goal ring + streak, and ship a token-funded **Prize Machine** (Wheel + Scratch, never a loss).

**Architecture:** The existing task→points→money engine stays. We delete the XP/level subsystem, replace the `quests.approvalMode` gate so low-stakes tasks credit points instantly (with full celebration) while proof/high-value tasks keep the submit→approve flow. Hitting a per-person daily points goal and streak milestones award **tokens** — a new wallet currency spendable only at the Prize Machine. The Prize Machine's payout logic is pure and config-driven so the "no-loss" invariant is unit-testable; awarding a prize runs in a Firestore transaction that debits one token and credits the reward.

**Tech Stack:** Flutter (Dart 3.12), Firebase (Auth, Cloud Firestore, Storage), `google_fonts`. Tests: `flutter_test`, `integration_test`, and new dev-dep `fake_cloud_firestore` for transaction unit tests.

**Working directory:** All paths are relative to `app/` (the Flutter package root). Run all `flutter`/`dart` commands from `app/`.

**Conventions in this codebase:**
- RTL Hebrew UI. Display numbers/titles use `displayFont(...)`, body text `bodyFont(...)` from `lib/theme/app_theme.dart`.
- Palette in `AppPalette` (`lib/theme/app_theme.dart`): `gold`, `goldDeep`, `pink`, `violet`, `green`, `sky`, `bgDeep`, `surface`, `heroGrad`.
- Tappable surfaces use `ScaleTap(onTap:..., child:...)` from `lib/widgets/scale_tap.dart`.
- Screens pushed via `context.pushFadeUp((_) => Screen())` from `lib/widgets/page_routes.dart`.
- Sub-screens with a back arrow wrap content in `ScreenChrome(title: '...', child: ...)` from `lib/widgets/screen_chrome.dart`.
- `AnimatedIntCounter` (`lib/widgets/animated_counter.dart`) animates number changes.

---

## File Structure

**New files**
- `lib/models/prize.dart` — prize types, default Prize Machine config, and the pure no-loss roll functions for wheel & scratch.
- `lib/services/prize_service.dart` — token-spend + prize-award Firestore transaction; `prizeWins` log; streams.
- `lib/screens/prize_machine_screen.dart` — the Prize Machine hub (token balance, Wheel, Scratch, recent wins).
- `lib/widgets/prize_wheel.dart` — animated spin-the-wheel widget.
- `lib/widgets/scratch_card.dart` — scratch-to-reveal widget.
- `lib/widgets/daily_goal_ring.dart` — progress ring for the daily goal.
- `test/prize_roll_test.dart` — no-loss invariant + weighting tests (pure).
- `test/quest_instance_service_test.dart` — approve/auto-complete transaction tests (fake_cloud_firestore).
- `test/daily_goal_test.dart` — daily-goal & token-award pure-logic tests.

**Modified files**
- `pubspec.yaml` — add `fake_cloud_firestore` dev dep.
- `lib/models/quest.dart` — drop `xpReward`; add `QuestApprovalMode` + `approvalMode`.
- `lib/models/quest_instance.dart` — drop `xpReward`; add `comboMultiplier`, `tokensAwarded`.
- `lib/models/badge.dart` — drop level badges + `BadgeMetrics.level`; add `streak_14`.
- `lib/services/quest_service.dart` — drop `_xpForDifficulty`/`xpReward`; persist `approvalMode`.
- `lib/services/quest_instance_service.dart` — drop xp/level math; `approve()` credits points+streak+tokens+badges and computes daily-goal token; new `completeAuto()` for instant auto-approve.
- `lib/services/wallet_service.dart` — no change needed for tokens (PrizeService owns them); leave as-is unless a helper is referenced (it isn't).
- `lib/services/auth_service.dart` — drop xp/level init; seed `dailyGoal`, `tokens`, `cosmeticsOwned`, family `dailyGoalDefault`.
- `lib/screens/home_tab.dart` — remove `_LevelBadge`/`_XpBar`; add daily-goal ring + streak + tokens chip + Prize Machine entry.
- `lib/screens/quest_detail_screen.dart` — branch auto vs. approval-required; remove XP chip; celebration shows real reward.
- `lib/screens/profile_tab.dart` — remove level card + XP; keep points/money/streak/quests stats.
- `lib/screens/family_tab.dart` — sort by `lifetimePoints`; drop LV/XP tags + "רמה" labels.
- `lib/screens/approvals_screen.dart` — drop XP from the quest approval card.
- `lib/screens/admin_screen.dart` — drop XP from the quest list subtitle.
- `lib/screens/create_quest_screen.dart` — add an approval-mode selector.
- `lib/screens/main_navigation.dart` — add the Prize Machine tab.
- `integration_test/core_flows_test.dart` — add Prize Machine coverage; keep existing assertions green.

**Deleted files**
- `lib/widgets/level_up_overlay.dart`
- `lib/widgets/level_change_listener.dart`

---

## Data model deltas (Firestore)

- `users/{uid}`: **remove** `xp`, `level`, `xpToNextLevel`. **Add** `dailyGoal` (int, default 50). Keep `streak`, `questsCompleted`, `badges`.
- `wallets/{uid}`: keep `points`, `moneyILS`, `lifetimeEarned`. **Add** `tokens` (int, default 0), `cosmeticsOwned` (list, default `[]`).
- `quests/{id}`: **remove** `xpReward`. **Add** `approvalMode` (`auto` | `required`).
- `questInstances/{id}`: **remove** `xpReward`/`xpAwarded`. **Add** `comboMultiplier` (num, default 1.0), `tokensAwarded` (int). Keep `pointsAwarded`.
- `families/{id}.settings`: **add** `dailyGoalDefault` (int, default 50).
- `prizeWins/{id}` (**new**): `userId`, `familyId`, `game` (`wheel`|`scratch`), `rewardType` (`points`|`tokens`|`cosmetic`), `rewardValue` (num|string), `createdAt`.

Orphaned `xp/level/xpToNextLevel` on existing user docs are harmless; new code never reads them.

---

## Task 1: Add fake_cloud_firestore dev dependency

**Files:**
- Modify: `pubspec.yaml:45-49`

- [ ] **Step 1: Add the dev dependency**

In `pubspec.yaml`, under `dev_dependencies:`, add `fake_cloud_firestore` after the `integration_test` block:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  fake_cloud_firestore: ^3.1.0

  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.14.1
```

- [ ] **Step 2: Resolve dependencies**

Run: `flutter pub get`
Expected: `Got dependencies!` (a compatible `fake_cloud_firestore` version resolves; if `^3.1.0` fails to resolve, run `flutter pub add --dev fake_cloud_firestore` and accept the version it picks).

- [ ] **Step 3: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock
git commit -m "test: add fake_cloud_firestore dev dependency"
```

---

## Task 2: Quest model — drop xpReward, add approvalMode

**Files:**
- Modify: `lib/models/quest.dart`

- [ ] **Step 1: Add the `QuestApprovalMode` enum**

At the top of `lib/models/quest.dart`, after the existing `enum QuestRecurrence { once, daily, weekly }` line, add:

```dart
enum QuestApprovalMode { auto, required }
```

- [ ] **Step 2: Replace `xpReward` with `approvalMode` on the `Quest` class**

In the constructor, remove `required this.xpReward,` and add `required this.approvalMode,`.
In the fields, remove `final int xpReward;` and add `final QuestApprovalMode approvalMode;`.
In `Quest.fromDoc`, remove the `xpReward: (d['xpReward'] as num?)?.toInt() ?? 0,` line and add:

```dart
      approvalMode: _parseApprovalMode(d['approvalMode'] as String?),
```

- [ ] **Step 3: Add the parser + label extension**

Add this static method inside the `Quest` class (next to `_parseRecurrence`):

```dart
  static QuestApprovalMode _parseApprovalMode(String? v) {
    switch (v) {
      case 'required':
        return QuestApprovalMode.required;
      default:
        return QuestApprovalMode.auto;
    }
  }
```

And add this extension at the bottom of the file:

```dart
extension QuestApprovalModeLabel on QuestApprovalMode {
  String get label {
    switch (this) {
      case QuestApprovalMode.auto:
        return 'אישור אוטומטי';
      case QuestApprovalMode.required:
        return 'דורש אישור הורה';
    }
  }

  String get serialized => name;
}
```

- [ ] **Step 4: Verify it compiles (will fail elsewhere — that's expected mid-refactor)**

Run: `flutter analyze lib/models/quest.dart`
Expected: No errors in `quest.dart` itself. (Other files still reference `xpReward`; they're fixed in later tasks. Do not commit yet.)

---

## Task 3: QuestInstance model — drop xpReward, add combo/tokens fields

**Files:**
- Modify: `lib/models/quest_instance.dart`

- [ ] **Step 1: Swap the fields**

In the constructor, remove `required this.xpReward,` and add:

```dart
    required this.comboMultiplier,
    required this.tokensAwarded,
```

In the fields, remove `final int xpReward;` and add:

```dart
  final double comboMultiplier;
  final int tokensAwarded;
```

In `QuestInstance.fromDoc`, remove `xpReward: (d['xpReward'] as num?)?.toInt() ?? 0,` and add:

```dart
      comboMultiplier: (d['comboMultiplier'] as num?)?.toDouble() ?? 1.0,
      tokensAwarded: (d['tokensAwarded'] as num?)?.toInt() ?? 0,
```

- [ ] **Step 2: Verify the model file compiles**

Run: `flutter analyze lib/models/quest_instance.dart`
Expected: No errors in this file. (Callers fixed later.)

---

## Task 4: Badge catalog — remove level badges, add streak_14

**Files:**
- Modify: `lib/models/badge.dart`

- [ ] **Step 1: Remove `level` from `BadgeMetrics`**

In the `BadgeMetrics` constructor remove `required this.level,` and remove the field `final int level;`. Final class:

```dart
class BadgeMetrics {
  const BadgeMetrics({
    required this.lifetimePoints,
    required this.currentStreak,
    required this.longestStreak,
    required this.questsCompleted,
  });

  final int lifetimePoints;
  final int currentStreak;
  final int longestStreak;
  final int questsCompleted;
}
```

- [ ] **Step 2: Remove the two level badge entries and add a 14-day streak badge**

In `badgeCatalog`, delete the `level_5` and `level_10` `BadgeDefinition` entries entirely. Add this entry after `streak_7`:

```dart
  BadgeDefinition(
    id: 'streak_14',
    title: 'שבועיים ברצף',
    description: 'רצף של 14 ימים',
    icon: '🔥',
    unlocked: _streak14,
  ),
```

- [ ] **Step 3: Remove the level predicates, add `_streak14`**

Delete `bool _level5(...)` and `bool _level10(...)`. Add:

```dart
bool _streak14(BadgeMetrics m) => m.longestStreak >= 14;
```

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/models/badge.dart`
Expected: No errors in this file.

---

## Task 5: QuestService — drop XP, persist approvalMode

**Files:**
- Modify: `lib/services/quest_service.dart`

- [ ] **Step 1: Update `createQuest` signature and body**

Replace the `createQuest` method so it takes `approvalMode` and drops xp:

```dart
  Future<String> createQuest({
    required String familyId,
    required String createdBy,
    required String title,
    required String description,
    required String icon,
    required int points,
    required QuestDifficulty difficulty,
    required QuestProof proofRequired,
    required QuestRecurrence recurrence,
    required QuestApprovalMode approvalMode,
  }) async {
    final ref = await _coll.add({
      'familyId': familyId,
      'createdBy': createdBy,
      'title': title,
      'description': description,
      'icon': icon,
      'points': points,
      'difficulty': difficulty.serialized,
      'proofRequired': proofRequired.serialized,
      'recurrence': recurrence.serialized,
      'approvalMode': approvalMode.serialized,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }
```

- [ ] **Step 2: Update `updateQuest`**

```dart
  Future<void> updateQuest({
    required String questId,
    required String title,
    required String description,
    required String icon,
    required int points,
    required QuestDifficulty difficulty,
    required QuestProof proofRequired,
    required QuestRecurrence recurrence,
    required QuestApprovalMode approvalMode,
  }) {
    return _coll.doc(questId).update({
      'title': title,
      'description': description,
      'icon': icon,
      'points': points,
      'difficulty': difficulty.serialized,
      'proofRequired': proofRequired.serialized,
      'recurrence': recurrence.serialized,
      'approvalMode': approvalMode.serialized,
    });
  }
```

- [ ] **Step 3: Delete `_xpForDifficulty`**

Remove the entire `int _xpForDifficulty(...)` method.

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/services/quest_service.dart`
Expected: No errors in this file.

---

## Task 6: Daily-goal token logic (pure) — write the test first

**Files:**
- Create: `lib/services/daily_goal.dart`
- Test: `test/daily_goal_test.dart`

This extracts the "did this earn cross the daily goal?" and "how many tokens does this streak day grant?" decisions into pure functions so the Firestore transaction in Task 7 stays thin and these rules are unit-tested.

- [ ] **Step 1: Write the failing test**

Create `test/daily_goal_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:task2gain/services/daily_goal.dart';

void main() {
  group('crossedDailyGoal', () {
    test('true only when this earn pushes today from below to at-or-above goal', () {
      expect(crossedDailyGoal(earnedToday: 40, justEarned: 20, goal: 50), isTrue);
    });
    test('false when already at/above goal before this earn', () {
      expect(crossedDailyGoal(earnedToday: 60, justEarned: 20, goal: 50), isFalse);
    });
    test('false when still below goal after this earn', () {
      expect(crossedDailyGoal(earnedToday: 10, justEarned: 20, goal: 50), isFalse);
    });
    test('exact hit counts', () {
      expect(crossedDailyGoal(earnedToday: 30, justEarned: 20, goal: 50), isTrue);
    });
  });

  group('streakMilestoneTokens', () {
    test('milestones grant bonus tokens', () {
      expect(streakMilestoneTokens(3), 2);
      expect(streakMilestoneTokens(7), 3);
      expect(streakMilestoneTokens(14), 5);
      expect(streakMilestoneTokens(30), 10);
    });
    test('non-milestone days grant 0', () {
      expect(streakMilestoneTokens(1), 0);
      expect(streakMilestoneTokens(5), 0);
      expect(streakMilestoneTokens(0), 0);
    });
  });
}
```

- [ ] **Step 2: Run it to confirm failure**

Run: `flutter test test/daily_goal_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:task2gain/services/daily_goal.dart'`.

- [ ] **Step 3: Implement the pure functions**

Create `lib/services/daily_goal.dart`:

```dart
/// Pure rules for the daily-goal token loop. Kept out of the Firestore
/// transaction so they can be unit-tested without a backend.

/// True when [justEarned] points are what pushed the running [earnedToday]
/// total from below [goal] to at-or-above it — i.e. the daily goal is met
/// exactly on this earn (so we award the daily-goal token exactly once).
bool crossedDailyGoal({
  required int earnedToday,
  required int justEarned,
  required int goal,
}) {
  if (goal <= 0) return false;
  final before = earnedToday;
  final after = earnedToday + justEarned;
  return before < goal && after >= goal;
}

/// Bonus tokens granted when the streak reaches a milestone day.
int streakMilestoneTokens(int streakDay) {
  switch (streakDay) {
    case 3:
      return 2;
    case 7:
      return 3;
    case 14:
      return 5;
    case 30:
      return 10;
    default:
      return 0;
  }
}
```

- [ ] **Step 4: Run the test to confirm pass**

Run: `flutter test test/daily_goal_test.dart`
Expected: PASS (all 6 tests).

- [ ] **Step 5: Commit Tasks 2–6 together (model+service refactor + daily-goal logic)**

```bash
git add app/lib/models/quest.dart app/lib/models/quest_instance.dart app/lib/models/badge.dart app/lib/services/quest_service.dart app/lib/services/daily_goal.dart app/test/daily_goal_test.dart
git commit -m "refactor(economy): drop XP/levels from models+quest service; add approvalMode + daily-goal token logic"
```

---

## Task 7: QuestInstanceService — rewrite approve(), add completeAuto(), track today's earnings

**Files:**
- Modify: `lib/services/quest_instance_service.dart`
- Test: `test/quest_instance_service_test.dart`

The approve transaction must: credit points + lifetime points, update streak, award a daily-goal token when crossed, award streak-milestone tokens, recompute badges, and write **no** xp/level fields. `completeAuto()` does the same crediting in one shot for `approvalMode == auto` tasks (no separate submit). We track `earnedToday` on the user doc (`{points, date}`) so `crossedDailyGoal` has its input.

- [ ] **Step 1: Write the failing test**

Create `test/quest_instance_service_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2gain/models/quest.dart';
import 'package:task2gain/services/quest_instance_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late QuestInstanceService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = QuestInstanceService(firestore: db);
    await db.collection('users').doc('kid1').set({
      'familyId': 'fam1',
      'dailyGoal': 50,
      'streak': {'current': 0, 'longest': 0, 'lastDate': null},
      'questsCompleted': 0,
      'badges': <Map<String, dynamic>>[],
    });
    await db.collection('wallets').doc('kid1').set({
      'userId': 'kid1',
      'familyId': 'fam1',
      'points': 0,
      'moneyILS': 0,
      'tokens': 0,
      'lifetimeEarned': {'points': 0, 'money': 0},
    });
  });

  Quest quest({int points = 60, QuestApprovalMode mode = QuestApprovalMode.required}) =>
      Quest(
        id: 'q1',
        familyId: 'fam1',
        title: 'נקה את החדר',
        description: '',
        icon: '🧹',
        points: points,
        difficulty: QuestDifficulty.easy,
        proofRequired: QuestProof.none,
        recurrence: QuestRecurrence.once,
        approvalMode: mode,
        createdBy: 'parent1',
        active: true,
        createdAt: DateTime.now(),
      );

  test('approve credits points + lifetime, never writes xp/level', () async {
    final id = await service.startQuest(quest: quest(), kidUid: 'kid1');
    await service.submit(id);
    await service.approve(instanceId: id, adminUid: 'parent1');

    final wallet = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(wallet['points'], 60);
    expect((wallet['lifetimeEarned'] as Map)['points'], 60);

    final user = (await db.collection('users').doc('kid1').get()).data()!;
    expect(user.containsKey('xp'), isFalse);
    expect(user.containsKey('level'), isFalse);
    expect(user['questsCompleted'], 1);
    expect((user['streak'] as Map)['current'], 1);
  });

  test('crossing the daily goal awards exactly one token', () async {
    final id = await service.startQuest(quest: quest(points: 60), kidUid: 'kid1');
    await service.submit(id);
    await service.approve(instanceId: id, adminUid: 'parent1');
    final wallet = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(wallet['tokens'], 1); // 60 >= goal 50, daily-goal token
  });

  test('completeAuto credits instantly without submit', () async {
    final id = await service.completeAuto(
        quest: quest(points: 30, mode: QuestApprovalMode.auto), kidUid: 'kid1');
    final inst = (await db.collection('questInstances').doc(id).get()).data()!;
    expect(inst['status'], 'approved');
    expect(inst['pointsAwarded'], 30);
    final wallet = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(wallet['points'], 30);
    expect(wallet['tokens'], 0); // 30 < goal 50, no daily-goal token yet
  });

  test('first quest unlocks first_quest badge, not any level badge', () async {
    final id = await service.completeAuto(
        quest: quest(mode: QuestApprovalMode.auto), kidUid: 'kid1');
    expect(id, isNotEmpty);
    final user = (await db.collection('users').doc('kid1').get()).data()!;
    final ids = (user['badges'] as List)
        .map((b) => (b as Map)['id'] as String)
        .toList();
    expect(ids, contains('first_quest'));
    expect(ids.any((s) => s.startsWith('level_')), isFalse);
  });
}
```

- [ ] **Step 2: Run it to confirm failure**

Run: `flutter test test/quest_instance_service_test.dart`
Expected: FAIL — `completeAuto` is undefined and approve still writes xp/level.

- [ ] **Step 3: Rewrite the service**

Replace the body of `lib/services/quest_instance_service.dart`. Keep `startQuest` (minus xp), `submit`, `reject`, `watchMine`, `watchPendingApprovals`, the date helpers, and rewrite `approve`. Add a shared private `_creditEarn` used by both `approve` and `completeAuto`.

Replace the imports + `startQuest` + add the new methods:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/badge.dart';
import '../models/quest.dart';
import '../models/quest_instance.dart';
import 'daily_goal.dart';

class QuestInstanceService {
  QuestInstanceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _coll =>
      _firestore.collection('questInstances');

  /// Kid starts a quest — creates an instance in_progress.
  Future<String> startQuest({
    required Quest quest,
    required String kidUid,
  }) async {
    final ref = await _coll.add({
      'questId': quest.id,
      'familyId': quest.familyId,
      'assignedTo': kidUid,
      'status': QuestInstanceStatus.inProgress.serialized,
      'title': quest.title,
      'icon': quest.icon,
      'points': quest.points,
      'startedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> submit(String instanceId, {List<String>? proofPhotos}) {
    return _coll.doc(instanceId).update({
      'status': QuestInstanceStatus.submitted.serialized,
      'submittedAt': FieldValue.serverTimestamp(),
      if (proofPhotos != null && proofPhotos.isNotEmpty)
        'proofPhotos': proofPhotos,
    });
  }

  /// Auto-approved (honor-system) completion: creates an instance already
  /// approved and credits the reward in one transaction. No parent step.
  Future<String> completeAuto({
    required Quest quest,
    required String kidUid,
  }) async {
    final ref = _coll.doc();
    await _firestore.runTransaction((tx) async {
      // All reads must precede writes in a Firestore transaction.
      final earn = await _readEarnState(tx, uid: kidUid);
      tx.set(ref, {
        'questId': quest.id,
        'familyId': quest.familyId,
        'assignedTo': kidUid,
        'status': QuestInstanceStatus.approved.serialized,
        'title': quest.title,
        'icon': quest.icon,
        'points': quest.points,
        'startedAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': kidUid,
        'pointsAwarded': quest.points,
        'comboMultiplier': 1.0,
      });
      _writeEarn(tx, uid: kidUid, points: quest.points, earn: earn,
          instanceRef: ref);
    });
    return ref.id;
  }

  /// Approves a submitted instance and credits points + tokens + streak +
  /// badges atomically. Writes no xp/level.
  Future<void> approve({
    required String instanceId,
    required String adminUid,
  }) async {
    final instanceRef = _coll.doc(instanceId);
    await _firestore.runTransaction((tx) async {
      final instanceSnap = await tx.get(instanceRef);
      if (!instanceSnap.exists) throw StateError('Instance missing');
      final data = instanceSnap.data()!;
      if (data['status'] != QuestInstanceStatus.submitted.serialized) {
        throw StateError('Instance is not awaiting approval');
      }
      final assignedTo = data['assignedTo'] as String;
      final points = (data['points'] as num?)?.toInt() ?? 0;
      final earn = await _readEarnState(tx, uid: assignedTo);
      tx.update(instanceRef, {
        'status': QuestInstanceStatus.approved.serialized,
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'pointsAwarded': points,
      });
      _writeEarn(tx, uid: assignedTo, points: points, earn: earn,
          instanceRef: instanceRef);
    });
  }

  Future<void> reject({
    required String instanceId,
    required String adminUid,
    String? reason,
  }) {
    return _coll.doc(instanceId).update({
      'status': QuestInstanceStatus.rejected.serialized,
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });
  }
```

- [ ] **Step 4: Add the shared earn read/write helpers + date helpers**

Add these inside the class (replacing the old `_todayUtcKey`/`_yesterdayUtcKey` block, which we keep):

```dart
  /// Snapshot of everything the earn-credit needs, read before any write.
  Future<_EarnState> _readEarnState(
      Transaction tx, {required String uid}) async {
    final walletRef = _firestore.collection('wallets').doc(uid);
    final userRef = _firestore.collection('users').doc(uid);
    final walletSnap = await tx.get(walletRef);
    final userSnap = await tx.get(userRef);
    return _EarnState(
      walletRef: walletRef,
      userRef: userRef,
      wallet: walletSnap.data() ?? <String, dynamic>{},
      user: userSnap.data() ?? <String, dynamic>{},
    );
  }

  void _writeEarn(
    Transaction tx, {
    required String uid,
    required int points,
    required _EarnState earn,
    required DocumentReference<Map<String, dynamic>> instanceRef,
  }) {
    final wallet = earn.wallet;
    final user = earn.user;
    final today = _todayUtcKey();
    final yesterday = _yesterdayUtcKey();

    // Lifetime points.
    final lifetime =
        (wallet['lifetimeEarned'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{'points': 0, 'money': 0};
    final newLifetimePoints =
        ((lifetime['points'] as num?)?.toInt() ?? 0) + points;

    // Streak.
    final streakMap =
        (user['streak'] as Map?)?.cast<String, dynamic>() ?? const {};
    final lastDateStr = streakMap['lastDate'] as String?;
    var streakCurrent = (streakMap['current'] as num?)?.toInt() ?? 0;
    var streakLongest = (streakMap['longest'] as num?)?.toInt() ?? 0;
    final streakAlreadyCountedToday = lastDateStr == today;
    if (streakAlreadyCountedToday) {
      // no change
    } else if (lastDateStr == yesterday) {
      streakCurrent += 1;
    } else {
      streakCurrent = 1;
    }
    if (streakCurrent > streakLongest) streakLongest = streakCurrent;

    // Today's running earnings (resets when the date rolls over).
    final earnedMap =
        (user['earnedToday'] as Map?)?.cast<String, dynamic>() ?? const {};
    final earnedDate = earnedMap['date'] as String?;
    final earnedBefore =
        earnedDate == today ? (earnedMap['points'] as num?)?.toInt() ?? 0 : 0;
    final goal = (user['dailyGoal'] as num?)?.toInt() ?? 50;

    // Tokens: daily-goal crossing + streak milestone (only on a fresh streak day).
    var tokensEarned = 0;
    if (crossedDailyGoal(
        earnedToday: earnedBefore, justEarned: points, goal: goal)) {
      tokensEarned += 1;
    }
    if (!streakAlreadyCountedToday) {
      tokensEarned += streakMilestoneTokens(streakCurrent);
    }

    // Badges.
    final questsCompleted =
        ((user['questsCompleted'] as num?)?.toInt() ?? 0) + 1;
    final existingBadges =
        (user['badges'] as List?)?.cast<dynamic>() ?? const <dynamic>[];
    final existingBadgeIds = existingBadges
        .map((b) => (b is Map ? b['id'] as String? : null) ?? '')
        .toSet();
    final metrics = BadgeMetrics(
      lifetimePoints: newLifetimePoints,
      currentStreak: streakCurrent,
      longestStreak: streakLongest,
      questsCompleted: questsCompleted,
    );
    final newlyUnlocked = badgeCatalog
        .where((b) => !existingBadgeIds.contains(b.id) && b.unlocked(metrics))
        .map((b) => {
              'id': b.id,
              'earnedAt': DateTime.now().toUtc().toIso8601String(),
            })
        .toList();
    final updatedBadges = [...existingBadges, ...newlyUnlocked];

    tx.set(earn.walletRef, {
      'points': FieldValue.increment(points),
      'tokens': FieldValue.increment(tokensEarned),
      'lifetimeEarned': {
        'points': newLifetimePoints,
        'money': (lifetime['money'] as num?)?.toInt() ?? 0,
      },
    }, SetOptions(merge: true));

    tx.set(earn.userRef, {
      'streak': {
        'current': streakCurrent,
        'longest': streakLongest,
        'lastDate': today,
      },
      'earnedToday': {'date': today, 'points': earnedBefore + points},
      'questsCompleted': questsCompleted,
      'badges': updatedBadges,
    }, SetOptions(merge: true));

    tx.update(instanceRef, {'tokensAwarded': tokensEarned});
  }

  static String _todayUtcKey() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _yesterdayUtcKey() {
    final y = DateTime.now().toUtc().subtract(const Duration(days: 1));
    return '${y.year.toString().padLeft(4, '0')}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }
```

And keep the existing `watchMine` and `watchPendingApprovals` methods unchanged at the end of the class. Add this small private holder class at the bottom of the file (outside the service class):

```dart
class _EarnState {
  _EarnState({
    required this.walletRef,
    required this.userRef,
    required this.wallet,
    required this.user,
  });
  final DocumentReference<Map<String, dynamic>> walletRef;
  final DocumentReference<Map<String, dynamic>> userRef;
  final Map<String, dynamic> wallet;
  final Map<String, dynamic> user;
}
```

- [ ] **Step 5: Run the test to confirm pass**

Run: `flutter test test/quest_instance_service_test.dart`
Expected: PASS (5 tests after you delete the stray stub line).

- [ ] **Step 6: Commit**

```bash
git add app/lib/services/quest_instance_service.dart app/test/quest_instance_service_test.dart
git commit -m "feat(economy): rewrite approve() w/o XP; add completeAuto + token awards"
```

---

## Task 8: AuthService — seed tokens/dailyGoal, drop xp/level init

**Files:**
- Modify: `lib/services/auth_service.dart`

- [ ] **Step 1: Update the parent's family settings + user + wallet docs**

In `signUpParent`, in the `families` doc `settings` map add `'dailyGoalDefault': 50,`. In the `users/{uid}` set, remove the three lines `'level': 1,`, `'xp': 0,`, `'xpToNextLevel': 100,` and add `'dailyGoal': 50,`. In the `wallets` doc set, add `'tokens': 0,` and `'cosmeticsOwned': <String>[],`.

Resulting parent `users` set:

```dart
    batch.set(userRef, {
      'familyId': familyRef.id,
      'role': 'admin',
      'displayName': parentDisplayName,
      'avatar': {'type': 'preset', 'value': avatar},
      'dailyGoal': 50,
      'streak': {'current': 0, 'longest': 0, 'lastDate': null},
      'badges': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('wallets').doc(uid), {
      'userId': uid,
      'familyId': familyRef.id,
      'points': 0,
      'moneyILS': 0,
      'tokens': 0,
      'cosmeticsOwned': <String>[],
      'lifetimeEarned': {'points': 0, 'money': 0},
    });
```

- [ ] **Step 2: Mirror the change in `signUpWithInvite`**

In `signUpWithInvite`, do the same: remove `level`/`xp`/`xpToNextLevel` from the `users` set and add `'dailyGoal': 50,`; add `'tokens': 0,` and `'cosmeticsOwned': <String>[],` to the wallet set. Read the family's `dailyGoalDefault` is not required here (default 50 is fine for v1).

- [ ] **Step 3: Verify**

Run: `flutter analyze lib/services/auth_service.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add app/lib/services/auth_service.dart
git commit -m "feat(economy): seed tokens + dailyGoal; drop xp/level on signup"
```

---

## Task 9: Prize roll logic (pure, no-loss) — test first

**Files:**
- Create: `lib/models/prize.dart`
- Test: `test/prize_roll_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/prize_roll_test.dart`:

```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2gain/models/prize.dart';

void main() {
  group('wheel no-loss invariant', () {
    test('every defined segment is a positive reward', () {
      for (final seg in defaultWheelSegments) {
        expect(seg.isPositive, isTrue, reason: '${seg.label} must be positive');
      }
    });

    test('1000 weighted rolls always yield a positive reward', () {
      final rng = Random(7);
      for (var i = 0; i < 1000; i++) {
        final result = rollWheel(rng);
        expect(result.isPositive, isTrue);
      }
    });

    test('rare jackpot is actually rare (< 5% over 2000 rolls)', () {
      final rng = Random(11);
      var jackpots = 0;
      for (var i = 0; i < 2000; i++) {
        if (rollWheel(rng).label == defaultJackpotLabel) jackpots++;
      }
      expect(jackpots / 2000, lessThan(0.05));
    });
  });

  group('scratch no-loss invariant', () {
    test('every scratch result is a positive reward', () {
      final rng = Random(3);
      for (var i = 0; i < 500; i++) {
        expect(rollScratch(rng).isPositive, isTrue);
      }
    });
  });
}
```

Note: `lessThan 0.05` above is intentionally malformed — write `lessThan(0.05)` in your real file.

- [ ] **Step 2: Run it to confirm failure**

Run: `flutter test test/prize_roll_test.dart`
Expected: FAIL — `package:task2gain/models/prize.dart` doesn't exist.

- [ ] **Step 3: Implement `lib/models/prize.dart`**

```dart
import 'dart:math';

/// What kind of reward a prize grants.
enum PrizeType { points, tokens, cosmetic }

/// A single prize outcome. No outcome is ever negative — the "no-loss" rule.
class PrizeReward {
  const PrizeReward({
    required this.type,
    required this.value,
    required this.label,
    required this.emoji,
  });

  final PrizeType type;

  /// For points/tokens this is the int amount (as num); for cosmetic it's the
  /// cosmetic id (String).
  final Object value;
  final String label;
  final String emoji;

  bool get isPositive {
    switch (type) {
      case PrizeType.points:
      case PrizeType.tokens:
        return (value as num) > 0;
      case PrizeType.cosmetic:
        return (value as String).isNotEmpty;
    }
  }

  int get intValue => (value as num).toInt();
}

/// A wheel segment = a reward plus a selection weight.
class WheelSegment {
  const WheelSegment({required this.reward, required this.weight});
  final PrizeReward reward;
  final int weight;

  String get label => reward.label;
  bool get isPositive => reward.isPositive;
}

const defaultJackpotLabel = 'ג׳קפוט!';

/// Default wheel config. Weights are tunable; the smallest reward is still
/// positive so the wheel can never "lose".
const defaultWheelSegments = <WheelSegment>[
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 5, label: '5 נקודות', emoji: '⭐'),
    weight: 30,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 15, label: '15 נקודות', emoji: '⭐'),
    weight: 24,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 40, label: '40 נקודות', emoji: '🌟'),
    weight: 14,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.tokens, value: 1, label: 'אסימון', emoji: '🎟️'),
    weight: 18,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.tokens, value: 3, label: '3 אסימונים', emoji: '🎟️'),
    weight: 8,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.cosmetic,
        value: 'frame_confetti',
        label: 'מסגרת קונפטי',
        emoji: '🖼️'),
    weight: 4,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points,
        value: 200,
        label: defaultJackpotLabel,
        emoji: '💎'),
    weight: 2,
  ),
];

/// Default scratch-card prize pool (each panel reveal draws from this).
const defaultScratchRewards = <WheelSegment>[
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 10, label: '10 נקודות', emoji: '⭐'),
    weight: 40,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 30, label: '30 נקודות', emoji: '🌟'),
    weight: 22,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.tokens, value: 1, label: 'אסימון', emoji: '🎟️'),
    weight: 28,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 100, label: '100 נקודות', emoji: '💎'),
    weight: 10,
  ),
];

PrizeReward _weightedPick(Random rng, List<WheelSegment> segments) {
  final total = segments.fold<int>(0, (s, seg) => s + seg.weight);
  var roll = rng.nextInt(total);
  for (final seg in segments) {
    if (roll < seg.weight) return seg.reward;
    roll -= seg.weight;
  }
  return segments.last.reward; // unreachable; safe fallback
}

/// Rolls the wheel; result is always positive (no-loss).
PrizeReward rollWheel([Random? rng]) =>
    _weightedPick(rng ?? Random(), defaultWheelSegments);

/// Rolls a scratch reward; result is always positive (no-loss).
PrizeReward rollScratch([Random? rng]) =>
    _weightedPick(rng ?? Random(), defaultScratchRewards);

/// Index of [reward] within [defaultWheelSegments] (for animating the wheel
/// to the winning slice). Returns 0 if not found.
int wheelSegmentIndex(PrizeReward reward) {
  for (var i = 0; i < defaultWheelSegments.length; i++) {
    if (identical(defaultWheelSegments[i].reward, reward)) return i;
  }
  return 0;
}
```

- [ ] **Step 4: Run the test to confirm pass**

Run: `flutter test test/prize_roll_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Commit**

```bash
git add app/lib/models/prize.dart app/test/prize_roll_test.dart
git commit -m "feat(prize): pure no-loss wheel + scratch roll logic"
```

---

## Task 10: PrizeService — spend a token, award a prize, log it

**Files:**
- Create: `lib/services/prize_service.dart`
- Test: `test/prize_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/prize_service_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2gain/models/prize.dart';
import 'package:task2gain/services/prize_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PrizeService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = PrizeService(firestore: db);
    await db.collection('wallets').doc('kid1').set({
      'userId': 'kid1',
      'familyId': 'fam1',
      'points': 0,
      'tokens': 2,
      'cosmeticsOwned': <String>[],
      'lifetimeEarned': {'points': 0, 'money': 0},
    });
  });

  test('playing debits one token and credits a points reward', () async {
    const reward = PrizeReward(
        type: PrizeType.points, value: 40, label: '40', emoji: '⭐');
    await service.award(
        uid: 'kid1', familyId: 'fam1', game: 'wheel', reward: reward);
    final w = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(w['tokens'], 1);
    expect(w['points'], 40);
  });

  test('a token reward nets zero token change (spent 1, won 1)', () async {
    const reward = PrizeReward(
        type: PrizeType.tokens, value: 1, label: '1', emoji: '🎟️');
    await service.award(
        uid: 'kid1', familyId: 'fam1', game: 'wheel', reward: reward);
    final w = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(w['tokens'], 2); // 2 - 1 spent + 1 won
  });

  test('cosmetic reward is added to cosmeticsOwned', () async {
    const reward = PrizeReward(
        type: PrizeType.cosmetic,
        value: 'frame_confetti',
        label: 'מסגרת',
        emoji: '🖼️');
    await service.award(
        uid: 'kid1', familyId: 'fam1', game: 'scratch', reward: reward);
    final w = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect((w['cosmeticsOwned'] as List), contains('frame_confetti'));
  });

  test('award with no tokens throws and writes nothing', () async {
    await db.collection('wallets').doc('kid1').update({'tokens': 0});
    const reward = PrizeReward(
        type: PrizeType.points, value: 40, label: '40', emoji: '⭐');
    expect(
      () => service.award(
          uid: 'kid1', familyId: 'fam1', game: 'wheel', reward: reward),
      throwsA(isA<StateError>()),
    );
  });

  test('every award writes a prizeWins log entry', () async {
    const reward = PrizeReward(
        type: PrizeType.points, value: 5, label: '5', emoji: '⭐');
    await service.award(
        uid: 'kid1', familyId: 'fam1', game: 'wheel', reward: reward);
    final wins = await db.collection('prizeWins').get();
    expect(wins.docs.length, 1);
    expect(wins.docs.first.data()['userId'], 'kid1');
  });
}
```

- [ ] **Step 2: Run it to confirm failure**

Run: `flutter test test/prize_service_test.dart`
Expected: FAIL — `prize_service.dart` doesn't exist.

- [ ] **Step 3: Implement `lib/services/prize_service.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/prize.dart';

class PrizeService {
  PrizeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Spends one token and credits [reward] atomically, then logs the win.
  /// Throws [StateError] if the wallet has no tokens.
  Future<void> award({
    required String uid,
    required String familyId,
    required String game,
    required PrizeReward reward,
  }) async {
    final walletRef = _firestore.collection('wallets').doc(uid);
    final winRef = _firestore.collection('prizeWins').doc();
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(walletRef);
      if (!snap.exists) throw StateError('ארנק לא נמצא');
      final wallet = snap.data()!;
      final tokens = (wallet['tokens'] as num?)?.toInt() ?? 0;
      if (tokens <= 0) throw StateError('אין אסימונים');

      var tokenDelta = -1; // cost of one play
      final updates = <String, dynamic>{};
      switch (reward.type) {
        case PrizeType.points:
          updates['points'] = FieldValue.increment(reward.intValue);
          final lifetime =
              (wallet['lifetimeEarned'] as Map?)?.cast<String, dynamic>() ??
                  <String, dynamic>{'points': 0, 'money': 0};
          updates['lifetimeEarned'] = {
            'points':
                ((lifetime['points'] as num?)?.toInt() ?? 0) + reward.intValue,
            'money': (lifetime['money'] as num?)?.toInt() ?? 0,
          };
          break;
        case PrizeType.tokens:
          tokenDelta += reward.intValue;
          break;
        case PrizeType.cosmetic:
          updates['cosmeticsOwned'] =
              FieldValue.arrayUnion([reward.value as String]);
          break;
      }
      updates['tokens'] = FieldValue.increment(tokenDelta);

      tx.set(walletRef, updates, SetOptions(merge: true));
      tx.set(winRef, {
        'userId': uid,
        'familyId': familyId,
        'game': game,
        'rewardType': reward.type.name,
        'rewardValue': reward.value,
        'rewardLabel': reward.label,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Recent wins across the family, newest first.
  Stream<List<PrizeWin>> watchRecentWins(String familyId, {int limit = 10}) {
    return _firestore
        .collection('prizeWins')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(PrizeWin.fromDoc).toList();
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list.take(limit).toList();
    });
  }
}

class PrizeWin {
  const PrizeWin({
    required this.id,
    required this.userId,
    required this.game,
    required this.rewardLabel,
    required this.createdAt,
  });
  final String id;
  final String userId;
  final String game;
  final String rewardLabel;
  final DateTime? createdAt;

  factory PrizeWin.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PrizeWin(
      id: doc.id,
      userId: (d['userId'] as String?) ?? '',
      game: (d['game'] as String?) ?? '',
      rewardLabel: (d['rewardLabel'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
```

- [ ] **Step 4: Run the test to confirm pass**

Run: `flutter test test/prize_service_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/prize_service.dart app/test/prize_service_test.dart
git commit -m "feat(prize): token-spend + prize-award transaction with prizeWins log"
```

---

## Task 11: Spin-the-Wheel widget

**Files:**
- Create: `lib/widgets/prize_wheel.dart`

A wheel that, when tapped, animates a spin landing on `targetIndex`, then calls `onSettled`. The parent screen (Task 13) decides the reward via `rollWheel`, passes its index, and persists it via `PrizeService` in `onSettled`.

- [ ] **Step 1: Implement the widget**

```dart
import 'dart:math';
import 'package:flutter/material.dart';

import '../models/prize.dart';
import '../theme/app_theme.dart';

class PrizeWheel extends StatefulWidget {
  const PrizeWheel({
    super.key,
    required this.targetIndex,
    required this.spinning,
    required this.onSettled,
  });

  /// Index in [defaultWheelSegments] the wheel should land on.
  final int targetIndex;

  /// Drive a spin by flipping this to true.
  final bool spinning;
  final VoidCallback onSettled;

  @override
  State<PrizeWheel> createState() => _PrizeWheelState();
}

class _PrizeWheelState extends State<PrizeWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _angle = 0;

  static const _segColors = [
    AppPalette.gold,
    AppPalette.green,
    AppPalette.sky,
    AppPalette.pink,
    AppPalette.violet,
    AppPalette.goldDeep,
    AppPalette.gold,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3600));
  }

  @override
  void didUpdateWidget(PrizeWheel old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !old.spinning) _spin();
  }

  void _spin() {
    final n = defaultWheelSegments.length;
    final slice = 2 * pi / n;
    // Land the target slice's centre at the top pointer (-pi/2).
    final target = -pi / 2 - (widget.targetIndex * slice) - slice / 2;
    final base = _angle % (2 * pi);
    final end = target - base + 2 * pi * 5; // 5 full turns
    _ctrl.reset();
    final tween = Tween<double>(begin: 0, end: end)
        .chain(CurveTween(curve: Curves.easeOutQuart));
    final anim = tween.animate(_ctrl);
    void listener() => setState(() => _angle = (_angle) + 0); // repaint
    anim.addListener(() => setState(() => _angle = base + anim.value));
    _ctrl.addListener(listener);
    _ctrl.forward().whenComplete(() {
      _ctrl.removeListener(listener);
      widget.onSettled();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 300,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Transform.rotate(
              angle: _angle,
              child: CustomPaint(
                size: const Size(260, 260),
                painter: _WheelPainter(colors: _segColors),
              ),
            ),
          ),
          // Pointer at top.
          const Positioned(
            top: 0,
            child: Icon(Icons.arrow_drop_down, size: 48, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.colors});
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final n = defaultWheelSegments.length;
    final slice = 2 * pi / n;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2;
    final textPainter = TextPainter(textDirection: TextDirection.rtl);

    for (var i = 0; i < n; i++) {
      final start = -pi / 2 + i * slice;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = colors[i % colors.length].withValues(alpha: 0.85);
      canvas.drawArc(rect, start, slice, true, paint);
      canvas.drawArc(
        rect,
        start,
        slice,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppPalette.bgDeep,
      );

      // Emoji label at slice mid-angle.
      final mid = start + slice / 2;
      final seg = defaultWheelSegments[i];
      textPainter.text = TextSpan(
          text: seg.reward.emoji, style: const TextStyle(fontSize: 22));
      textPainter.layout();
      final lx = center.dx + cos(mid) * radius * 0.62 - textPainter.width / 2;
      final ly = center.dy + sin(mid) * radius * 0.62 - textPainter.height / 2;
      textPainter.paint(canvas, Offset(lx, ly));
    }

    canvas.drawCircle(center, 18, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `flutter analyze lib/widgets/prize_wheel.dart`
Expected: No errors (info-level lints about unused `listener` pattern are acceptable; if `flutter analyze` flags the redundant `listener`, simplify by removing the no-op `listener` and the `_ctrl.addListener(listener)`/`removeListener` lines, keeping only `anim.addListener`).

---

## Task 12: Scratch-card widget

**Files:**
- Create: `lib/widgets/scratch_card.dart`

A 3-panel card. Tapping a covered panel reveals its (already-rolled) reward; once all three are revealed, `onComplete` fires with the best reward. For v1 simplicity the reward shown is whatever the parent screen rolled (one reward per play); panels reveal the same reward to keep the no-loss contract trivial.

- [ ] **Step 1: Implement the widget**

```dart
import 'package:flutter/material.dart';

import '../models/prize.dart';
import '../theme/app_theme.dart';
import 'scale_tap.dart';

class ScratchCard extends StatefulWidget {
  const ScratchCard({
    super.key,
    required this.reward,
    required this.onComplete,
  });

  /// The reward all three panels reveal (pre-rolled by the parent screen).
  final PrizeReward reward;
  final VoidCallback onComplete;

  @override
  State<ScratchCard> createState() => _ScratchCardState();
}

class _ScratchCardState extends State<ScratchCard> {
  final _revealed = [false, false, false];

  void _reveal(int i) {
    if (_revealed[i]) return;
    setState(() => _revealed[i] = true);
    if (_revealed.every((r) => r)) {
      Future.delayed(const Duration(milliseconds: 400), widget.onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ScaleTap(
              onTap: () => _reveal(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 84,
                height: 104,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: _revealed[i]
                        ? [AppPalette.gold, AppPalette.goldDeep]
                        : [AppPalette.surface, AppPalette.bgDeep],
                  ),
                  border: Border.all(
                    color: _revealed[i]
                        ? AppPalette.gold
                        : Colors.white.withValues(alpha: 0.15),
                    width: 2,
                  ),
                ),
                child: _revealed[i]
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.reward.emoji,
                              style: const TextStyle(fontSize: 34)),
                          const SizedBox(height: 4),
                          Text(widget.reward.label,
                              textAlign: TextAlign.center,
                              style: bodyFont(
                                  size: 10,
                                  weight: FontWeight.w800,
                                  color: AppPalette.bgDeep)),
                        ],
                      )
                    : const Text('❓', style: TextStyle(fontSize: 34)),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/widgets/scratch_card.dart`
Expected: No errors.

---

## Task 13: Prize Machine screen + nav tab

**Files:**
- Create: `lib/screens/prize_machine_screen.dart`
- Modify: `lib/screens/main_navigation.dart`

- [ ] **Step 1: Implement `lib/screens/prize_machine_screen.dart`**

```dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/prize.dart';
import '../services/prize_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_text.dart';
import '../widgets/prize_wheel.dart';
import '../widgets/scale_tap.dart';
import '../widgets/scratch_card.dart';
import '../widgets/screen_chrome.dart';
import 'main_navigation.dart';

class PrizeMachineScreen extends StatefulWidget {
  const PrizeMachineScreen({super.key, required this.data});
  final HomeData data;

  @override
  State<PrizeMachineScreen> createState() => _PrizeMachineScreenState();
}

class _PrizeMachineScreenState extends State<PrizeMachineScreen> {
  final _service = PrizeService();
  final _rng = Random();
  bool _spinning = false;
  int _wheelTarget = 0;
  PrizeReward? _pendingWheel;
  PrizeReward? _scratchReward;
  String? _error;

  Future<int> _tokens() async {
    final snap = await FirebaseFirestore.instance
        .collection('wallets')
        .doc(widget.data.uid)
        .get();
    return (snap.data()?['tokens'] as num?)?.toInt() ?? 0;
  }

  Future<void> _playWheel() async {
    if (_spinning) return;
    if (await _tokens() <= 0) {
      setState(() => _error = 'אין לך אסימונים. תרוויח עוד! 🎯');
      return;
    }
    final reward = rollWheel(_rng);
    setState(() {
      _error = null;
      _pendingWheel = reward;
      _wheelTarget = wheelSegmentIndex(reward);
      _spinning = true;
    });
  }

  Future<void> _onWheelSettled() async {
    final reward = _pendingWheel;
    setState(() => _spinning = false);
    if (reward == null) return;
    try {
      await _service.award(
          uid: widget.data.uid,
          familyId: widget.data.familyId,
          game: 'wheel',
          reward: reward);
      if (mounted) _showWin(reward);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _startScratch() async {
    if (await _tokens() <= 0) {
      setState(() => _error = 'אין לך אסימונים. תרוויח עוד! 🎯');
      return;
    }
    setState(() {
      _error = null;
      _scratchReward = rollScratch(_rng);
    });
  }

  Future<void> _onScratchComplete() async {
    final reward = _scratchReward;
    if (reward == null) return;
    try {
      await _service.award(
          uid: widget.data.uid,
          familyId: widget.data.familyId,
          game: 'scratch',
          reward: reward);
      if (mounted) {
        setState(() => _scratchReward = null);
        _showWin(reward);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _showWin(PrizeReward reward) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppPalette.bgDeep,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppPalette.gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(reward.emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 8),
              GradientText('זכית!',
                  style: displayFont(size: 28, weight: FontWeight.w900),
                  colors: AppPalette.heroGrad),
              const SizedBox(height: 6),
              Text(reward.label,
                  style: displayFont(size: 18, weight: FontWeight.w800)),
              const SizedBox(height: 16),
              ScaleTap(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppPalette.gold, AppPalette.goldDeep]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('אחלה',
                      style: displayFont(
                          size: 16,
                          weight: FontWeight.w900,
                          color: AppPalette.bgDeep)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenChrome(
      title: 'מכונת הפרסים 🎰',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _TokenBalance(uid: widget.data.uid),
          const SizedBox(height: 16),
          Center(
            child: PrizeWheel(
              targetIndex: _wheelTarget,
              spinning: _spinning,
              onSettled: _onWheelSettled,
            ),
          ),
          const SizedBox(height: 8),
          _PlayButton(label: 'סובב! (אסימון 1)', onTap: _playWheel),
          const SizedBox(height: 28),
          Text('כרטיס גירוד', style: displayFont(size: 18, weight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (_scratchReward != null)
            ScratchCard(
                reward: _scratchReward!, onComplete: _onScratchComplete)
          else
            _PlayButton(label: 'כרטיס חדש (אסימון 1)', onTap: _startScratch),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: bodyFont(color: AppPalette.pink)),
          ],
          const SizedBox(height: 24),
          Text('זכיות אחרונות',
              style: displayFont(size: 16, weight: FontWeight.w900)),
          const SizedBox(height: 8),
          _RecentWins(service: _service, familyId: widget.data.familyId),
        ],
      ),
    );
  }
}

class _TokenBalance extends StatelessWidget {
  const _TokenBalance({required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('wallets').doc(uid).snapshots(),
      builder: (context, snap) {
        final tokens = (snap.data?.data()?['tokens'] as num?)?.toInt() ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: [
              AppPalette.violet.withValues(alpha: 0.4),
              AppPalette.sky.withValues(alpha: 0.3),
            ]),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎟️', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Text('$tokens אסימונים',
                  style: displayFont(size: 22, weight: FontWeight.w900)),
            ],
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
              colors: [AppPalette.gold, AppPalette.goldDeep]),
        ),
        child: Center(
          child: Text(label,
              style: displayFont(
                  size: 18,
                  weight: FontWeight.w900,
                  color: AppPalette.bgDeep)),
        ),
      ),
    );
  }
}

class _RecentWins extends StatelessWidget {
  const _RecentWins({required this.service, required this.familyId});
  final PrizeService service;
  final String familyId;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PrizeWin>>(
      stream: service.watchRecentWins(familyId),
      builder: (context, snap) {
        final wins = snap.data ?? const [];
        if (wins.isEmpty) {
          return Text('עוד אין זכיות — תהיה הראשון! ✨',
              style: bodyFont(size: 13, color: Colors.white60));
        }
        return Column(
          children: [
            for (final w in wins)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(w.game == 'wheel' ? '🎡' : '🎫',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(w.rewardLabel,
                          style: bodyFont(size: 13, color: Colors.white70)),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 2: Add the Prize Machine tab to `main_navigation.dart`**

In `_TabHost._tabs` (the getter that returns the list), insert a new `_TabSpec` as the **second** tab (after משימות, before חנות):

```dart
        _TabSpec(
          icon: Icons.casino_outlined,
          activeIcon: Icons.casino_rounded,
          label: 'פרסים',
          builder: (ctx) => PrizeMachineScreen(data: data),
        ),
```

Add the import at the top of `main_navigation.dart`:

```dart
import 'prize_machine_screen.dart';
```

- [ ] **Step 3: Verify the app analyzes**

Run: `flutter analyze lib/screens/prize_machine_screen.dart lib/screens/main_navigation.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add app/lib/widgets/prize_wheel.dart app/lib/widgets/scratch_card.dart app/lib/screens/prize_machine_screen.dart app/lib/screens/main_navigation.dart
git commit -m "feat(prize): Prize Machine screen (wheel + scratch) + nav tab"
```

---

## Task 14: Daily-goal ring widget + Home redesign

**Files:**
- Create: `lib/widgets/daily_goal_ring.dart`
- Modify: `lib/screens/home_tab.dart`

- [ ] **Step 1: Implement the ring**

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular progress ring for the daily points goal.
class DailyGoalRing extends StatelessWidget {
  const DailyGoalRing({
    super.key,
    required this.earnedToday,
    required this.goal,
    this.size = 64,
  });

  final int earnedToday;
  final int goal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (earnedToday / goal).clamp(0.0, 1.0);
    final met = earnedToday >= goal && goal > 0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(
                  met ? AppPalette.green : AppPalette.gold),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(met ? '✅' : '🎯', style: const TextStyle(fontSize: 16)),
              Text('$earnedToday/$goal',
                  style: displayFont(size: 11, weight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Rewrite `_WalletHero` in `home_tab.dart`**

Replace the `_WalletHero` class body's stat row. Specifically:
- In the `StreamBuilder` builder, **remove** the `level`, `xp`, `xpToNext`, and `progress` locals.
- **Add** locals: `final tokens = (wallet['tokens'] as num?)?.toInt() ?? 0;`, `final dailyGoal = (user['dailyGoal'] as num?)?.toInt() ?? 50;`, and read today's earnings: `final earnedMap = (user['earnedToday'] as Map?)?.cast<String, dynamic>() ?? const {}; final earnedToday = (earnedMap['points'] as num?)?.toInt() ?? 0;`.
- Replace `_LevelBadge(level: level)` (in the top Row) with the daily-goal ring:

```dart
                      DailyGoalRing(earnedToday: earnedToday, goal: dailyGoal),
```

- Replace the entire bottom `Row` (the one containing `_StreakFlame` + the XP column, lines ~299–335) with a streak + tokens row:

```dart
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StreakFlame(days: streakDays),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _TokensChip(tokens: tokens),
                      ),
                    ],
                  ),
```

- [ ] **Step 3: Delete `_LevelBadge` and `_XpBar`, add `_TokensChip`**

Delete the entire `_LevelBadge` class and the entire `_XpBar` class from `home_tab.dart`. Add:

```dart
class _TokensChip extends StatelessWidget {
  const _TokensChip({required this.tokens});
  final int tokens;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.violet.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.violet.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('🎟️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text('$tokens אסימונים',
              style: displayFont(size: 15, weight: FontWeight.w900)),
          const Spacer(),
          Text('למכונת הפרסים →',
              style: bodyFont(size: 11, color: Colors.white54)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Remove the XP mini-tag from `_QuestCard`**

In `_QuestCard.build`, in the `Wrap` of `_miniTag`s, delete the line `_miniTag('${quest.xpReward} XP', grad.last),`.

- [ ] **Step 5: Add the import**

At the top of `home_tab.dart`, add:

```dart
import '../widgets/daily_goal_ring.dart';
```

- [ ] **Step 6: Verify**

Run: `flutter analyze lib/screens/home_tab.dart lib/widgets/daily_goal_ring.dart`
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add app/lib/widgets/daily_goal_ring.dart app/lib/screens/home_tab.dart
git commit -m "feat(home): daily-goal ring + streak + tokens; remove level badge/XP bar"
```

---

## Task 15: Quest detail — auto vs. approval-required flow

**Files:**
- Modify: `lib/screens/quest_detail_screen.dart`

- [ ] **Step 1: Branch the submit logic on `approvalMode`**

In `_startAndSubmit`, after computing/uploading proof, branch: if the quest is auto-approve **and** needs no photo, credit instantly via `completeAuto`; otherwise keep the submit flow. Replace the body of `_startAndSubmit` from the `try {` block:

```dart
    try {
      final q = widget.quest;
      if (q.approvalMode == QuestApprovalMode.auto && !_needsPhoto) {
        await _service.completeAuto(quest: q, kidUid: widget.kidUid);
        if (!mounted) return;
        _showCelebration(instant: true);
        return;
      }
      final id = _instanceId ??
          await _service.startQuest(quest: q, kidUid: widget.kidUid);
      _instanceId = id;
      List<String>? urls;
      if (_proofFile != null) {
        final url = await _uploader.uploadProof(
          familyId: q.familyId,
          instanceId: id,
          name: 'proof_${DateTime.now().millisecondsSinceEpoch}',
          file: _proofFile!,
        );
        urls = [url];
      }
      await _service.submit(id, proofPhotos: urls);
      if (!mounted) return;
      _showCelebration(instant: false);
    } catch (e) {
      setState(() => _error = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
```

- [ ] **Step 2: Make the celebration reflect instant vs. pending**

Change `_showCelebration()` to `void _showCelebration({required bool instant})` and replace its message `Text(...)` (the one referencing `xpReward`) with:

```dart
              Text(
                instant
                    ? 'קיבלת +${widget.quest.points}⭐ עכשיו! 🎉'
                    : 'נשלח להורה לאישור.\nכשתאושר תקבל +${widget.quest.points}⭐',
                textAlign: TextAlign.center,
                style: bodyFont(size: 14, height: 1.6),
              ),
```

- [ ] **Step 3: Remove the XP chip**

In `build`, in the `Wrap` of `_chip(...)`, delete the line `_chip('${q.xpReward}', '🔥', 'XP', AppPalette.violet),`.

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/screens/quest_detail_screen.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add app/lib/screens/quest_detail_screen.dart
git commit -m "feat(quest): instant auto-approve flow; drop XP chip"
```

---

## Task 16: Strip XP from profile, family, approvals, admin; add approval-mode picker

**Files:**
- Modify: `lib/screens/profile_tab.dart`, `lib/screens/family_tab.dart`, `lib/screens/approvals_screen.dart`, `lib/screens/admin_screen.dart`, `lib/screens/create_quest_screen.dart`

- [ ] **Step 1: profile_tab — remove the level card**

In `profile_tab.dart`, in the inner `StreamBuilder` builder: remove the `level`, `xp`, `xpToNext`, and `progress` locals. Delete the entire `Container(...)` that renders the "רמה" card (the one after `_StatGrid`, from `const SizedBox(height: 14),` through its closing `),`). Keep the `_StatGrid`. The `Column` children become just:

```dart
                  return Column(
                    children: [
                      _StatGrid(stats: [
                        _Stat('⭐', '$points', 'נקודות', AppPalette.gold),
                        _Stat('💰', '₪${money.toStringAsFixed(2)}', 'כסף',
                            AppPalette.green),
                        _Stat('🔥', '$streakDays', 'רצף', AppPalette.pink),
                        _Stat('🏆', '$questsDone', 'משימות',
                            AppPalette.violet),
                      ]),
                      const SizedBox(height: 14),
                      _LifetimeStrip(
                          longest: streakLongest, lifetime: lifetimePoints),
                    ],
                  );
```

Add a small `_LifetimeStrip` widget at the bottom of `profile_tab.dart`:

```dart
class _LifetimeStrip extends StatelessWidget {
  const _LifetimeStrip({required this.longest, required this.lifetime});
  final int longest;
  final int lifetime;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('רצף שיא: $longest 🔥',
              style: bodyFont(size: 12, color: Colors.white70)),
          Text('סה״כ הרווחת: $lifetime ⭐',
              style: bodyFont(size: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}
```

The locals `streakLongest` and `lifetimePoints` already exist in the builder; keep them.

- [ ] **Step 2: family_tab — sort by lifetimePoints; drop level/xp**

In `family_tab.dart`:
- In `_Entry`, remove the `level` and `xp` fields (and their constructor params). Keep `lifetimePoints`.
- In the `entries` mapping, remove `level:` and `xp:` lines.
- Replace the `entries.sort(...)` body with:

```dart
                entries.sort((a, b) => b.lifetimePoints.compareTo(a.lifetimePoints));
```

- In `_PodiumStep`, replace the `'רמה ${entry.level}'` Text with the lifetime points:

```dart
        Text(
          '${entry.lifetimePoints} ⭐',
          style: bodyFont(size: 11, color: Colors.white60),
        ),
```

- In `_LeaderRow`, in the `Wrap` of `_miniTag`s, delete the `'LV ${entry.level}'` and `'${entry.xp} XP'` tags, keeping only `_miniTag('${entry.lifetimePoints} ⭐', AppPalette.green)`.
- Update the file's top doc comment from "Sorted by level then XP" to "Sorted by lifetime points".

- [ ] **Step 3: approvals_screen — drop XP from the quest card**

In `approvals_screen.dart`, in `_QuestApprovalCardState.build`, replace `'+${inst.points}⭐  ·  +${inst.xpReward} XP'` with `'+${inst.points}⭐'`.

- [ ] **Step 4: admin_screen — drop XP from the quest list subtitle**

In `admin_screen.dart:549`, replace `'${quest.points}⭐ · ${quest.xpReward} XP · ${quest.difficulty.label} · ${quest.recurrence.label}'` with `'${quest.points}⭐ · ${quest.approvalMode.label} · ${quest.recurrence.label}'`.

- [ ] **Step 5: create_quest_screen — add approval-mode state + selector + wire into submit**

In `_CreateQuestScreenState`:
- Add a field: `late QuestApprovalMode _approvalMode;`
- In `initState`, after `_recurrence = ...`, add:

```dart
    _approvalMode = e?.approvalMode ??
        ((e?.proofRequired ?? QuestProof.none) != QuestProof.none ||
                (e?.points ?? 10) >= 100
            ? QuestApprovalMode.required
            : QuestApprovalMode.auto);
```

- In `_submit`, add `approvalMode: _approvalMode,` to **both** the `updateQuest(...)` and `createQuest(...)` calls.
- In `build`, after the "תדירות" `_Segmented<QuestRecurrence>` block, add:

```dart
              const SizedBox(height: 14),
              const FieldLabel('אישור'),
              _Segmented<QuestApprovalMode>(
                values: QuestApprovalMode.values,
                selected: _approvalMode,
                labelOf: (v) => v.label,
                onSelect: (v) => setState(() => _approvalMode = v),
              ),
```

- [ ] **Step 6: Verify all five**

Run: `flutter analyze lib/screens/profile_tab.dart lib/screens/family_tab.dart lib/screens/approvals_screen.dart lib/screens/admin_screen.dart lib/screens/create_quest_screen.dart`
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add app/lib/screens/profile_tab.dart app/lib/screens/family_tab.dart app/lib/screens/approvals_screen.dart app/lib/screens/admin_screen.dart app/lib/screens/create_quest_screen.dart
git commit -m "refactor(ui): remove XP/level from profile/family/approvals/admin; add approval-mode picker"
```

---

## Task 17: Delete the level-up overlay + listener; full analyze

**Files:**
- Delete: `lib/widgets/level_up_overlay.dart`, `lib/widgets/level_change_listener.dart`

- [ ] **Step 1: Confirm nothing imports them**

Run: `grep -rn "level_up_overlay\|level_change_listener\|LevelChangeListener\|showLevelUpOverlay" app/lib`
Expected: matches **only** inside the two files themselves (they're already unused elsewhere). If any other file imports them, stop and remove that usage first.

- [ ] **Step 2: Delete the files**

```bash
git rm app/lib/widgets/level_up_overlay.dart app/lib/widgets/level_change_listener.dart
```

- [ ] **Step 3: Whole-project analyze must be clean**

Run: `flutter analyze`
Expected: `No issues found!` (or only pre-existing info lints). If anything references `xp`, `level`, or the deleted widgets, fix it before continuing.

- [ ] **Step 4: Run the full unit/widget test suite**

Run: `flutter test`
Expected: All tests pass — `test/widget_test.dart`, `test/daily_goal_test.dart`, `test/prize_roll_test.dart`, `test/prize_service_test.dart`, `test/quest_instance_service_test.dart`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: delete level-up overlay + listener (XP/levels removed)"
```

---

## Task 18: Extend the integration harness for the Prize Machine

**Files:**
- Modify: `integration_test/core_flows_test.dart`

- [ ] **Step 1: Add a Prize Machine navigation step**

After the existing Shop-tab step (the block that taps `'חנות'` and waits for `'חנות פרסים 🎁'`), insert a Prize Machine step that taps the new tab and asserts its title renders, then returns home:

```dart
    // 2b. Prize Machine tab.
    await tapText(tester, 'פרסים');
    await pumpUntil(tester, find.text('מכונת הפרסים 🎰'),
        label: 'prize machine tab');
    await pumpUntil(tester, find.text('כרטיס גירוד'),
        label: 'prize machine: scratch section');
```

(The harness is read-only — do not tap "סובב!"/"כרטיס חדש", which would spend tokens and write to Firebase.)

- [ ] **Step 2: Keep existing home assertion valid**

The home heading text is unchanged (`'משימות פתוחות'`), so steps 1, 8, 9 still hold. Confirm no step references removed text (no `'XP'`, no `'רמה'` assertions exist in the harness — verify with `grep -n "XP\|רמה" integration_test/core_flows_test.dart`, expect no matches).

- [ ] **Step 3: Run the integration harness on a simulator**

Run (from `app/`, with a booted iOS simulator — get its UDID via `xcrun simctl list devices booted`):
`flutter test integration_test/core_flows_test.dart -d <simulator-udid>`
Expected: `STEP_OK` lines for every step including `prize machine tab`, ending with `ALL_FLOWS_RENDERED`. Requires a logged-in account whose home shows the seeded quests (same precondition as today's harness).

- [ ] **Step 4: Commit**

```bash
git add app/integration_test/core_flows_test.dart
git commit -m "test: extend integration harness with Prize Machine tab"
```

---

## Task 19: Manual smoke on device (juice verification)

**Files:** none (manual)

- [ ] **Step 1: Run the app**

The project uses a tmux session `t2g` for ~1s hot reloads (send `r`). If it's running, hot-restart with `R` after these changes; otherwise `flutter run -d <device>`.

- [ ] **Step 2: Walk the loop and confirm**

- Home shows the daily-goal ring (🎯), streak flame, and tokens chip — **no** level badge or XP bar.
- Create an auto-approve task (no proof, < 100 pts) in ניהול → complete it from Home → points credit instantly with the 🎉 celebration ("קיבלת +N⭐ עכשיו!").
- Create a proof/required task → completing it shows the "נשלח להורה לאישור" celebration and appears in אישורים.
- Earn enough to cross the daily goal → the ring turns green (✅) and the tokens count goes up.
- Open the פרסים tab → spin the wheel (lands on a slice, win dialog shows a positive reward, token count drops by 1 net of winnings) → scratch a card (3 panels reveal, win dialog). Confirm the "recent wins" feed updates.
- Leaderboard (משפחה) ranks by total earned ⭐, no LV/XP tags.

- [ ] **Step 3: Note any visual issues**

Record anything off (animation timing, overflow, RTL) for a follow-up polish pass. No commit unless you change code.

---

## Self-Review (completed during planning)

**Spec coverage (§§ from the design doc):**
- §5.5 approval gate vs. instant feedback → Tasks 2, 7, 15 (auto vs. required, instant celebration + pending message). ✅
- §5.2 daily goal & streak → Tasks 6, 7, 14 (goal token, streak milestone tokens, ring). ✅
- §5.3 tokens & Prize Machine (Wheel + Scratch, no-loss) → Tasks 9–13. ✅
- §4 currencies: tokens added, points/money unchanged → Tasks 7, 8, 10. ✅
- §7 data model (remove xp/level; add tokens/dailyGoal/approvalMode; prizeWins) → Tasks 2–4, 7, 8, 10. ✅
- §9 removing XP/levels (all listed files + leaderboard sort) → Tasks 2–8, 14–17. ✅
- §11 testing (no-loss invariant unit test, economy unit tests, integration harness extension) → Tasks 9, 10, 7, 18. ✅
- **Deferred to later phases (correctly out of scope here):** combo multiplier, power hour, power task (Phase 2); seasons/SP/leaderboard-by-SP/cosmetics catalog (Phase 3). The `comboMultiplier` field is seeded as `1.0` now so Phase 2 can populate it without a migration.

**Type consistency:** `QuestApprovalMode` (Task 2) used identically in Tasks 5, 7-test, 15, 16. `PrizeReward`/`WheelSegment`/`rollWheel`/`rollScratch`/`wheelSegmentIndex` (Task 9) consumed by Tasks 10–13. `PrizeService.award(uid, familyId, game, reward)` signature matches its callers in Task 13 and test in Task 10. `completeAuto(quest, kidUid)` and `approve(instanceId, adminUid)` match Tasks 7-test and 15.

**Placeholder scan:** none — every code step contains complete, compilable code; every command step states its expected output.
