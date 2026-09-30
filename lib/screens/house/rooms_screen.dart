import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/home_room.dart';
import '../../services/asset_store.dart';
import '../../services/room_store.dart';
import 'room_detail_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _roomStore = RoomStore();
  final _assetStore = AssetStore();

  bool _loading = true;
  List<HomeRoom> _rooms = [];
  List<HomeAsset> _assets = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rooms = await _roomStore.loadRooms();
    final assets = await _assetStore.loadAssets();

    if (!mounted) return;

    setState(() {
      _rooms = rooms;
      _assets = assets;
      _loading = false;
    });
  }

  int _countAssets(String roomId) =>
      _assets.where((asset) => asset.roomId == roomId).length;

  IconData _iconFor(String key) {
    switch (key) {
      case 'living':
        return Icons.weekend_outlined;
      case 'kitchen':
        return Icons.kitchen_outlined;
      case 'bedroom':
        return Icons.bed_outlined;
      case 'bathroom':
        return Icons.bathtub_outlined;
      case 'garage':
        return Icons.garage_outlined;
      case 'garden':
        return Icons.park_outlined;
      case 'office':
        return Icons.desk_outlined;
      case 'laundry':
        return Icons.local_laundry_service_outlined;
      default:
        return Icons.meeting_room_outlined;
    }
  }

  Future<void> _showRoomEditor({HomeRoom? room}) async {
    final controller = TextEditingController(text: room?.name ?? '');
    String iconKey = room?.iconKey ?? 'room';

    final result = await showModalBottomSheet<HomeRoom>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottom = MediaQuery.of(context).viewInsets.bottom;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      room == null ? 'Nuova stanza' : 'Modifica stanza',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      autofocus: room == null,
                      decoration: const InputDecoration(
                        labelText: 'Nome stanza',
                        hintText: 'Es. Studio',
                        prefixIcon: Icon(Icons.meeting_room_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Icona',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ('room', Icons.meeting_room_outlined),
                        ('living', Icons.weekend_outlined),
                        ('kitchen', Icons.kitchen_outlined),
                        ('bedroom', Icons.bed_outlined),
                        ('bathroom', Icons.bathtub_outlined),
                        ('garage', Icons.garage_outlined),
                        ('garden', Icons.park_outlined),
                        ('office', Icons.desk_outlined),
                        ('laundry', Icons.local_laundry_service_outlined),
                      ].map((entry) {
                        final selected = iconKey == entry.$1;
                        return ChoiceChip(
                          selected: selected,
                          avatar: Icon(entry.$2, size: 18),
                          label: const Text(''),
                          onSelected: (_) {
                            setModalState(() => iconKey = entry.$1);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          final name = controller.text.trim();
                          if (name.isEmpty) return;

                          Navigator.pop(
                            sheetContext,
                            HomeRoom(
                              id: room?.id ??
                                  DateTime.now()
                                      .microsecondsSinceEpoch
                                      .toString(),
                              name: name,
                              iconKey: iconKey,
                            ),
                          );
                        },
                        child: Text(
                          room == null ? 'Aggiungi stanza' : 'Salva modifiche',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (result == null) return;

    if (room == null) {
      await _roomStore.addRoom(result);
    } else {
      await _roomStore.updateRoom(result);
    }

    await _reload();
  }

  Future<void> _deleteRoom(HomeRoom room) async {
    final used = _countAssets(room.id);

    if (used > 0) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stanza utilizzata'),
          content: Text(
            'Ci sono $used oggett${used == 1 ? 'o' : 'i'} assegnat${used == 1 ? 'o' : 'i'} a "${room.name}". '
            'Sposta prima gli oggetti in un’altra stanza.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare stanza?'),
        content: Text('Vuoi eliminare "${room.name}"?'),
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
      await _roomStore.deleteRoom(room.id);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stanze'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoomEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Stanza'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  Text(
                    'Organizza gli oggetti per ambiente.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 18),
                  ..._rooms.map((room) {
                    final count = _countAssets(room.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          child: Icon(_iconFor(room.iconKey)),
                        ),
                        title: Text(
                          room.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          count == 1 ? '1 oggetto' : '$count oggetti',
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RoomDetailScreen(room: room),
                            ),
                          );
                          await _reload();
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showRoomEditor(room: room);
                            } else if (value == 'delete') {
                              _deleteRoom(room);
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
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
