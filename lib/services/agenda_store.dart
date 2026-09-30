import 'package:shared_preferences/shared_preferences.dart';

import '../models/agenda_event.dart';

class AgendaStore {
  static const _key = 'homelife_agenda_events_v1';

  Future<List<AgendaEvent>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    final events = raw
        .map((item) {
          try {
            return AgendaEvent.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<AgendaEvent>()
        .toList();

    events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return events;
  }

  Future<void> saveAll(List<AgendaEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      events.map((event) => event.toJson()).toList(),
    );
  }

  Future<void> add(AgendaEvent event) async {
    final events = await loadAll();
    events.add(event);
    await saveAll(events);
  }

  Future<void> update(AgendaEvent updated) async {
    final events = await loadAll();
    final index = events.indexWhere((event) => event.id == updated.id);

    if (index >= 0) {
      events[index] = updated;
    } else {
      events.add(updated);
    }

    await saveAll(events);
  }

  Future<void> delete(String id) async {
    final events = await loadAll();
    events.removeWhere((event) => event.id == id);
    await saveAll(events);
  }
}
