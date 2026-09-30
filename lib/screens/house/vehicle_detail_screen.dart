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
