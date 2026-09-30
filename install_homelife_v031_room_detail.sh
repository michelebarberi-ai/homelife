#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🏠 HomeLife v0.3.1 — Dettaglio stanza"

mkdir -p lib/screens/house

# 1) AddAssetScreen: aggiunge initialRoomId per preassegnare la stanza
python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/house/add_asset_screen.dart")
text = p.read_text()

old = """class AddAssetScreen extends StatefulWidget {
  final HomeAsset? existingAsset;

  const AddAssetScreen({
    super.key,
    this.existingAsset,
  });

  bool get isEditing => existingAsset != null;
"""

new = """class AddAssetScreen extends StatefulWidget {
  final HomeAsset? existingAsset;
  final String? initialRoomId;

  const AddAssetScreen({
    super.key,
    this.existingAsset,
    this.initialRoomId,
  });

  bool get isEditing => existingAsset != null;
"""

if old in text:
    text = text.replace(old, new)
elif "final String? initialRoomId;" not in text:
    raise SystemExit("❌ Struttura AddAssetScreen non riconosciuta.")

old2 = """    _roomId = asset?.roomId;

    _loadRooms();
"""
new2 = """    _roomId = asset?.roomId ?? widget.initialRoomId;

    _loadRooms();
"""

if old2 in text:
    text = text.replace(old2, new2)
elif "widget.initialRoomId" not in text:
    raise SystemExit("❌ Inizializzazione stanza non riconosciuta.")

p.write_text(text)
PY

# 2) Nuova schermata dettaglio stanza
cat > lib/screens/house/room_detail_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/home_room.dart';
import '../../services/asset_store.dart';
import 'add_asset_screen.dart';
import 'asset_detail_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  final HomeRoom room;

  const RoomDetailScreen({
    super.key,
    required this.room,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final _assetStore = AssetStore();

  bool _loading = true;
  List<HomeAsset> _assets = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final allAssets = await _assetStore.loadAssets();

    if (!mounted) return;

    setState(() {
      _assets = allAssets
          .where((asset) => asset.roomId == widget.room.id)
          .toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      _loading = false;
    });
  }

  Future<void> _addAsset() async {
    final added = await Navigator.push<HomeAsset>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAssetScreen(
          initialRoomId: widget.room.id,
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAsset,
        icon: const Icon(Icons.add),
        label: const Text('Oggetto'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              Text(
                'Oggetti presenti in ${widget.room.name}.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 22),

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
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_assets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 46,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Nessun oggetto in questa stanza',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aggiungi il primo oggetto a ${widget.room.name}.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _addAsset,
                        icon: const Icon(Icons.add),
                        label: const Text('Aggiungi oggetto'),
                      ),
                    ],
                  ),
                )
              else
                ..._assets.map(
                  (asset) {
                    final info = [
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
                        subtitle: Text(info),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openAsset(asset),
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

# 3) RoomsScreen: rende cliccabili le stanze e apre RoomDetailScreen
python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/house/rooms_screen.dart")
text = p.read_text()

if "room_detail_screen.dart" not in text:
    marker = "import '../../services/room_store.dart';"
    text = text.replace(
        marker,
        marker + "\nimport 'room_detail_screen.dart';",
    )

needle = """                        trailing: PopupMenuButton<String>(
"""
replacement = """                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RoomDetailScreen(room: room),
                            ),
                          );
                          await _reload();
                        },
                        trailing: PopupMenuButton<String>(
"""

if needle in text and "RoomDetailScreen(room: room)" not in text:
    text = text.replace(needle, replacement, 1)
elif "RoomDetailScreen(room: room)" not in text:
    raise SystemExit("❌ Non riesco a collegare il tap sulle stanze.")

p.write_text(text)
PY

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.3.1 installata."
echo "Ora esegui: flutter run"
