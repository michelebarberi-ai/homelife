import 'dart:convert';

class SmartDevice {
  final String id;
  final String name;
  final String type;
  final String brand;
  final String model;
  final String protocol;
  final String host;
  final String? roomId;
  final bool isOnline;
  final bool isControllable;
  final bool isOn;
  final int? batteryPercent;
  final String notes;

  const SmartDevice({
    required this.id,
    required this.name,
    required this.type,
    this.brand = '',
    this.model = '',
    this.protocol = 'Wi-Fi',
    this.host = '',
    this.roomId,
    this.isOnline = true,
    this.isControllable = false,
    this.isOn = false,
    this.batteryPercent,
    this.notes = '',
  });

  SmartDevice copyWith({
    String? id,
    String? name,
    String? type,
    String? brand,
    String? model,
    String? protocol,
    String? host,
    String? roomId,
    bool clearRoomId = false,
    bool? isOnline,
    bool? isControllable,
    bool? isOn,
    int? batteryPercent,
    bool clearBattery = false,
    String? notes,
  }) {
    return SmartDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      roomId: clearRoomId ? null : (roomId ?? this.roomId),
      isOnline: isOnline ?? this.isOnline,
      isControllable: isControllable ?? this.isControllable,
      isOn: isOn ?? this.isOn,
      batteryPercent:
          clearBattery ? null : (batteryPercent ?? this.batteryPercent),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'brand': brand,
        'model': model,
        'protocol': protocol,
        'host': host,
        'roomId': roomId,
        'isOnline': isOnline,
        'isControllable': isControllable,
        'isOn': isOn,
        'batteryPercent': batteryPercent,
        'notes': notes,
      };

  factory SmartDevice.fromMap(Map<String, dynamic> map) {
    return SmartDevice(
      id: map['id'] as String,
      name: map['name'] as String,
      type: (map['type'] as String?) ?? 'Altro',
      brand: (map['brand'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      protocol: (map['protocol'] as String?) ?? 'Wi-Fi',
      host: (map['host'] as String?) ?? '',
      roomId: map['roomId'] as String?,
      isOnline: (map['isOnline'] as bool?) ?? true,
      isControllable: (map['isControllable'] as bool?) ?? false,
      isOn: (map['isOn'] as bool?) ?? false,
      batteryPercent: (map['batteryPercent'] as num?)?.toInt(),
      notes: (map['notes'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SmartDevice.fromJson(String source) =>
      SmartDevice.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
