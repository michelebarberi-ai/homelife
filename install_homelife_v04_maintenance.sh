#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🔧 HomeLife v0.4 — Manutenzioni"

mkdir -p lib/models
mkdir -p lib/services
mkdir -p lib/screens/house

cat > lib/models/maintenance_record.dart <<'DART'
import 'dart:convert';

class MaintenanceRecord {
  final String id;
  final String title;
  final String? assetId;
  final DateTime performedDate;
  final DateTime? nextDueDate;
  final double? cost;
  final String notes;

  const MaintenanceRecord({
    required this.id,
    required this.title,
    required this.performedDate,
    this.assetId,
    this.nextDueDate,
    this.cost,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'assetId': assetId,
        'performedDate': performedDate.toIso8601String(),
        'nextDueDate': nextDueDate?.toIso8601String(),
        'cost': cost,
        'notes': notes,
      };

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] as String,
      title: map['title'] as String,
      assetId: map['assetId'] as String?,
      performedDate: DateTime.parse(map['performedDate'] as String),
      nextDueDate: map['nextDueDate'] == null
          ? null
          : DateTime.tryParse(map['nextDueDate'] as String),
      cost: (map['cost'] as num?)?.toDouble(),
      notes: (map['notes'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MaintenanceRecord.fromJson(String source) =>
      MaintenanceRecord.fromMap(
        jsonDecode(source) as Map<String, dynamic>,
      );
}
DART

cat > lib/services/maintenance_store.dart <<'DART'
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
DART

cat > lib/screens/house/add_maintenance_screen.dart <<'DART'
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/maintenance_record.dart';
import '../../services/asset_store.dart';
import '../../services/maintenance_store.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final MaintenanceRecord? existingRecord;
  final String? initialAssetId;

  const AddMaintenanceScreen({
    super.key,
    this.existingRecord,
    this.initialAssetId,
  });

  bool get isEditing => existingRecord != null;

  @override
  State<AddMaintenanceScreen> createState() =>
      _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState
    extends State<AddMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _cost;
  late final TextEditingController _notes;

  List<HomeAsset> _assets = [];
  String? _assetId;

  late DateTime _performedDate;
  DateTime? _nextDueDate;

  bool _loadingAssets = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final record = widget.existingRecord;

    _title = TextEditingController(text: record?.title ?? '');
    _cost = TextEditingController(
      text: record?.cost == null
          ? ''
          : record!.cost!.toStringAsFixed(2).replaceAll('.', ','),
    );
    _notes = TextEditingController(text: record?.notes ?? '');

    _assetId = record?.assetId ?? widget.initialAssetId;
    _performedDate = record?.performedDate ?? DateTime.now();
    _nextDueDate = record?.nextDueDate;

    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final assets = await AssetStore().loadAssets();

    if (!mounted) return;

    setState(() {
      _assets = assets;
      _loadingAssets = false;

      if (_assetId != null &&
          !_assets.any((asset) => asset.id == _assetId)) {
        _assetId = null;
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Nessuna data';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<DateTime?> _showDatePicker({
    required String title,
    required DateTime? value,
    bool allowNone = false,
  }) {
    DateTime tempDate = value ?? DateTime.now();

    return showModalBottomSheet<DateTime?>(
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
                      if (allowNone)
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, null),
                          child: const Text('Nessuna data'),
                        )
                      else
                        const SizedBox(width: 110),
                      const Spacer(),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, tempDate),
                        child: const Text('Fine'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: tempDate,
                    dateOrder: DatePickerDateOrder.dmy,
                    minimumDate: DateTime(1990, 1, 1),
                    maximumDate:
                        DateTime.now().add(const Duration(days: 365 * 20)),
                    onDateTimeChanged: (value) {
                      tempDate = value;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickPerformedDate() async {
    final value = await _showDatePicker(
      title: 'Data intervento',
      value: _performedDate,
    );

    if (value != null && mounted) {
      setState(() => _performedDate = value);
    }
  }

  Future<void> _pickNextDueDate() async {
    final value = await _showDatePicker(
      title: 'Prossima scadenza',
      value: _nextDueDate,
      allowNone: true,
    );

    if (!mounted) return;

    setState(() {
      _nextDueDate = value;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final normalizedCost = _cost.text.trim().replaceAll(',', '.');
    final parsedCost =
        normalizedCost.isEmpty ? null : double.tryParse(normalizedCost);

    final record = MaintenanceRecord(
      id: widget.existingRecord?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      assetId: _assetId,
      performedDate: _performedDate,
      nextDueDate: _nextDueDate,
      cost: parsedCost,
      notes: _notes.text.trim(),
    );

    if (widget.isEditing) {
      await MaintenanceStore().update(record);
    } else {
      await MaintenanceStore().add(record);
    }

    if (!mounted) return;
    Navigator.pop(context, record);
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
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
                      _formatDate(value),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: value == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color:
                            value == null ? Colors.grey.shade600 : null,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.calendar_month_outlined),
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
        title: Text(
          widget.isEditing
              ? 'Modifica manutenzione'
              : 'Nuova manutenzione',
        ),
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
                  labelText: 'Intervento',
                  hintText: 'Es. Pulizia filtro',
                  prefixIcon: Icon(Icons.build_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci il tipo di intervento';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String?>(
                initialValue: _assetId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Oggetto',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Casa / manutenzione generale'),
                  ),
                  ..._assets.map(
                    (asset) => DropdownMenuItem<String?>(
                      value: asset.id,
                      child: Text(
                        asset.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: _loadingAssets
                    ? null
                    : (value) {
                        setState(() => _assetId = value);
                      },
              ),
              const SizedBox(height: 14),

              _dateField(
                label: 'Data intervento',
                value: _performedDate,
                onTap: _pickPerformedDate,
                icon: Icons.event_available_outlined,
              ),
              const SizedBox(height: 12),

              _dateField(
                label: 'Prossima scadenza',
                value: _nextDueDate,
                onTap: _pickNextDueDate,
                icon: Icons.notifications_active_outlined,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _cost,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Costo',
                  prefixIcon: Icon(Icons.euro),
                  hintText: '0,00',
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                  hintText: 'Ricambi usati, tecnico, dettagli...',
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
                  _saving
                      ? 'Salvataggio...'
                      : widget.isEditing
                          ? 'Salva modifiche'
                          : 'Salva manutenzione',
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

cat > lib/screens/house/maintenance_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/maintenance_record.dart';
import '../../services/asset_store.dart';
import '../../services/maintenance_store.dart';
import 'add_maintenance_screen.dart';

class MaintenanceScreen extends StatefulWidget {
  final String? assetIdFilter;
  final String? assetName;

  const MaintenanceScreen({
    super.key,
    this.assetIdFilter,
    this.assetName,
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _store = MaintenanceStore();

  bool _loading = true;
  List<MaintenanceRecord> _records = [];
  List<HomeAsset> _assets = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final records = await _store.loadAll();
    final assets = await AssetStore().loadAssets();

    if (!mounted) return;

    setState(() {
      _assets = assets;

      _records = widget.assetIdFilter == null
          ? records
          : records
              .where((item) => item.assetId == widget.assetIdFilter)
              .toList();

      _loading = false;
    });
  }

  String _assetName(String? assetId) {
    if (assetId == null) return 'Casa';

    for (final asset in _assets) {
      if (asset.id == assetId) return asset.name;
    }

    return 'Oggetto non disponibile';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatCost(double? cost) {
    if (cost == null) return '';

    return '€ ${cost.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _add() async {
    final added = await Navigator.push<MaintenanceRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          initialAssetId: widget.assetIdFilter,
        ),
      ),
    );

    if (added != null) {
      await _reload();
    }
  }

  Future<void> _edit(MaintenanceRecord record) async {
    final updated = await Navigator.push<MaintenanceRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          existingRecord: record,
        ),
      ),
    );

    if (updated != null) {
      await _reload();
    }
  }

  Future<void> _delete(MaintenanceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare manutenzione?'),
        content: Text(
          'Vuoi eliminare "${record.title}" dallo storico?',
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

    if (confirmed == true) {
      await _store.delete(record.id);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.assetName == null
        ? 'Manutenzioni'
        : 'Manutenzioni';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Manutenzione'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              if (widget.assetName != null) ...[
                Text(
                  widget.assetName!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
              ],

              Text(
                widget.assetName == null
                    ? 'Storico degli interventi e prossime scadenze.'
                    : 'Storico degli interventi per questo oggetto.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 22),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_records.isEmpty)
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.home_repair_service_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Nessuna manutenzione registrata',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Aggiungi il primo intervento.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('Aggiungi manutenzione'),
                      ),
                    ],
                  ),
                )
              else
                ..._records.map(
                  (record) {
                    final next = record.nextDueDate == null
                        ? 'Nessuna prossima scadenza'
                        : 'Prossima: ${_formatDate(record.nextDueDate)}';

                    final cost = _formatCost(record.cost);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: const Icon(
                            Icons.home_repair_service_outlined,
                          ),
                        ),
                        title: Text(
                          record.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          [
                            _assetName(record.assetId),
                            _formatDate(record.performedDate),
                            if (cost.isNotEmpty) cost,
                            next,
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _edit(record);
                            } else if (value == 'delete') {
                              _delete(record);
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
                        onTap: () => _edit(record),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
DART

# Riscrive HouseScreen mantenendo tutto e collegando Manutenzioni
cat > lib/screens/house/house_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../services/asset_store.dart';
import 'add_asset_screen.dart';
import 'asset_detail_screen.dart';
import 'maintenance_screen.dart';
import 'rooms_screen.dart';

class HouseScreen extends StatefulWidget {
  const HouseScreen({super.key});

  @override
  State<HouseScreen> createState() => _HouseScreenState();
}

class _HouseScreenState extends State<HouseScreen> {
  final _store = AssetStore();

  bool _loading = true;
  List<HomeAsset> _assets = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final assets = await _store.loadAssets();

    if (!mounted) return;

    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  Future<void> _addAsset() async {
    final added = await Navigator.push<HomeAsset>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddAssetScreen(),
      ),
    );

    if (added != null) {
      await _reload();
    }
  }

  Future<void> _openAsset(HomeAsset asset) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(asset: asset),
      ),
    );

    await _reload();
  }

  Future<void> _openRooms() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RoomsScreen(),
      ),
    );

    await _reload();
  }

  Future<void> _openMaintenance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MaintenanceScreen(),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Elettrodomestico':
        return Icons.kitchen_outlined;
      case 'Elettronica':
        return Icons.devices_outlined;
      case 'Impianto':
        return Icons.settings_input_component_outlined;
      case 'Arredamento':
        return Icons.chair_outlined;
      case 'Giardino':
        return Icons.park_outlined;
      case 'Piscina':
        return Icons.pool_outlined;
      case 'Sicurezza':
        return Icons.shield_outlined;
      case 'Smart Home':
        return Icons.sensors_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Widget _topTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
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
                    'Casa',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addAsset,
                  icon: const Icon(Icons.add),
                  label: const Text('Oggetto'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'La memoria digitale della tua casa.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),

            _topTile(
              Icons.grid_view_rounded,
              'Stanze',
              'Organizza casa per ambienti',
              onTap: _openRooms,
            ),

            _topTile(
              Icons.directions_car_outlined,
              'Veicoli',
              'Auto, moto e altri mezzi',
            ),

            _topTile(
              Icons.home_repair_service_outlined,
              'Manutenzioni',
              'Interventi fatti e prossime scadenze',
              onTap: _openMaintenance,
            ),

            const SizedBox(height: 26),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Oggetti',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  '${_assets.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_assets.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 44,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Nessun oggetto registrato',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Aggiungi il primo elettrodomestico, impianto o dispositivo della casa.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _addAsset,
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi il primo oggetto'),
                    ),
                  ],
                ),
              )
            else
              ..._assets.map(
                (asset) {
                  final meta = [
                    asset.category,
                    if (asset.brand.trim().isNotEmpty)
                      asset.brand.trim(),
                  ].join(' • ');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        child: Icon(
                          _categoryIcon(asset.category),
                        ),
                      ),
                      title: Text(
                        asset.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(meta),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openAsset(asset),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
DART

# Riscrive AssetDetailScreen collegando il blocco Manutenzioni
cat > lib/screens/house/asset_detail_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/home_room.dart';
import '../../services/asset_store.dart';
import '../../services/room_store.dart';
import 'add_asset_screen.dart';
import 'maintenance_screen.dart';

class AssetDetailScreen extends StatefulWidget {
  final HomeAsset asset;

  const AssetDetailScreen({
    super.key,
    required this.asset,
  });

  @override
  State<AssetDetailScreen> createState() =>
      _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late HomeAsset _asset;
  String _roomName = 'Non assegnata';

  @override
  void initState() {
    super.initState();
    _asset = widget.asset;
    _loadRoom();
  }

  Future<void> _loadRoom() async {
    if (_asset.roomId == null) {
      if (mounted) {
        setState(() => _roomName = 'Non assegnata');
      }
      return;
    }

    final rooms = await RoomStore().loadRooms();
    HomeRoom? room;

    for (final item in rooms) {
      if (item.id == _asset.roomId) {
        room = item;
        break;
      }
    }

    if (!mounted) return;

    setState(() {
      _roomName = room?.name ?? 'Non assegnata';
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Non indicata';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatPrice(double? value) {
    if (value == null) return 'Non indicato';

    return '€ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<HomeAsset>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAssetScreen(
          existingAsset: _asset,
        ),
      ),
    );

    if (updated == null || !mounted) return;

    setState(() {
      _asset = updated;
    });

    await _loadRoom();
  }

  Future<void> _openMaintenance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceScreen(
          assetIdFilter: _asset.id,
          assetName: _asset.name,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare oggetto?'),
        content: Text(
          'Vuoi eliminare "${_asset.name}" da HomeLife?',
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

    await AssetStore().deleteAsset(_asset.id);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget _row(
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
      if (_asset.brand.trim().isNotEmpty) _asset.brand.trim(),
      if (_asset.model.trim().isNotEmpty) _asset.model.trim(),
    ].join(' ');

    return Scaffold(
      appBar: AppBar(
        title: Text(_asset.name),
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 38,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _asset.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(_asset.category),
                  if (brandModel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(brandModel),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            _row(
              context,
              Icons.meeting_room_outlined,
              'Stanza',
              _roomName,
            ),
            _row(
              context,
              Icons.shopping_bag_outlined,
              'Acquistato',
              _formatDate(_asset.purchaseDate),
            ),
            _row(
              context,
              Icons.euro,
              'Prezzo',
              _formatPrice(_asset.price),
            ),
            _row(
              context,
              Icons.verified_outlined,
              'Garanzia',
              _formatDate(_asset.warrantyExpiry),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifica oggetto'),
              ),
            ),

            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),

            Text(
              'Collegamenti',
              style:
                  Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
            ),
            const SizedBox(height: 10),

            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('Documenti'),
                    subtitle:
                        Text('Fatture, manuali e garanzie'),
                    trailing: Text('Prossimamente'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.home_repair_service_outlined,
                    ),
                    title: const Text('Manutenzioni'),
                    subtitle: const Text(
                      'Storico e prossimi interventi',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openMaintenance,
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.sensors_outlined),
                    title: Text('Smart Home'),
                    subtitle:
                        Text('Stato e controllo dispositivo'),
                    trailing: Text('Prossimamente'),
                  ),
                ],
              ),
            ),

            if (_asset.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
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
                  child: Text(_asset.notes),
                ),
              ),
            ],
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
echo "✅ HomeLife v0.4 installata."
echo "Ora esegui: flutter run"
