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
