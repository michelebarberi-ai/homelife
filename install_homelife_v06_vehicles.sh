#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🚗 HomeLife v0.6 — Veicoli"

mkdir -p lib/models
mkdir -p lib/services
mkdir -p lib/screens/house

cat > lib/models/home_vehicle.dart <<'DART'
import 'dart:convert';

class HomeVehicle {
  final String id;
  final String type;
  final String name;
  final String brand;
  final String model;
  final String plate;
  final int? year;
  final int? mileage;
  final DateTime? purchaseDate;
  final DateTime? insuranceExpiry;
  final DateTime? roadTaxExpiry;
  final DateTime? inspectionExpiry;
  final String notes;

  const HomeVehicle({
    required this.id,
    required this.type,
    required this.name,
    this.brand = '',
    this.model = '',
    this.plate = '',
    this.year,
    this.mileage,
    this.purchaseDate,
    this.insuranceExpiry,
    this.roadTaxExpiry,
    this.inspectionExpiry,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'name': name,
        'brand': brand,
        'model': model,
        'plate': plate,
        'year': year,
        'mileage': mileage,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'insuranceExpiry': insuranceExpiry?.toIso8601String(),
        'roadTaxExpiry': roadTaxExpiry?.toIso8601String(),
        'inspectionExpiry': inspectionExpiry?.toIso8601String(),
        'notes': notes,
      };

  factory HomeVehicle.fromMap(Map<String, dynamic> map) {
    return HomeVehicle(
      id: map['id'] as String,
      type: (map['type'] as String?) ?? 'Auto',
      name: map['name'] as String,
      brand: (map['brand'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      plate: (map['plate'] as String?) ?? '',
      year: (map['year'] as num?)?.toInt(),
      mileage: (map['mileage'] as num?)?.toInt(),
      purchaseDate: map['purchaseDate'] == null
          ? null
          : DateTime.tryParse(map['purchaseDate'] as String),
      insuranceExpiry: map['insuranceExpiry'] == null
          ? null
          : DateTime.tryParse(map['insuranceExpiry'] as String),
      roadTaxExpiry: map['roadTaxExpiry'] == null
          ? null
          : DateTime.tryParse(map['roadTaxExpiry'] as String),
      inspectionExpiry: map['inspectionExpiry'] == null
          ? null
          : DateTime.tryParse(map['inspectionExpiry'] as String),
      notes: (map['notes'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory HomeVehicle.fromJson(String source) =>
      HomeVehicle.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
DART

cat > lib/services/vehicle_store.dart <<'DART'
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
DART

cat > lib/screens/house/add_vehicle_screen.dart <<'DART'
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/home_vehicle.dart';
import '../../services/vehicle_store.dart';

class AddVehicleScreen extends StatefulWidget {
  final HomeVehicle? existingVehicle;

  const AddVehicleScreen({
    super.key,
    this.existingVehicle,
  });

  bool get isEditing => existingVehicle != null;

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _plate;
  late final TextEditingController _year;
  late final TextEditingController _mileage;
  late final TextEditingController _notes;

  late String _type;
  DateTime? _purchaseDate;
  DateTime? _insuranceExpiry;
  DateTime? _roadTaxExpiry;
  DateTime? _inspectionExpiry;

  bool _saving = false;

  static const _types = [
    'Auto',
    'Moto',
    'Scooter',
    'Bici',
    'E-bike',
    'Camper',
    'Altro',
  ];

  @override
  void initState() {
    super.initState();

    final vehicle = widget.existingVehicle;

    _name = TextEditingController(text: vehicle?.name ?? '');
    _brand = TextEditingController(text: vehicle?.brand ?? '');
    _model = TextEditingController(text: vehicle?.model ?? '');
    _plate = TextEditingController(text: vehicle?.plate ?? '');
    _year = TextEditingController(
      text: vehicle?.year?.toString() ?? '',
    );
    _mileage = TextEditingController(
      text: vehicle?.mileage?.toString() ?? '',
    );
    _notes = TextEditingController(text: vehicle?.notes ?? '');

    _type = vehicle?.type ?? 'Auto';
    _purchaseDate = vehicle?.purchaseDate;
    _insuranceExpiry = vehicle?.insuranceExpiry;
    _roadTaxExpiry = vehicle?.roadTaxExpiry;
    _inspectionExpiry = vehicle?.inspectionExpiry;
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _model.dispose();
    _plate.dispose();
    _year.dispose();
    _mileage.dispose();
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
    required DateTime? currentValue,
  }) async {
    DateTime tempDate = currentValue ?? DateTime.now();

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
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, null),
                        child: const Text('Nessuna data'),
                      ),
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
                    minimumDate: DateTime(1950, 1, 1),
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

  Future<void> _pickDate(
    String title,
    DateTime? currentValue,
    void Function(DateTime?) setter,
  ) async {
    final result = await _showDatePicker(
      title: title,
      currentValue: currentValue,
    );

    if (!mounted) return;
    setState(() => setter(result));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final vehicle = HomeVehicle(
      id: widget.existingVehicle?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      name: _name.text.trim(),
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      plate: _plate.text.trim().toUpperCase(),
      year: int.tryParse(_year.text.trim()),
      mileage: int.tryParse(
        _mileage.text.trim().replaceAll('.', ''),
      ),
      purchaseDate: _purchaseDate,
      insuranceExpiry: _insuranceExpiry,
      roadTaxExpiry: _roadTaxExpiry,
      inspectionExpiry: _inspectionExpiry,
      notes: _notes.text.trim(),
    );

    if (widget.isEditing) {
      await VehicleStore().update(vehicle);
    } else {
      await VehicleStore().add(vehicle);
    }

    if (!mounted) return;
    Navigator.pop(context, vehicle);
  }

  Widget _dateField({
    required IconData icon,
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
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
          widget.isEditing ? 'Modifica veicolo' : 'Nuovo veicolo',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
                items: _types
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Es. Auto Michele',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci un nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brand,
                      decoration: const InputDecoration(
                        labelText: 'Marca',
                        hintText: 'Fiat',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _model,
                      decoration: const InputDecoration(
                        labelText: 'Modello',
                        hintText: '500',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Targa',
                  hintText: 'AB123CD',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Anno',
                        hintText: '2024',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _mileage,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Km',
                        hintText: '25000',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _dateField(
                icon: Icons.shopping_bag_outlined,
                label: 'Data acquisto',
                value: _purchaseDate,
                onTap: () => _pickDate(
                  'Data acquisto',
                  _purchaseDate,
                  (value) => _purchaseDate = value,
                ),
              ),
              const SizedBox(height: 12),

              _dateField(
                icon: Icons.shield_outlined,
                label: 'Scadenza assicurazione',
                value: _insuranceExpiry,
                onTap: () => _pickDate(
                  'Assicurazione',
                  _insuranceExpiry,
                  (value) => _insuranceExpiry = value,
                ),
              ),
              const SizedBox(height: 12),

              _dateField(
                icon: Icons.receipt_long_outlined,
                label: 'Scadenza bollo',
                value: _roadTaxExpiry,
                onTap: () => _pickDate(
                  'Bollo',
                  _roadTaxExpiry,
                  (value) => _roadTaxExpiry = value,
                ),
              ),
              const SizedBox(height: 12),

              _dateField(
                icon: Icons.fact_check_outlined,
                label: 'Scadenza revisione',
                value: _inspectionExpiry,
                onTap: () => _pickDate(
                  'Revisione',
                  _inspectionExpiry,
                  (value) => _inspectionExpiry = value,
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                  hintText: 'Assicurazione, numero telaio, pneumatici...',
                ),
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  widget.isEditing
                      ? 'Salva modifiche'
                      : 'Salva veicolo',
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

cat > lib/screens/house/vehicle_detail_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_vehicle.dart';
import '../../services/vehicle_store.dart';
import 'add_vehicle_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  final HomeVehicle vehicle;

  const VehicleDetailScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late HomeVehicle _vehicle;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Non indicata';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatMileage(int? mileage) {
    if (mileage == null) return 'Non indicati';

    final raw = mileage.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(raw[i]);
    }

    return '${buffer.toString()} km';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Moto':
        return Icons.two_wheeler_outlined;
      case 'Scooter':
        return Icons.electric_scooter_outlined;
      case 'Bici':
      case 'E-bike':
        return Icons.pedal_bike_outlined;
      case 'Camper':
        return Icons.rv_hookup_outlined;
      default:
        return Icons.directions_car_outlined;
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<HomeVehicle>(
      context,
      MaterialPageRoute(
        builder: (_) => AddVehicleScreen(
          existingVehicle: _vehicle,
        ),
      ),
    );

    if (updated == null || !mounted) return;

    setState(() => _vehicle = updated);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare veicolo?'),
        content: Text(
          'Vuoi eliminare "${_vehicle.name}" da HomeLife?',
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

    await VehicleStore().delete(_vehicle.id);

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
      if (_vehicle.brand.trim().isNotEmpty) _vehicle.brand.trim(),
      if (_vehicle.model.trim().isNotEmpty) _vehicle.model.trim(),
    ].join(' ');

    return Scaffold(
      appBar: AppBar(
        title: Text(_vehicle.name),
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
                    _typeIcon(_vehicle.type),
                    size: 42,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _vehicle.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(_vehicle.type),
                  if (brandModel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(brandModel),
                  ],
                  if (_vehicle.plate.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _vehicle.plate,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            _infoRow(
              context,
              Icons.speed_outlined,
              'Chilometraggio',
              _formatMileage(_vehicle.mileage),
            ),

            _infoRow(
              context,
              Icons.calendar_today_outlined,
              'Anno',
              _vehicle.year?.toString() ?? 'Non indicato',
            ),

            _infoRow(
              context,
              Icons.shopping_bag_outlined,
              'Acquistato',
              _formatDate(_vehicle.purchaseDate),
            ),

            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),

            Text(
              'Scadenze',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            _infoRow(
              context,
              Icons.shield_outlined,
              'Assicurazione',
              _formatDate(_vehicle.insuranceExpiry),
            ),

            _infoRow(
              context,
              Icons.receipt_long_outlined,
              'Bollo',
              _formatDate(_vehicle.roadTaxExpiry),
            ),

            _infoRow(
              context,
              Icons.fact_check_outlined,
              'Revisione',
              _formatDate(_vehicle.inspectionExpiry),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifica veicolo'),
              ),
            ),

            if (_vehicle.notes.trim().isNotEmpty) ...[
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
                  child: Text(_vehicle.notes),
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

cat > lib/screens/house/vehicles_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_vehicle.dart';
import '../../services/vehicle_store.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _store = VehicleStore();

  bool _loading = true;
  List<HomeVehicle> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final vehicles = await _store.loadAll();

    if (!mounted) return;

    setState(() {
      _vehicles = vehicles;
      _loading = false;
    });
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Moto':
        return Icons.two_wheeler_outlined;
      case 'Scooter':
        return Icons.electric_scooter_outlined;
      case 'Bici':
      case 'E-bike':
        return Icons.pedal_bike_outlined;
      case 'Camper':
        return Icons.rv_hookup_outlined;
      default:
        return Icons.directions_car_outlined;
    }
  }

  Future<void> _add() async {
    final added = await Navigator.push<HomeVehicle>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddVehicleScreen(),
      ),
    );

    if (added != null) {
      await _reload();
    }
  }

  Future<void> _open(HomeVehicle vehicle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleDetailScreen(
          vehicle: vehicle,
        ),
      ),
    );

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Veicoli'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Veicolo'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              Text(
                'Auto, moto e altri mezzi della famiglia.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 22),

              if (_loading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (_vehicles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 50,
                        color:
                            Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Nessun veicolo registrato',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Aggiungi il primo veicolo della famiglia.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('Aggiungi veicolo'),
                      ),
                    ],
                  ),
                )
              else
                ..._vehicles.map(
                  (vehicle) {
                    final subtitle = [
                      vehicle.type,
                      if (vehicle.brand.trim().isNotEmpty)
                        vehicle.brand.trim(),
                      if (vehicle.model.trim().isNotEmpty)
                        vehicle.model.trim(),
                      if (vehicle.plate.trim().isNotEmpty)
                        vehicle.plate.trim(),
                    ].join(' • ');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: Icon(
                            _typeIcon(vehicle.type),
                          ),
                        ),
                        title: Text(
                          vehicle.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(subtitle),
                        trailing:
                            const Icon(Icons.chevron_right),
                        onTap: () => _open(vehicle),
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

# Replace HouseScreen with version that links Vehicles too.
cat > lib/screens/house/house_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../services/asset_store.dart';
import 'add_asset_screen.dart';
import 'asset_detail_screen.dart';
import 'maintenance_screen.dart';
import 'rooms_screen.dart';
import 'vehicles_screen.dart';

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

  Future<void> _openVehicles() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VehiclesScreen(),
      ),
    );
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
        leading: CircleAvatar(child: Icon(icon)),
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
              onTap: _openVehicles,
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
                      trailing:
                          const Icon(Icons.chevron_right),
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

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.6 installata."
echo "Ora esegui: flutter run"
