import 'dart:convert';

class ArchiveDocument {
  final String id;
  final String title;
  final String category;
  final String? assetId;
  final DateTime? documentDate;
  final DateTime? expiryDate;
  final String reference;
  final String notes;
  final String? attachmentPath;
  final String? attachmentName;

  const ArchiveDocument({
    required this.id,
    required this.title,
    required this.category,
    this.assetId,
    this.documentDate,
    this.expiryDate,
    this.reference = '',
    this.notes = '',
    this.attachmentPath,
    this.attachmentName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'assetId': assetId,
        'documentDate': documentDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'reference': reference,
        'notes': notes,
        'attachmentPath': attachmentPath,
        'attachmentName': attachmentName,
      };

  factory ArchiveDocument.fromMap(Map<String, dynamic> map) {
    return ArchiveDocument(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      assetId: map['assetId'] as String?,
      documentDate: map['documentDate'] == null
          ? null
          : DateTime.tryParse(map['documentDate'] as String),
      expiryDate: map['expiryDate'] == null
          ? null
          : DateTime.tryParse(map['expiryDate'] as String),
      reference: (map['reference'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      attachmentPath: map['attachmentPath'] as String?,
      attachmentName: map['attachmentName'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ArchiveDocument.fromJson(String source) =>
      ArchiveDocument.fromMap(
        jsonDecode(source) as Map<String, dynamic>,
      );
}
