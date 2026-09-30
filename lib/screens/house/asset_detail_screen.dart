import 'package:flutter/material.dart';

import '../archive/archive_screen.dart';

import '../../models/home_asset.dart';
import '../../models/home_room.dart';
import '../../services/asset_store.dart';
import '../../services/room_store.dart';
import 'add_asset_screen.dart';
import 'maintenance_screen.dart';
import 'smart_home_screen.dart';

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

  Future<void> _openDocuments() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveScreen(
          assetIdFilter: _asset.id,
          assetName: _asset.name,
        ),
      ),
    );
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

  Future<void> _openSmartHome() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SmartHomeScreen(),
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
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Documenti'),
                    subtitle:
                        const Text('Fatture, manuali e garanzie'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openDocuments,
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
                  ListTile(
                    leading: const Icon(Icons.sensors_outlined),
                    title: const Text('Smart Home'),
                    subtitle:
                        const Text('Stato e controllo dispositivo'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openSmartHome,
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
