import 'package:cloud_firestore/cloud_firestore.dart';

enum QuestInstanceStatus { inProgress, submitted, approved, rejected }

class QuestInstance {
  const QuestInstance({
    required this.id,
    required this.questId,
    required this.familyId,
    required this.assignedTo,
    required this.status,
    required this.title,
    required this.icon,
    required this.points,
    required this.xpReward,
    required this.submittedAt,
    required this.approvedBy,
    required this.approvedAt,
    required this.rejectionReason,
    required this.proofPhotos,
  });

  final String id;
  final String questId;
  final String familyId;
  final String assignedTo;
  final QuestInstanceStatus status;
  final String title;
  final String icon;
  final int points;
  final int xpReward;
  final DateTime? submittedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final List<String> proofPhotos;

  factory QuestInstance.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return QuestInstance(
      id: doc.id,
      questId: (d['questId'] as String?) ?? '',
      familyId: (d['familyId'] as String?) ?? '',
      assignedTo: (d['assignedTo'] as String?) ?? '',
      status: _parseStatus(d['status'] as String?),
      title: (d['title'] as String?) ?? '',
      icon: (d['icon'] as String?) ?? '⚡',
      points: (d['points'] as num?)?.toInt() ?? 0,
      xpReward: (d['xpReward'] as num?)?.toInt() ?? 0,
      submittedAt: (d['submittedAt'] as Timestamp?)?.toDate(),
      approvedBy: d['approvedBy'] as String?,
      approvedAt: (d['approvedAt'] as Timestamp?)?.toDate(),
      rejectionReason: d['rejectionReason'] as String?,
      proofPhotos:
          ((d['proofPhotos'] as List?) ?? const []).cast<String>(),
    );
  }

  static QuestInstanceStatus _parseStatus(String? v) {
    switch (v) {
      case 'submitted':
        return QuestInstanceStatus.submitted;
      case 'approved':
        return QuestInstanceStatus.approved;
      case 'rejected':
        return QuestInstanceStatus.rejected;
      default:
        return QuestInstanceStatus.inProgress;
    }
  }
}

extension QuestInstanceStatusLabel on QuestInstanceStatus {
  String get label {
    switch (this) {
      case QuestInstanceStatus.inProgress:
        return 'בעבודה';
      case QuestInstanceStatus.submitted:
        return 'ממתין לאישור';
      case QuestInstanceStatus.approved:
        return 'אושר';
      case QuestInstanceStatus.rejected:
        return 'נדחה';
    }
  }

  String get serialized {
    switch (this) {
      case QuestInstanceStatus.inProgress:
        return 'in_progress';
      case QuestInstanceStatus.submitted:
        return 'submitted';
      case QuestInstanceStatus.approved:
        return 'approved';
      case QuestInstanceStatus.rejected:
        return 'rejected';
    }
  }
}
