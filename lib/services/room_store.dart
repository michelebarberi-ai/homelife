import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_room.dart';

class RoomStore {
  static const _key = 'homelife_rooms_v1';

  Future<List<HomeRoom>> loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);

    if (raw == null) {
      final defaults = <HomeRoom>[
        const HomeRoom(id: 'default_living', name: 'Soggiorno', iconKey: 'living'),
        const HomeRoom(id: 'default_kitchen', name: 'Cucina', iconKey: 'kitchen'),
        const HomeRoom(id: 'default_bedroom', name: 'Camera', iconKey: 'bedroom'),
        const HomeRoom(id: 'default_bathroom', name: 'Bagno', iconKey: 'bathroom'),
        const HomeRoom(id: 'default_garage', name: 'Garage', iconKey: 'garage'),
      ];
      await saveRooms(defaults);
      return defaults;
    }

    final rooms = raw
        .map((item) {
          try {
            return HomeRoom.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<HomeRoom>()
        .toList();

    rooms.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rooms;
  }

  Future<void> saveRooms(List<HomeRoom> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      rooms.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> addRoom(HomeRoom room) async {
    final rooms = await loadRooms();
    rooms.add(room);
    await saveRooms(rooms);
  }

  Future<void> updateRoom(HomeRoom updated) async {
    final rooms = await loadRooms();
    final index = rooms.indexWhere((room) => room.id == updated.id);
    if (index >= 0) {
      rooms[index] = updated;
    } else {
      rooms.add(updated);
    }
    await saveRooms(rooms);
  }

  Future<void> deleteRoom(String id) async {
    final rooms = await loadRooms();
    rooms.removeWhere((room) => room.id == id);
    await saveRooms(rooms);
  }
}
