#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🏠 HomeLife v0.7 — Smart Home Hub"

mkdir -p lib/models
mkdir -p lib/services
mkdir -p lib/screens/house

cat > lib/models/smart_device.dart <<'DART'
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
DART

cat > lib/services/smart_device_store.dart <<'DART'
import 'package:shared_preferences/shared_preferences.dart';

import '../models/smart_device.dart';

class SmartDeviceStore {
  static const _key = 'homelife_smart_devices_v1';

  Future<List<SmartDevice>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    final devices = raw
        .map((item) {
          try {
            return SmartDevice.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<SmartDevice>()
        .toList();

    devices.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return devices;
  }

  Future<void> saveAll(List<SmartDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      devices.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> add(SmartDevice device) async {
    final devices = await loadAll();
    devices.add(device);
    await saveAll(devices);
  }

  Future<void> update(SmartDevice updated) async {
    final devices = await loadAll();
    final index = devices.indexWhere((item) => item.id == updated.id);

    if (index >= 0) {
      devices[index] = updated;
    } else {
      devices.add(updated);
    }

    await saveAll(devices);
  }

  Future<void> delete(String id) async {
    final devices = await loadAll();
    devices.removeWhere((item) => item.id == id);
    await saveAll(devices);
  }
}
DART

cat > lib/screens/house/add_smart_device_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_room.dart';
import '../../models/smart_device.dart';
import '../../services/room_store.dart';
import '../../services/smart_device_store.dart';

class AddSmartDeviceScreen extends StatefulWidget {
  final SmartDevice? existingDevice;

  const AddSmartDeviceScreen({
    super.key,
    this.existingDevice,
  });

  bool get isEditing => existingDevice != null;

  @override
  State<AddSmartDeviceScreen> createState() =>
      _AddSmartDeviceScreenState();
}

class _AddSmartDeviceScreenState extends State<AddSmartDeviceScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _host;
  late final TextEditingController _battery;
  late final TextEditingController _notes;

  late String _type;
  late String _protocol;
  String? _roomId;

  late bool _isOnline;
  late bool _isControllable;
  late bool _isOn;

  bool _loadingRooms = true;
  bool _saving = false;

  List<HomeRoom> _rooms = [];

  static const _types = [
    'Luce',
    'Presa',
    'Termostato',
    'Sensore',
    'Telecamera',
    'Campanello',
    'Elettrodomestico',
    'Altro',
  ];

  static const _protocols = [
    'Wi-Fi',
    'Matter',
    'HomeKit',
    'Zigbee',
    'Bluetooth',
    'Thread',
    'Altro',
  ];

  @override
  void initState() {
    super.initState();

    final device = widget.existingDevice;

    _name = TextEditingController(text: device?.name ?? '');
    _brand = TextEditingController(text: device?.brand ?? '');
    _model = TextEditingController(text: device?.model ?? '');
    _host = TextEditingController(text: device?.host ?? '');
    _battery = TextEditingController(
      text: device?.batteryPercent?.toString() ?? '',
    );
    _notes = TextEditingController(text: device?.notes ?? '');

    _type = device?.type ?? 'Luce';
    _protocol = device?.protocol ?? 'Wi-Fi';
    _roomId = device?.roomId;

    _isOnline = device?.isOnline ?? true;
    _isControllable = device?.isControllable ?? true;
    _isOn = device?.isOn ?? false;

    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final rooms = await RoomStore().loadRooms();

    if (!mounted) return;

    setState(() {
      _rooms = rooms;
      _loadingRooms = false;

      if (_roomId != null &&
          !_rooms.any((room) => room.id == _roomId)) {
        _roomId = null;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _model.dispose();
    _host.dispose();
    _battery.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    int? battery;
    if (_battery.text.trim().isNotEmpty) {
      battery = int.tryParse(_battery.text.trim());
      if (battery != null) {
        battery = battery.clamp(0, 100);
      }
    }

    final device = SmartDevice(
      id: widget.existingDevice?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      type: _type,
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      protocol: _protocol,
      host: _host.text.trim(),
      roomId: _roomId,
      isOnline: _isOnline,
      isControllable: _isControllable,
      isOn: _isControllable ? _isOn : false,
      batteryPercent: battery,
      notes: _notes.text.trim(),
    );

    if (widget.isEditing) {
      await SmartDeviceStore().update(device);
    } else {
      await SmartDeviceStore().add(device);
    }

    if (!mounted) return;
    Navigator.pop(context, device);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Modifica dispositivo'
              : 'Nuovo dispositivo',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Es. Lampada soggiorno',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci un nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: Icon(Icons.devices_other_outlined),
                ),
                items: _types
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String?>(
                initialValue: _roomId,
                decoration: const InputDecoration(
                  labelText: 'Stanza',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Nessuna stanza'),
                  ),
                  ..._rooms.map(
                    (room) => DropdownMenuItem<String?>(
                      value: room.id,
                      child: Text(room.name),
                    ),
                  ),
                ],
                onChanged: _loadingRooms
                    ? null
                    : (value) {
                        setState(() => _roomId = value);
                      },
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brand,
                      decoration: const InputDecoration(
                        labelText: 'Marca',
                        hintText: 'Philips',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _model,
                      decoration: const InputDecoration(
                        labelText: 'Modello',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _protocol,
                decoration: const InputDecoration(
                  labelText: 'Protocollo',
                  prefixIcon: Icon(Icons.hub_outlined),
                ),
                items: _protocols
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _protocol = value);
                  }
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _host,
                decoration: const InputDecoration(
                  labelText: 'IP / Host',
                  hintText: 'Es. 192.168.1.25',
                  prefixIcon: Icon(Icons.lan_outlined),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _battery,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Batteria %',
                  hintText: 'Opzionale',
                  prefixIcon: Icon(Icons.battery_std_outlined),
                ),
              ),
              const SizedBox(height: 14),

              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                ),
                title: const Text('Dispositivo online'),
                subtitle: const Text('Stato manuale per ora'),
                value: _isOnline,
                onChanged: (value) {
                  setState(() => _isOnline = value);
                },
              ),

              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                ),
                title: const Text('Controllabile da HomeLife'),
                subtitle: const Text(
                  'Abilita il comando acceso/spento locale',
                ),
                value: _isControllable,
                onChanged: (value) {
                  setState(() {
                    _isControllable = value;
                    if (!value) {
                      _isOn = false;
                    }
                  });
                },
              ),

              if (_isControllable)
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  title: const Text('Acceso'),
                  subtitle: const Text(
                    'Stato simulato finché non colleghiamo il dispositivo reale',
                  ),
                  value: _isOn,
                  onChanged: (value) {
                    setState(() => _isOn = value);
                  },
                ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                  hintText: 'Posizione, seriale, informazioni utili...',
                ),
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  widget.isEditing
                      ? 'Salva modifiche'
                      : 'Salva dispositivo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
DART

cat > lib/screens/house/smart_device_detail_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_room.dart';
import '../../models/smart_device.dart';
import '../../services/room_store.dart';
import '../../services/smart_device_store.dart';
import 'add_smart_device_screen.dart';

class SmartDeviceDetailScreen extends StatefulWidget {
  final SmartDevice device;

  const SmartDeviceDetailScreen({
    super.key,
    required this.device,
  });

  @override
  State<SmartDeviceDetailScreen> createState() =>
      _SmartDeviceDetailScreenState();
}

class _SmartDeviceDetailScreenState
    extends State<SmartDeviceDetailScreen> {
  late SmartDevice _device;
  String _roomName = 'Non assegnata';

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _loadRoom();
  }

  Future<void> _loadRoom() async {
    if (_device.roomId == null) {
      if (mounted) {
        setState(() => _roomName = 'Non assegnata');
      }
      return;
    }

    final rooms = await RoomStore().loadRooms();
    HomeRoom? found;

    for (final room in rooms) {
      if (room.id == _device.roomId) {
        found = room;
        break;
      }
    }

    if (!mounted) return;

    setState(() {
      _roomName = found?.name ?? 'Non assegnata';
    });
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Luce':
        return Icons.lightbulb_outline;
      case 'Presa':
        return Icons.electrical_services_outlined;
      case 'Termostato':
        return Icons.thermostat_outlined;
      case 'Sensore':
        return Icons.sensors_outlined;
      case 'Telecamera':
        return Icons.videocam_outlined;
      case 'Campanello':
        return Icons.notifications_active_outlined;
      case 'Elettrodomestico':
        return Icons.kitchen_outlined;
      default:
        return Icons.devices_other_outlined;
    }
  }

  Future<void> _togglePower(bool value) async {
    final updated = _device.copyWith(isOn: value);

    await SmartDeviceStore().update(updated);

    if (!mounted) return;

    setState(() {
      _device = updated;
    });
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<SmartDevice>(
      context,
      MaterialPageRoute(
        builder: (_) => AddSmartDeviceScreen(
          existingDevice: _device,
        ),
      ),
    );

    if (updated == null || !mounted) return;

    setState(() {
      _device = updated;
    });

    await _loadRoom();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare dispositivo?'),
        content: Text(
          'Vuoi eliminare "${_device.name}" da HomeLife?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await SmartDeviceStore().delete(_device.id);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon),
      ),
      title: Text(label),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brandModel = [
      if (_device.brand.trim().isNotEmpty) _device.brand.trim(),
      if (_device.model.trim().isNotEmpty) _device.model.trim(),
    ].join(' ');

    return Scaffold(
      appBar: AppBar(
        title: Text(_device.name),
        actions: [
          IconButton(
            tooltip: 'Modifica',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Elimina',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 50),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _typeIcon(_device.type),
                    size: 44,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _device.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(_device.type),
                  if (brandModel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(brandModel),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _device.isOnline
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _device.isOnline
                            ? 'Online'
                            : 'Offline',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _infoRow(
              context,
              Icons.meeting_room_outlined,
              'Stanza',
              _roomName,
            ),

            _infoRow(
              context,
              Icons.hub_outlined,
              'Protocollo',
              _device.protocol,
            ),

            _infoRow(
              context,
              Icons.lan_outlined,
              'IP / Host',
              _device.host.trim().isEmpty
                  ? 'Non indicato'
                  : _device.host.trim(),
            ),

            _infoRow(
              context,
              Icons.battery_std_outlined,
              'Batteria',
              _device.batteryPercent == null
                  ? 'Non indicata'
                  : '${_device.batteryPercent}%',
            ),

            if (_device.isControllable) ...[
              const SizedBox(height: 10),
              Card(
                child: SwitchListTile.adaptive(
                  title: const Text(
                    'Controllo dispositivo',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _device.isOn ? 'Acceso' : 'Spento',
                  ),
                  secondary: Icon(
                    _device.isOn
                        ? Icons.power_settings_new
                        : Icons.power_off_outlined,
                  ),
                  value: _device.isOn,
                  onChanged:
                      _device.isOnline ? _togglePower : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Controllo locale simulato: il comando reale verrà attivato quando collegheremo il relativo ecosistema.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],

            if (_device.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Note',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_device.notes),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
DART

cat > lib/screens/house/smart_home_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_room.dart';
import '../../models/smart_device.dart';
import '../../services/room_store.dart';
import '../../services/smart_device_store.dart';
import 'add_smart_device_screen.dart';
import 'smart_device_detail_screen.dart';

class SmartHomeScreen extends StatefulWidget {
  const SmartHomeScreen({super.key});

  @override
  State<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> {
  final _store = SmartDeviceStore();

  bool _loading = true;
  List<SmartDevice> _devices = [];
  List<HomeRoom> _rooms = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final devices = await _store.loadAll();
    final rooms = await RoomStore().loadRooms();

    if (!mounted) return;

    setState(() {
      _devices = devices;
      _rooms = rooms;
      _loading = false;
    });
  }

  String _roomName(String? roomId) {
    if (roomId == null) return 'Senza stanza';

    for (final room in _rooms) {
      if (room.id == roomId) {
        return room.name;
      }
    }

    return 'Senza stanza';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Luce':
        return Icons.lightbulb_outline;
      case 'Presa':
        return Icons.electrical_services_outlined;
      case 'Termostato':
        return Icons.thermostat_outlined;
      case 'Sensore':
        return Icons.sensors_outlined;
      case 'Telecamera':
        return Icons.videocam_outlined;
      case 'Campanello':
        return Icons.notifications_active_outlined;
      case 'Elettrodomestico':
        return Icons.kitchen_outlined;
      default:
        return Icons.devices_other_outlined;
    }
  }

  Future<void> _add() async {
    final added = await Navigator.push<SmartDevice>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddSmartDeviceScreen(),
      ),
    );

    if (added != null) {
      await _reload();
    }
  }

  Future<void> _open(SmartDevice device) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmartDeviceDetailScreen(
          device: device,
        ),
      ),
    );

    await _reload();
  }

  Future<void> _togglePower(
    SmartDevice device,
    bool value,
  ) async {
    final updated = device.copyWith(isOn: value);
    await _store.update(updated);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<SmartDevice>>{};

    for (final device in _devices) {
      final room = _roomName(device.roomId);
      groups.putIfAbsent(room, () => []).add(device);
    }

    final groupNames = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Home'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Dispositivo'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              Text(
                'Dispositivi connessi e controlli della casa.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 22),

              if (_loading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (_devices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.sensors_outlined,
                        size: 50,
                        color:
                            Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Nessun dispositivo smart',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Aggiungi il primo dispositivo della casa.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('Aggiungi dispositivo'),
                      ),
                    ],
                  ),
                )
              else
                ...groupNames.expand(
                  (groupName) {
                    final devices = groups[groupName]!;

                    return <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 8,
                          bottom: 10,
                        ),
                        child: Text(
                          groupName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      ...devices.map(
                        (device) => Card(
                          margin: const EdgeInsets.only(
                            bottom: 10,
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              child: Icon(
                                _typeIcon(device.type),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    device.name,
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Icon(
                                  device.isOnline
                                      ? Icons.circle
                                      : Icons.circle_outlined,
                                  size: 12,
                                ),
                              ],
                            ),
                            subtitle: Text(
                              [
                                device.type,
                                device.protocol,
                                if (device
                                        .batteryPercent !=
                                    null)
                                  'Batteria ${device.batteryPercent}%',
                              ].join(' • '),
                            ),
                            trailing: device.isControllable
                                ? Switch.adaptive(
                                    value: device.isOn,
                                    onChanged: device.isOnline
                                        ? (value) =>
                                            _togglePower(
                                              device,
                                              value,
                                            )
                                        : null,
                                  )
                                : const Icon(
                                    Icons.chevron_right,
                                  ),
                            onTap: () => _open(device),
                          ),
                        ),
                      ),
                    ];
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
DART

python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/house/house_screen.dart")
text = p.read_text()

if "import 'smart_home_screen.dart';" not in text:
    text = text.replace(
        "import 'rooms_screen.dart';",
        "import 'rooms_screen.dart';\nimport 'smart_home_screen.dart';",
        1,
    )

if "Future<void> _openSmartHome()" not in text:
    anchor = "  Future<void> _openVehicles() async {"
    method = """  Future<void> _openSmartHome() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SmartHomeScreen(),
      ),
    );
  }

"""
    if anchor not in text:
        raise SystemExit("❌ Non trovo il punto per inserire Smart Home.")
    text = text.replace(anchor, method + anchor, 1)

maintenance_block = """            _topTile(
              Icons.home_repair_service_outlined,
              'Manutenzioni',
              'Interventi fatti e prossime scadenze',
              onTap: _openMaintenance,
            ),
"""

smart_block = maintenance_block + """
            _topTile(
              Icons.sensors_outlined,
              'Smart Home',
              'Dispositivi, stato e controlli',
              onTap: _openSmartHome,
            ),
"""

if "'Smart Home',\n              'Dispositivi, stato e controlli'" not in text:
    if maintenance_block not in text:
        raise SystemExit("❌ Non trovo il blocco Manutenzioni.")
    text = text.replace(
        maintenance_block,
        smart_block,
        1,
    )

p.write_text(text)
PY

python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/house/asset_detail_screen.dart")
text = p.read_text()

if "import 'smart_home_screen.dart';" not in text:
    text = text.replace(
        "import 'maintenance_screen.dart';",
        "import 'maintenance_screen.dart';\nimport 'smart_home_screen.dart';",
        1,
    )

if "Future<void> _openSmartHome()" not in text:
    anchor = "  Future<void> _delete() async {"
    method = """  Future<void> _openSmartHome() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SmartHomeScreen(),
      ),
    );
  }

"""
    if anchor not in text:
        raise SystemExit("❌ Non trovo il punto Smart Home in AssetDetail.")
    text = text.replace(anchor, method + anchor, 1)

old = """                  const ListTile(
                    leading: Icon(Icons.sensors_outlined),
                    title: Text('Smart Home'),
                    subtitle:
                        Text('Stato e controllo dispositivo'),
                    trailing: Text('Prossimamente'),
                  ),"""

new = """                  ListTile(
                    leading: const Icon(Icons.sensors_outlined),
                    title: const Text('Smart Home'),
                    subtitle:
                        const Text('Stato e controllo dispositivo'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openSmartHome,
                  ),"""

if old in text:
    text = text.replace(old, new, 1)
elif "onTap: _openSmartHome" not in text:
    raise SystemExit("❌ Non trovo il blocco Smart Home in AssetDetail.")

p.write_text(text)
PY

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.7 installata."
echo "Ora esegui: flutter run"
