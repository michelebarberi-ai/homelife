import 'dart:convert';

class HomeVehicle {
  final String id;
  final String type;
  final String name;
  final String brand;
  final String model;
  final String plate;
  final int? year;
  final int? mileage;
  final DateTime? purchaseDate;
  final DateTime? insuranceExpiry;
  final DateTime? roadTaxExpiry;
  final DateTime? inspectionExpiry;
  final String notes;

  const HomeVehicle({
    required this.id,
    required this.type,
    required this.name,
    this.brand = '',
    this.model = '',
    this.plate = '',
    this.year,
    this.mileage,
    this.purchaseDate,
    this.insuranceExpiry,
    this.roadTaxExpiry,
    this.inspectionExpiry,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'name': name,
        'brand': brand,
        'model': model,
        'plate': plate,
        'year': year,
        'mileage': mileage,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'insuranceExpiry': insuranceExpiry?.toIso8601String(),
        'roadTaxExpiry': roadTaxExpiry?.toIso8601String(),
        'inspectionExpiry': inspectionExpiry?.toIso8601String(),
        'notes': notes,
      };

  factory HomeVehicle.fromMap(Map<String, dynamic> map) {
    return HomeVehicle(
      id: map['id'] as String,
      type: (map['type'] as String?) ?? 'Auto',
      name: map['name'] as String,
      brand: (map['brand'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      plate: (map['plate'] as String?) ?? '',
      year: (map['year'] as num?)?.toInt(),
      mileage: (map['mileage'] as num?)?.toInt(),
      purchaseDate: map['purchaseDate'] == null
          ? null
          : DateTime.tryParse(map['purchaseDate'] as String),
      insuranceExpiry: map['insuranceExpiry'] == null
          ? null
          : DateTime.tryParse(map['insuranceExpiry'] as String),
      roadTaxExpiry: map['roadTaxExpiry'] == null
          ? null
          : DateTime.tryParse(map['roadTaxExpiry'] as String),
      inspectionExpiry: map['inspectionExpiry'] == null
          ? null
          : DateTime.tryParse(map['inspectionExpiry'] as String),
      notes: (map['notes'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory HomeVehicle.fromJson(String source) =>
      HomeVehicle.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
