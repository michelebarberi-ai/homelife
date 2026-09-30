#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🏠 HomeLife v0.4.1 — Scadenze manutenzioni in Home"

mkdir -p lib/screens/home

cat > lib/screens/home/home_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/maintenance_record.dart';
import '../../services/asset_store.dart';
import '../../services/maintenance_store.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/home_card.dart';
import '../../widgets/section_title.dart';
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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final records = await MaintenanceStore().loadAll();
    final assets = await AssetStore().loadAssets();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = records
        .where((record) {
          final due = record.nextDueDate;
          if (due == null) return false;

          final normalized = DateTime(due.year, due.month, due.day);
          return !normalized.isBefore(today);
        })
        .toList()
      ..sort((a, b) {
        return a.nextDueDate!.compareTo(b.nextDueDate!);
      });

    if (!mounted) return;

    setState(() {
      _upcomingMaintenance = upcoming;
      _assets = assets;
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

    if (days == 0) return 'Scade oggi';
    if (days == 1) return 'Scade domani';
    if (days < 7) return 'Scade tra $days giorni';
    if (days < 30) return 'Scade tra ${(days / 7).floor()} settimane';

    return 'Scadenza ${_formatDate(due)}';
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

            const SectionTitle(title: 'Oggi'),

            const HomeCard(
              icon: Icons.calendar_today,
              title: '17:30',
              subtitle: 'Allenamento',
            ),

            const HomeCard(
              icon: Icons.inventory_2_outlined,
              title: '19:00',
              subtitle: 'Ritirare pacco',
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._upcomingMaintenance.take(4).map(
                (record) {
                  final due = record.nextDueDate!;
                  final assetName = _assetName(record.assetId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: const CircleAvatar(
                        child: Icon(
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
                        '$assetName • ${_relativeDueText(due)}',
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
              children: const [
                Expanded(
                  child: DashboardCard(
                    icon: Icons.build_circle_outlined,
                    value: '3',
                    label: 'Manutenzioni',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: DashboardCard(
                    icon: Icons.verified_outlined,
                    value: '2',
                    label: 'Garanzie',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const SectionTitle(title: 'Questo mese'),

            const HomeCard(
              icon: Icons.euro,
              title: '€ 1.426',
              subtitle: 'Spese registrate',
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
echo "✅ HomeLife v0.4.1 installata."
echo "Ora esegui: flutter run"
