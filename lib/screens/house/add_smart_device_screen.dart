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
