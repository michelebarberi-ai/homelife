import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_vehicle.dart';

class VehicleStore {
  static const _key = 'homelife_vehicles_v1';

  Future<List<HomeVehicle>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    final vehicles = raw
        .map((item) {
          try {
            return HomeVehicle.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<HomeVehicle>()
        .toList();

    vehicles.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return vehicles;
  }

  Future<void> saveAll(List<HomeVehicle> vehicles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      vehicles.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> add(HomeVehicle vehicle) async {
    final vehicles = await loadAll();
    vehicles.add(vehicle);
    await saveAll(vehicles);
  }

  Future<void> update(HomeVehicle updated) async {
    final vehicles = await loadAll();
    final index = vehicles.indexWhere((item) => item.id == updated.id);

    if (index >= 0) {
      vehicles[index] = updated;
    } else {
      vehicles.add(updated);
    }

    await saveAll(vehicles);
  }

  Future<void> delete(String id) async {
    final vehicles = await loadAll();
    vehicles.removeWhere((item) => item.id == id);
    await saveAll(vehicles);
  }
}
