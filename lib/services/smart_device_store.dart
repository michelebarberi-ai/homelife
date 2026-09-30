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
