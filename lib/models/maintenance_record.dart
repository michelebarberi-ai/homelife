import 'dart:convert';

class MaintenanceRecord {
  final String id;
  final String title;
  final String? assetId;
  final DateTime performedDate;
  final DateTime? nextDueDate;
  final double? cost;
  final String notes;

  const MaintenanceRecord({
    required this.id,
    required this.title,
    required this.performedDate,
    this.assetId,
    this.nextDueDate,
    this.cost,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'assetId': assetId,
        'performedDate': performedDate.toIso8601String(),
        'nextDueDate': nextDueDate?.toIso8601String(),
        'cost': cost,
        'notes': notes,
      };

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] as String,
      title: map['title'] as String,
      assetId: map['assetId'] as String?,
      performedDate: DateTime.parse(map['performedDate'] as String),
      nextDueDate: map['nextDueDate'] == null
          ? null
          : DateTime.tryParse(map['nextDueDate'] as String),
      cost: (map['cost'] as num?)?.toDouble(),
      notes: (map['notes'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MaintenanceRecord.fromJson(String source) =>
      MaintenanceRecord.fromMap(
        jsonDecode(source) as Map<String, dynamic>,
      );
}
