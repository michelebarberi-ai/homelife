import 'package:flutter/material.dart';

import '../../models/home_room.dart';
import '../../models/smart_device.dart';
import '../../services/room_store.dart';
import '../../services/smart_device_store.dart';
import 'add_smart_device_screen.dart';
import 'network_device_discovery_screen.dart';
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

  Future<void> _discoverDevices() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NetworkDeviceDiscoveryScreen(),
      ),
    );

    await _reload();
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
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _discoverDevices,
                  icon: const Icon(Icons.wifi_find_outlined),
                  label: const Text('Cerca dispositivi nella rete'),
                ),
              ),

              const SizedBox(height: 18),

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
