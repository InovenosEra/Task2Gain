import 'package:cloud_firestore/cloud_firestore.dart';

class Reward {
  const Reward({
    required this.id,
    required this.familyId,
    required this.title,
    required this.description,
    required this.icon,
    required this.priceILS,
    required this.stock,
    required this.active,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String title;
  final String description;
  final String icon;
  final double priceILS;
  final int? stock; // null = unlimited
  final bool active;
  final String createdBy;
  final DateTime? createdAt;

  factory Reward.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final stockField = d['stock'];
    return Reward(
      id: doc.id,
      familyId: (d['familyId'] as String?) ?? '',
      title: (d['title'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
      icon: (d['icon'] as String?) ?? '🎁',
      priceILS: (d['priceILS'] as num?)?.toDouble() ?? 0.0,
      stock: stockField is num ? stockField.toInt() : null,
      active: (d['active'] as bool?) ?? true,
      createdBy: (d['createdBy'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
