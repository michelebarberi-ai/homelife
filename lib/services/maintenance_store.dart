import 'package:shared_preferences/shared_preferences.dart';

import '../models/maintenance_record.dart';

class MaintenanceStore {
  static const _key = 'homelife_maintenance_v1';

  Future<List<MaintenanceRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    final records = raw
        .map((item) {
          try {
            return MaintenanceRecord.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<MaintenanceRecord>()
        .toList();

    records.sort(
      (a, b) => b.performedDate.compareTo(a.performedDate),
    );

    return records;
  }

  Future<void> saveAll(List<MaintenanceRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      records.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> add(MaintenanceRecord record) async {
    final records = await loadAll();
    records.add(record);
    await saveAll(records);
  }

  Future<void> update(MaintenanceRecord updated) async {
    final records = await loadAll();
    final index = records.indexWhere((item) => item.id == updated.id);

    if (index >= 0) {
      records[index] = updated;
    } else {
      records.add(updated);
    }

    await saveAll(records);
  }

  Future<void> delete(String id) async {
    final records = await loadAll();
    records.removeWhere((item) => item.id == id);
    await saveAll(records);
  }
}
