import 'dart:convert';

class AgendaEvent {
  final String id;
  final String title;
  final DateTime dateTime;
  final String notes;

  const AgendaEvent({
    required this.id,
    required this.title,
    required this.dateTime,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'notes': notes,
      };

  factory AgendaEvent.fromMap(Map<String, dynamic> map) {
    return AgendaEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
      notes: (map['notes'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AgendaEvent.fromJson(String source) =>
      AgendaEvent.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
