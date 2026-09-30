import 'package:flutter/material.dart';

import '../../models/agenda_event.dart';
import '../../models/home_asset.dart';
import '../../models/home_vehicle.dart';
import '../../models/maintenance_record.dart';
import '../../services/agenda_store.dart';
import '../../services/asset_store.dart';
import '../../services/maintenance_store.dart';
import '../../services/vehicle_store.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/section_title.dart';
import '../agenda/agenda_screen.dart';
import '../house/maintenance_screen.dart';
import '../house/vehicles_screen.dart';

class _ReminderItem {
  final String title;
  final String subtitle;
  final DateTime date;
  final IconData icon;
  final VoidCallback onTap;

  const _ReminderItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    required this.onTap,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;

  List<MaintenanceRecord> _maintenanceRecords = [];
  List<HomeAsset> _assets = [];
  List<HomeVehicle> _vehicles = [];
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
    final vehicles = await VehicleStore().loadAll();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

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
      _maintenanceRecords = records;
      _assets = assets;
      _vehicles = vehicles;
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

    if (days < 60) {
      return 'tra 1 mese';
    }

    return 'il ${_formatDate(due)}';
  }

  List<_ReminderItem> _buildReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminders = <_ReminderItem>[];

    for (final record in _maintenanceRecords) {
      final performed = DateTime(
        record.performedDate.year,
        record.performedDate.month,
        record.performedDate.day,
      );

      if (!performed.isBefore(today)) {
        reminders.add(
          _ReminderItem(
            title: record.title,
            subtitle:
                '${_assetName(record.assetId)} • Programmato ${_relativeDueText(performed)}',
            date: performed,
            icon: Icons.event_available_outlined,
            onTap: _openMaintenance,
          ),
        );
        continue;
      }

      final due = record.nextDueDate;
      if (due == null) continue;

      final normalized = DateTime(due.year, due.month, due.day);
      if (normalized.isBefore(today)) continue;

      reminders.add(
        _ReminderItem(
          title: record.title,
          subtitle:
              '${_assetName(record.assetId)} • Scade ${_relativeDueText(normalized)}',
          date: normalized,
          icon: Icons.home_repair_service_outlined,
          onTap: _openMaintenance,
        ),
      );
    }

    for (final vehicle in _vehicles) {
      void addVehicleReminder({
        required String title,
        required DateTime? date,
        required IconData icon,
      }) {
        if (date == null) return;

        final normalized = DateTime(
          date.year,
          date.month,
          date.day,
        );

        if (normalized.isBefore(today)) return;

        reminders.add(
          _ReminderItem(
            title: title,
            subtitle:
                '${vehicle.name} • Scade ${_relativeDueText(normalized)}',
            date: normalized,
            icon: icon,
            onTap: _openVehicles,
          ),
        );
      }

      addVehicleReminder(
        title: 'Assicurazione',
        date: vehicle.insuranceExpiry,
        icon: Icons.shield_outlined,
      );

      addVehicleReminder(
        title: 'Bollo',
        date: vehicle.roadTaxExpiry,
        icon: Icons.receipt_long_outlined,
      );

      addVehicleReminder(
        title: 'Revisione',
        date: vehicle.inspectionExpiry,
        icon: Icons.fact_check_outlined,
      );
    }

    reminders.sort((a, b) => a.date.compareTo(b.date));
    return reminders;
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

  Future<void> _openVehicles() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VehiclesScreen(),
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
    final reminders = _buildReminders();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            Text(
              'Buon pomeriggio',
              style:
                  Theme.of(context).textTheme.headlineMedium?.copyWith(
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
              const Center(
                child: CircularProgressIndicator(),
              )
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
                      child: Icon(
                        Icons.event_available_outlined,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Nessun evento oggi.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
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
                      child: Icon(
                        Icons.calendar_today_outlined,
                      ),
                    ),
                    title: Text(
                      _time(event.dateTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(event.title),
                    trailing:
                        const Icon(Icons.chevron_right),
                    onTap: _openAgenda,
                  ),
                ),
              ),

            const SizedBox(height: 18),

            Row(
              children: [
                const Expanded(
                  child: SectionTitle(
                    title: 'Da ricordare',
                  ),
                ),
                if (!_loading && reminders.isNotEmpty)
                  Text(
                    '${reminders.length}',
                    style:
                        Theme.of(context).textTheme.titleMedium,
                  ),
              ],
            ),

            if (_loading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (reminders.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      child: Icon(
                        Icons.check_circle_outline,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Nessuna scadenza da ricordare.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...reminders.take(5).map(
                (reminder) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      child: Icon(reminder.icon),
                    ),
                    title: Text(
                      reminder.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(reminder.subtitle),
                    trailing:
                        const Icon(Icons.chevron_right),
                    onTap: reminder.onTap,
                  ),
                ),
              ),

            const SizedBox(height: 18),

            const SectionTitle(title: 'Casa'),

            Row(
              children: [
                Expanded(
                  child: DashboardCard(
                    icon:
                        Icons.build_circle_outlined,
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
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius:
                    BorderRadius.circular(22),
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
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}
