/// Snapshot of metrics used to evaluate badge unlocks. Computed inside the
/// approval transaction so badges only ever unlock from a verified state.
class BadgeMetrics {
  const BadgeMetrics({
    required this.level,
    required this.lifetimePoints,
    required this.currentStreak,
    required this.longestStreak,
    required this.questsCompleted,
  });

  final int level;
  final int lifetimePoints;
  final int currentStreak;
  final int longestStreak;
  final int questsCompleted;
}

class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final bool Function(BadgeMetrics m) unlocked;
}

const badgeCatalog = <BadgeDefinition>[
  BadgeDefinition(
    id: 'first_quest',
    title: 'הקווסט הראשון',
    description: 'השלמת את הקווסט הראשון!',
    icon: '🌱',
    unlocked: _firstQuest,
  ),
  BadgeDefinition(
    id: 'quests_10',
    title: 'עשרת המופלאים',
    description: '10 קווסטים מאושרים',
    icon: '⭐',
    unlocked: _quests10,
  ),
  BadgeDefinition(
    id: 'quests_50',
    title: 'מקצוען',
    description: '50 קווסטים מאושרים',
    icon: '🏅',
    unlocked: _quests50,
  ),
  BadgeDefinition(
    id: 'level_5',
    title: 'עולה רמה',
    description: 'הגעת לרמה 5',
    icon: '🎯',
    unlocked: _level5,
  ),
  BadgeDefinition(
    id: 'level_10',
    title: 'אגדי',
    description: 'הגעת לרמה 10',
    icon: '👑',
    unlocked: _level10,
  ),
  BadgeDefinition(
    id: 'streak_3',
    title: 'בעיניים פקוחות',
    description: 'רצף של 3 ימים',
    icon: '🔥',
    unlocked: _streak3,
  ),
  BadgeDefinition(
    id: 'streak_7',
    title: 'שבוע מושלם',
    description: 'רצף של 7 ימים',
    icon: '🔥',
    unlocked: _streak7,
  ),
  BadgeDefinition(
    id: 'streak_30',
    title: 'חודש מסטר',
    description: 'רצף של 30 ימים',
    icon: '💎',
    unlocked: _streak30,
  ),
  BadgeDefinition(
    id: 'points_1000',
    title: 'אספן נקודות',
    description: '1000 נקודות בכל הזמנים',
    icon: '💰',
    unlocked: _points1000,
  ),
];

bool _firstQuest(BadgeMetrics m) => m.questsCompleted >= 1;
bool _quests10(BadgeMetrics m) => m.questsCompleted >= 10;
bool _quests50(BadgeMetrics m) => m.questsCompleted >= 50;
bool _level5(BadgeMetrics m) => m.level >= 5;
bool _level10(BadgeMetrics m) => m.level >= 10;
bool _streak3(BadgeMetrics m) => m.longestStreak >= 3;
bool _streak7(BadgeMetrics m) => m.longestStreak >= 7;
bool _streak30(BadgeMetrics m) => m.longestStreak >= 30;
bool _points1000(BadgeMetrics m) => m.lifetimePoints >= 1000;
