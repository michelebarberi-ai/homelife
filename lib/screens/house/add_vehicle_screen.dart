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
