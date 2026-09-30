#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "📅 HomeLife v0.4.3 — Home reale + Agenda"

mkdir -p lib/models
mkdir -p lib/services
mkdir -p lib/screens/agenda
mkdir -p lib/screens/home

cat > lib/models/agenda_event.dart <<'DART'
import 'dart:convert';

class AgendaEvent {
  final String id;
  final String title;
  final DateTime dateTime;
  final String notes;

  const AgendaEvent({
    required this.id,
    required this.title,
    required this.dateTime,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'notes': notes,
      };

  factory AgendaEvent.fromMap(Map<String, dynamic> map) {
    return AgendaEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
      notes: (map['notes'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AgendaEvent.fromJson(String source) =>
      AgendaEvent.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
DART

cat > lib/services/agenda_store.dart <<'DART'
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
DART

cat > lib/screens/agenda/add_event_screen.dart <<'DART'
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/agenda_event.dart';
import '../../services/agenda_store.dart';

class AddEventScreen extends StatefulWidget {
  final AgendaEvent? existingEvent;
  final DateTime? initialDate;

  const AddEventScreen({
    super.key,
    this.existingEvent,
    this.initialDate,
  });

  bool get isEditing => existingEvent != null;

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _notes;

  late DateTime _dateTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingEvent;
    final base = widget.initialDate ?? DateTime.now();

    _title = TextEditingController(text: existing?.title ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');

    _dateTime = existing?.dateTime ??
        DateTime(
          base.year,
          base.month,
          base.day,
          DateTime.now().hour + 1,
          0,
        );
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    DateTime temp = _dateTime;

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 355,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 72),
                      const Spacer(),
                      const Text(
                        'Data',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext, temp),
                        child: const Text('Fine'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: temp,
                    dateOrder: DatePickerDateOrder.dmy,
                    minimumDate: DateTime(2020, 1, 1),
                    maximumDate:
                        DateTime.now().add(const Duration(days: 365 * 10)),
                    onDateTimeChanged: (value) {
                      temp = DateTime(
                        value.year,
                        value.month,
                        value.day,
                        temp.hour,
                        temp.minute,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _dateTime = DateTime(
          result.year,
          result.month,
          result.day,
          _dateTime.hour,
          _dateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    DateTime temp = _dateTime;

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 330,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 72),
                      const Spacer(),
                      const Text(
                        'Ora',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext, temp),
                        child: const Text('Fine'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    minuteInterval: 5,
                    initialDateTime: temp,
                    onDateTimeChanged: (value) {
                      temp = DateTime(
                        temp.year,
                        temp.month,
                        temp.day,
                        value.hour,
                        value.minute,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _dateTime = DateTime(
          _dateTime.year,
          _dateTime.month,
          _dateTime.day,
          result.hour,
          result.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final event = AgendaEvent(
      id: widget.existingEvent?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      dateTime: _dateTime,
      notes: _notes.text.trim(),
    );

    if (widget.isEditing) {
      await AgendaStore().update(event);
    } else {
      await AgendaStore().add(event);
    }

    if (!mounted) return;
    Navigator.pop(context, event);
  }

  Widget _pickerCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Modifica evento' : 'Nuovo evento'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Evento',
                  hintText: 'Es. Dentista',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci un evento';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _pickerCard(
                icon: Icons.calendar_month_outlined,
                label: 'Data',
                value: _formatDate(_dateTime),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              _pickerCard(
                icon: Icons.schedule_outlined,
                label: 'Ora',
                value: _formatTime(_dateTime),
                onTap: _pickTime,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  widget.isEditing ? 'Salva modifiche' : 'Salva evento',
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

cat > lib/screens/agenda/agenda_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/agenda_event.dart';
import '../../services/agenda_store.dart';
import 'add_event_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _store = AgendaStore();

  bool _loading = true;
  List<AgendaEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final events = await _store.loadAll();

    if (!mounted) return;

    setState(() {
      _events = events;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final event = await Navigator.push<AgendaEvent>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEventScreen(),
      ),
    );

    if (event != null) {
      await _reload();
    }
  }

  Future<void> _edit(AgendaEvent event) async {
    final updated = await Navigator.push<AgendaEvent>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventScreen(existingEvent: event),
      ),
    );

    if (updated != null) {
      await _reload();
    }
  }

  Future<void> _delete(AgendaEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare evento?'),
        content: Text('Vuoi eliminare "${event.title}"?'),
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

    if (confirmed == true) {
      await _store.delete(event.id);
      await _reload();
    }
  }

  String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _time(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Agenda',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Evento'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Impegni e appuntamenti della famiglia.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_events.isEmpty)
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Nessun evento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Aggiungi il primo appuntamento.',
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi evento'),
                    ),
                  ],
                ),
              )
            else
              ..._events.map(
                (event) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: const CircleAvatar(
                      child: Icon(Icons.event_outlined),
                    ),
                    title: Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_date(event.dateTime)} • ${_time(event.dateTime)}'
                      '${event.notes.trim().isEmpty ? '' : '\n${event.notes}'}',
                    ),
                    isThreeLine: event.notes.trim().isNotEmpty,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _edit(event);
                        } else if (value == 'delete') {
                          _delete(event);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 10),
                              Text('Modifica'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline),
                              SizedBox(width: 10),
                              Text('Elimina'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _edit(event),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
DART

cat > lib/screens/home/home_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/agenda_event.dart';
import '../../models/home_asset.dart';
import '../../models/maintenance_record.dart';
import '../../services/agenda_store.dart';
import '../../services/asset_store.dart';
import '../../services/maintenance_store.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/section_title.dart';
import '../agenda/agenda_screen.dart';
import '../house/maintenance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;

  List<MaintenanceRecord> _upcomingMaintenance = [];
  List<HomeAsset> _assets = [];
  List<AgendaEvent> _todayEvents = [];

  int _maintenanceCount = 0;
  int _warrantyCount = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final records = await MaintenanceStore().loadAll();
    final assets = await AssetStore().loadAssets();
    final events = await AgendaStore().loadAll();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = records
        .where((record) {
          final performed = DateTime(
            record.performedDate.year,
            record.performedDate.month,
            record.performedDate.day,
          );

          if (!performed.isBefore(today)) {
            return true;
          }

          final due = record.nextDueDate;
          if (due == null) return false;

          final normalized = DateTime(
            due.year,
            due.month,
            due.day,
          );

          return !normalized.isBefore(today);
        })
        .toList()
      ..sort((a, b) {
        DateTime effectiveDate(MaintenanceRecord record) {
          final performed = DateTime(
            record.performedDate.year,
            record.performedDate.month,
            record.performedDate.day,
          );

          if (!performed.isBefore(today)) {
            return performed;
          }

          return record.nextDueDate!;
        }

        return effectiveDate(a).compareTo(effectiveDate(b));
      });

    final todayEvents = events.where((event) {
      return event.dateTime.year == today.year &&
          event.dateTime.month == today.month &&
          event.dateTime.day == today.day;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final activeWarranties = assets.where((asset) {
      final expiry = asset.warrantyExpiry;
      if (expiry == null) return false;

      final normalized = DateTime(
        expiry.year,
        expiry.month,
        expiry.day,
      );

      return !normalized.isBefore(today);
    }).length;

    if (!mounted) return;

    setState(() {
      _upcomingMaintenance = upcoming;
      _assets = assets;
      _todayEvents = todayEvents;
      _maintenanceCount = records.length;
      _warrantyCount = activeWarranties;
      _loading = false;
    });
  }

  String _assetName(String? assetId) {
    if (assetId == null) return 'Casa';

    for (final asset in _assets) {
      if (asset.id == assetId) return asset.name;
    }

    return 'Oggetto';
  }

  String _time(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _relativeDueText(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(due.year, due.month, due.day);

    final days = target.difference(today).inDays;

    if (days == 0) return 'oggi';
    if (days == 1) return 'domani';
    if (days < 7) return 'tra $days giorni';

    if (days < 30) {
      final weeks = (days / 7).floor();
      return weeks == 1
          ? 'tra 1 settimana'
          : 'tra $weeks settimane';
    }

    return 'il ${_formatDate(due)}';
  }

  Future<void> _openMaintenance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MaintenanceScreen(),
      ),
    );

    await _reload();
  }

  Future<void> _openAgenda() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AgendaScreen(),
      ),
    );

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            Text(
              'Buon pomeriggio',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ecco cosa succede oggi a casa.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),

            const SizedBox(height: 28),

            Row(
              children: [
                const Expanded(
                  child: SectionTitle(title: 'Oggi'),
                ),
                TextButton(
                  onPressed: _openAgenda,
                  child: const Text('Agenda'),
                ),
              ],
            ),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_todayEvents.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      child: Icon(Icons.event_available_outlined),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Nessun evento oggi.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._todayEvents.map(
                (event) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(
                      child: Icon(Icons.calendar_today_outlined),
                    ),
                    title: Text(
                      _time(event.dateTime),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(event.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openAgenda,
                  ),
                ),
              ),

            const SizedBox(height: 18),

            Row(
              children: [
                const Expanded(
                  child: SectionTitle(title: 'Da ricordare'),
                ),
                if (!_loading && _upcomingMaintenance.isNotEmpty)
                  TextButton(
                    onPressed: _openMaintenance,
                    child: const Text('Vedi tutte'),
                  ),
              ],
            ),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_upcomingMaintenance.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      child: Icon(Icons.check_circle_outline),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Nessuna manutenzione in scadenza.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._upcomingMaintenance.take(4).map(
                (record) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);

                  final performed = DateTime(
                    record.performedDate.year,
                    record.performedDate.month,
                    record.performedDate.day,
                  );

                  final isScheduled = !performed.isBefore(today);

                  final effectiveDate =
                      isScheduled ? performed : record.nextDueDate!;

                  final assetName = _assetName(record.assetId);

                  final timingText = isScheduled
                      ? 'Programmato ${_relativeDueText(effectiveDate)}'
                      : 'Scade ${_relativeDueText(effectiveDate)}';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        child: Icon(
                          isScheduled
                              ? Icons.event_available_outlined
                              : Icons.home_repair_service_outlined,
                        ),
                      ),
                      title: Text(
                        record.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '$assetName • $timingText',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openMaintenance,
                    ),
                  );
                },
              ),

            const SizedBox(height: 18),

            const SectionTitle(title: 'Casa'),

            Row(
              children: [
                Expanded(
                  child: DashboardCard(
                    icon: Icons.build_circle_outlined,
                    value: '$_maintenanceCount',
                    label: _maintenanceCount == 1
                        ? 'Manutenzione'
                        : 'Manutenzioni',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DashboardCard(
                    icon: Icons.verified_outlined,
                    value: '$_warrantyCount',
                    label: _warrantyCount == 1
                        ? 'Garanzia'
                        : 'Garanzie',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Chiedi a HomeLife',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
DART

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.4.3 installata."
echo "Ora esegui: flutter run"
