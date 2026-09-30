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
