#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

mkdir -p lib/screens/house

cat > lib/screens/house/house_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../services/asset_store.dart';
import 'add_asset_screen.dart';
import 'asset_detail_screen.dart';
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
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(asset: asset),
      ),
    );

    if (changed == true) {
      await _reload();
    } else {
      // Ricarica comunque: l'oggetto potrebbe essere stato modificato.
      await _reload();
    }
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
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                    if (asset.brand.trim().isNotEmpty) asset.brand.trim(),
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

echo "🔎 flutter analyze"
flutter analyze

echo ""
echo "✅ Casa → Stanze collegato correttamente."
echo "Ora esegui: flutter run"
