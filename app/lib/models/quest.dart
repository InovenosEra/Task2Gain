import 'package:cloud_firestore/cloud_firestore.dart';

enum QuestDifficulty { easy, medium, epic }

enum QuestProof { none, photo, beforeAfter }

enum QuestRecurrence { once, daily, weekly }

class Quest {
  const Quest({
    required this.id,
    required this.familyId,
    required this.title,
    required this.description,
    required this.icon,
    required this.points,
    required this.xpReward,
    required this.difficulty,
    required this.proofRequired,
    required this.recurrence,
    required this.createdBy,
    required this.active,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String title;
  final String description;
  final String icon;
  final int points;
  final int xpReward;
  final QuestDifficulty difficulty;
  final QuestProof proofRequired;
  final QuestRecurrence recurrence;
  final String createdBy;
  final bool active;
  final DateTime? createdAt;

  factory Quest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Quest(
      id: doc.id,
      familyId: (d['familyId'] as String?) ?? '',
      title: (d['title'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
      icon: (d['icon'] as String?) ?? '⚡',
      points: (d['points'] as num?)?.toInt() ?? 0,
      xpReward: (d['xpReward'] as num?)?.toInt() ?? 0,
      difficulty: _parseDifficulty(d['difficulty'] as String?),
      proofRequired: _parseProof(d['proofRequired'] as String?),
      recurrence: _parseRecurrence(d['recurrence'] as String?),
      createdBy: (d['createdBy'] as String?) ?? '',
      active: (d['active'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static QuestDifficulty _parseDifficulty(String? v) {
    switch (v) {
      case 'medium':
        return QuestDifficulty.medium;
      case 'epic':
        return QuestDifficulty.epic;
      default:
        return QuestDifficulty.easy;
    }
  }

  static QuestProof _parseProof(String? v) {
    switch (v) {
      case 'photo':
        return QuestProof.photo;
      case 'before-after':
        return QuestProof.beforeAfter;
      default:
        return QuestProof.none;
    }
  }

  static QuestRecurrence _parseRecurrence(String? v) {
    switch (v) {
      case 'daily':
        return QuestRecurrence.daily;
      case 'weekly':
        return QuestRecurrence.weekly;
      default:
        return QuestRecurrence.once;
    }
  }
}

extension QuestDifficultyLabel on QuestDifficulty {
  String get label {
    switch (this) {
      case QuestDifficulty.easy:
        return 'קל';
      case QuestDifficulty.medium:
        return 'בינוני';
      case QuestDifficulty.epic:
        return 'אפי';
    }
  }

  String get serialized => name;
}

extension QuestProofLabel on QuestProof {
  String get label {
    switch (this) {
      case QuestProof.none:
        return 'בלי הוכחה';
      case QuestProof.photo:
        return 'תמונה';
      case QuestProof.beforeAfter:
        return 'לפני / אחרי';
    }
  }

  String get serialized {
    switch (this) {
      case QuestProof.beforeAfter:
        return 'before-after';
      default:
        return name;
    }
  }
}

extension QuestRecurrenceLabel on QuestRecurrence {
  String get label {
    switch (this) {
      case QuestRecurrence.once:
        return 'חד פעמי';
      case QuestRecurrence.daily:
        return 'כל יום';
      case QuestRecurrence.weekly:
        return 'כל שבוע';
    }
  }

  String get serialized => name;
}
