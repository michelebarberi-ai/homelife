import 'dart:convert';

class HomeRoom {
  final String id;
  final String name;
  final String iconKey;

  const HomeRoom({
    required this.id,
    required this.name,
    this.iconKey = 'room',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
      };

  factory HomeRoom.fromMap(Map<String, dynamic> map) {
    return HomeRoom(
      id: map['id'] as String,
      name: map['name'] as String,
      iconKey: (map['iconKey'] as String?) ?? 'room',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory HomeRoom.fromJson(String source) =>
      HomeRoom.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
