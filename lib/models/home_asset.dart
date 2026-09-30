import 'dart:convert';

class HomeAsset {
  final String id;
  final String name;
  final String category;
  final String brand;
  final String model;
  final DateTime? purchaseDate;
  final double? price;
  final DateTime? warrantyExpiry;
  final String notes;
  final String? roomId;

  const HomeAsset({
    required this.id,
    required this.name,
    required this.category,
    this.brand = '',
    this.model = '',
    this.purchaseDate,
    this.price,
    this.warrantyExpiry,
    this.notes = '',
    this.roomId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'brand': brand,
        'model': model,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'price': price,
        'warrantyExpiry': warrantyExpiry?.toIso8601String(),
        'notes': notes,
        'roomId': roomId,
      };

  factory HomeAsset.fromMap(Map<String, dynamic> map) {
    return HomeAsset(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      brand: (map['brand'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      purchaseDate: map['purchaseDate'] == null
          ? null
          : DateTime.tryParse(map['purchaseDate'] as String),
      price: (map['price'] as num?)?.toDouble(),
      warrantyExpiry: map['warrantyExpiry'] == null
          ? null
          : DateTime.tryParse(map['warrantyExpiry'] as String),
      notes: (map['notes'] as String?) ?? '',
      roomId: map['roomId'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory HomeAsset.fromJson(String source) =>
      HomeAsset.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
