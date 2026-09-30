#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🏠 HomeLife v0.3 — Stanze + assegnazione oggetti"

mkdir -p lib/models
mkdir -p lib/services
mkdir -p lib/screens/house

cat > lib/models/home_room.dart <<'DART'
import 'dart:convert';

class HomeRoom {
  final String id;
  final String name;
  final String iconKey;

  const HomeRoom({
    required this.id,
    required this.name,
    this.iconKey = 'room',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
      };

  factory HomeRoom.fromMap(Map<String, dynamic> map) {
    return HomeRoom(
      id: map['id'] as String,
      name: map['name'] as String,
      iconKey: (map['iconKey'] as String?) ?? 'room',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory HomeRoom.fromJson(String source) =>
      HomeRoom.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
DART

cat > lib/models/home_asset.dart <<'DART'
import 'dart:convert';

class HomeAsset {
  final String id;
  final String name;
  final String category;
  final String brand;
  final String model;
  final DateTime? purchaseDate;
  final double? price;
  final DateTime? warrantyExpiry;
  final String notes;
  final String? roomId;

  const HomeAsset({
    required this.id,
    required this.name,
    required this.category,
    this.brand = '',
    this.model = '',
    this.purchaseDate,
    this.price,
    this.warrantyExpiry,
    this.notes = '',
    this.roomId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'brand': brand,
        'model': model,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'price': price,
        'warrantyExpiry': warrantyExpiry?.toIso8601String(),
        'notes': notes,
        'roomId': roomId,
      };

  factory HomeAsset.fromMap(Map<String, dynamic> map) {
    return HomeAsset(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      brand: (map['brand'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      purchaseDate: map['purchaseDate'] == null
          ? null
          : DateTime.tryParse(map['purchaseDate'] as String),
      price: (map['price'] as num?)?.toDouble(),
      warrantyExpiry: map['warrantyExpiry'] == null
          ? null
          : DateTime.tryParse(map['warrantyExpiry'] as String),
      notes: (map['notes'] as String?) ?? '',
      roomId: map['roomId'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory HomeAsset.fromJson(String source) =>
      HomeAsset.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
DART

cat > lib/services/room_store.dart <<'DART'
import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_room.dart';

class RoomStore {
  static const _key = 'homelife_rooms_v1';

  Future<List<HomeRoom>> loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);

    if (raw == null) {
      final defaults = <HomeRoom>[
        const HomeRoom(id: 'default_living', name: 'Soggiorno', iconKey: 'living'),
        const HomeRoom(id: 'default_kitchen', name: 'Cucina', iconKey: 'kitchen'),
        const HomeRoom(id: 'default_bedroom', name: 'Camera', iconKey: 'bedroom'),
        const HomeRoom(id: 'default_bathroom', name: 'Bagno', iconKey: 'bathroom'),
        const HomeRoom(id: 'default_garage', name: 'Garage', iconKey: 'garage'),
      ];
      await saveRooms(defaults);
      return defaults;
    }

    final rooms = raw
        .map((item) {
          try {
            return HomeRoom.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<HomeRoom>()
        .toList();

    rooms.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rooms;
  }

  Future<void> saveRooms(List<HomeRoom> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      rooms.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> addRoom(HomeRoom room) async {
    final rooms = await loadRooms();
    rooms.add(room);
    await saveRooms(rooms);
  }

  Future<void> updateRoom(HomeRoom updated) async {
    final rooms = await loadRooms();
    final index = rooms.indexWhere((room) => room.id == updated.id);
    if (index >= 0) {
      rooms[index] = updated;
    } else {
      rooms.add(updated);
    }
    await saveRooms(rooms);
  }

  Future<void> deleteRoom(String id) async {
    final rooms = await loadRooms();
    rooms.removeWhere((room) => room.id == id);
    await saveRooms(rooms);
  }
}
DART

cat > lib/screens/house/rooms_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/home_room.dart';
import '../../services/asset_store.dart';
import '../../services/room_store.dart';

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
DART

cat > lib/screens/house/add_asset_screen.dart <<'DART'
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/home_room.dart';
import '../../services/asset_store.dart';
import '../../services/room_store.dart';

class AddAssetScreen extends StatefulWidget {
  final HomeAsset? existingAsset;

  const AddAssetScreen({
    super.key,
    this.existingAsset,
  });

  bool get isEditing => existingAsset != null;

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _price;
  late final TextEditingController _notes;

  late String _category;
  DateTime? _purchaseDate;
  DateTime? _warrantyExpiry;
  String? _roomId;

  bool _saving = false;
  bool _loadingRooms = true;
  List<HomeRoom> _rooms = [];

  static const _categories = [
    'Elettrodomestico',
    'Elettronica',
    'Impianto',
    'Arredamento',
    'Giardino',
    'Piscina',
    'Sicurezza',
    'Smart Home',
    'Altro',
  ];

  @override
  void initState() {
    super.initState();

    final asset = widget.existingAsset;

    _name = TextEditingController(text: asset?.name ?? '');
    _brand = TextEditingController(text: asset?.brand ?? '');
    _model = TextEditingController(text: asset?.model ?? '');
    _price = TextEditingController(
      text: asset?.price == null
          ? ''
          : asset!.price!.toStringAsFixed(2).replaceAll('.', ','),
    );
    _notes = TextEditingController(text: asset?.notes ?? '');

    _category = asset?.category ?? 'Elettrodomestico';
    _purchaseDate = asset?.purchaseDate;
    _warrantyExpiry = asset?.warrantyExpiry;
    _roomId = asset?.roomId;

    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final rooms = await RoomStore().loadRooms();
    if (!mounted) return;

    setState(() {
      _rooms = rooms;
      _loadingRooms = false;

      if (_roomId != null &&
          !_rooms.any((room) => room.id == _roomId)) {
        _roomId = null;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _model.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Nessuna data';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<DateTime?> _showIosDatePicker({
    required String title,
    required DateTime? currentValue,
    DateTime? minimumDate,
    DateTime? maximumDate,
  }) async {
    DateTime tempDate = currentValue ?? DateTime.now();

    if (minimumDate != null && tempDate.isBefore(minimumDate)) {
      tempDate = minimumDate;
    }
    if (maximumDate != null && tempDate.isAfter(maximumDate)) {
      tempDate = maximumDate;
    }

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
                        onPressed: () => Navigator.pop(sheetContext, null),
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
                    minimumDate: minimumDate,
                    maximumDate: maximumDate,
                    dateOrder: DatePickerDateOrder.dmy,
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

  Future<void> _pickPurchaseDate() async {
    final result = await _showIosDatePicker(
      title: 'Data acquisto',
      currentValue: _purchaseDate,
      minimumDate: DateTime(1990, 1, 1),
      maximumDate: DateTime.now(),
    );

    if (!mounted) return;
    setState(() => _purchaseDate = result);
  }

  Future<void> _pickWarrantyDate() async {
    final result = await _showIosDatePicker(
      title: 'Garanzia',
      currentValue: _warrantyExpiry,
      minimumDate: DateTime(1990, 1, 1),
      maximumDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );

    if (!mounted) return;
    setState(() => _warrantyExpiry = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final normalizedPrice = _price.text.trim().replaceAll(',', '.');
    final parsedPrice =
        normalizedPrice.isEmpty ? null : double.tryParse(normalizedPrice);

    final asset = HomeAsset(
      id: widget.existingAsset?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      category: _category,
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      purchaseDate: _purchaseDate,
      price: parsedPrice,
      warrantyExpiry: _warrantyExpiry,
      notes: _notes.text.trim(),
      roomId: _roomId,
    );

    if (widget.isEditing) {
      await AssetStore().updateAsset(asset);
    } else {
      await AssetStore().addAsset(asset);
    }

    if (!mounted) return;
    Navigator.pop(context, asset);
  }

  Widget _dateField({
    required IconData icon,
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final hasDate = value != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
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
                        fontWeight:
                            hasDate ? FontWeight.w600 : FontWeight.w400,
                        color: hasDate ? null : Colors.grey.shade600,
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
        title: Text(widget.isEditing ? 'Modifica oggetto' : 'Nuovo oggetto'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Es. Lavastoviglie cucina',
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

              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categories
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String?>(
                initialValue: _roomId,
                decoration: const InputDecoration(
                  labelText: 'Stanza',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Nessuna stanza'),
                  ),
                  ..._rooms.map(
                    (room) => DropdownMenuItem<String?>(
                      value: room.id,
                      child: Text(room.name),
                    ),
                  ),
                ],
                onChanged: _loadingRooms
                    ? null
                    : (value) {
                        setState(() => _roomId = value);
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
                        hintText: 'Bosch',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _model,
                      decoration: const InputDecoration(
                        labelText: 'Modello',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Prezzo di acquisto',
                  prefixIcon: Icon(Icons.euro),
                  hintText: '649,00',
                ),
              ),
              const SizedBox(height: 14),

              _dateField(
                icon: Icons.shopping_bag_outlined,
                label: 'Data di acquisto',
                value: _purchaseDate,
                onTap: _pickPurchaseDate,
              ),
              const SizedBox(height: 12),

              _dateField(
                icon: Icons.verified_outlined,
                label: 'Scadenza garanzia',
                value: _warrantyExpiry,
                onTap: _pickWarrantyDate,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                  hintText: 'Informazioni utili, matricola, posizione...',
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
                    : Icon(
                        widget.isEditing
                            ? Icons.check
                            : Icons.save_outlined,
                      ),
                label: Text(
                  _saving
                      ? 'Salvataggio...'
                      : widget.isEditing
                          ? 'Salva modifiche'
                          : 'Salva oggetto',
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

cat > lib/screens/house/asset_detail_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/home_room.dart';
import '../../services/asset_store.dart';
import '../../services/room_store.dart';
import 'add_asset_screen.dart';

class AssetDetailScreen extends StatefulWidget {
  final HomeAsset asset;

  const AssetDetailScreen({
    super.key,
    required this.asset,
  });

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
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
        builder: (_) => AddAssetScreen(existingAsset: _asset),
      ),
    );

    if (updated == null || !mounted) return;

    setState(() {
      _asset = updated;
    });
    await _loadRoom();
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
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 38),
                  const SizedBox(height: 18),
                  Text(
                    _asset.name,
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),

            const Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('Documenti'),
                    subtitle: Text('Fatture, manuali e garanzie'),
                    trailing: Text('Prossimamente'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.home_repair_service_outlined),
                    title: Text('Manutenzioni'),
                    subtitle: Text('Storico e prossimi interventi'),
                    trailing: Text('Prossimamente'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.sensors_outlined),
                    title: Text('Smart Home'),
                    subtitle: Text('Stato e controllo dispositivo'),
                    trailing: Text('Prossimamente'),
                  ),
                ],
              ),
            ),

            if (_asset.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Note',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

# Aggiorna house_screen.dart inserendo navigazione a Stanze.
python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/house/house_screen.dart")
text = p.read_text()

if "rooms_screen.dart" not in text:
    text = text.replace(
        "import 'asset_detail_screen.dart';",
        "import 'asset_detail_screen.dart';\nimport 'rooms_screen.dart';"
    )

old = """  Widget _topTile(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }"""

new = """  Widget _topTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }"""

if old in text:
    text = text.replace(old, new)

old_tile = """            _topTile(
              Icons.grid_view_rounded,
              'Stanze',
              'Organizza casa per ambienti',
            ),"""

new_tile = """            _topTile(
              Icons.grid_view_rounded,
              'Stanze',
              'Organizza casa per ambienti',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RoomsScreen(),
                  ),
                );
                await _reload();
              },
            ),"""

if old_tile in text:
    text = text.replace(old_tile, new_tile)

p.write_text(text)
PY

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.3 installata."
echo "Ora esegui: flutter run"
