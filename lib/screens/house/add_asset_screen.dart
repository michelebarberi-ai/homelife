import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/home_room.dart';
import '../../services/asset_store.dart';
import '../../services/room_store.dart';

class AddAssetScreen extends StatefulWidget {
  final HomeAsset? existingAsset;
  final String? initialRoomId;

  const AddAssetScreen({
    super.key,
    this.existingAsset,
    this.initialRoomId,
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
  bool _loadingTemplates = true;

  List<HomeRoom> _rooms = [];
  List<HomeAsset> _templates = [];
  String? _selectedTemplateId;

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
    _roomId = asset?.roomId ?? widget.initialRoomId;

    _loadRooms();
    _loadTemplates();
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

  Future<void> _loadTemplates() async {
    final assets = await AssetStore().loadAssets();

    final seen = <String>{};
    final templates = <HomeAsset>[];

    for (final asset in assets) {
      if (widget.existingAsset?.id == asset.id) continue;

      final key = [
        asset.name.trim().toLowerCase(),
        asset.category.trim().toLowerCase(),
        asset.brand.trim().toLowerCase(),
        asset.model.trim().toLowerCase(),
      ].join('|');

      if (seen.add(key)) {
        templates.add(asset);
      }
    }

    templates.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    if (!mounted) return;

    setState(() {
      _templates = templates;
      _loadingTemplates = false;
    });
  }

  void _applyTemplate(HomeAsset template) {
    setState(() {
      _selectedTemplateId = template.id;
      _category = template.category;
    });

    _name.text = template.name;
    _brand.text = template.brand;
    _model.text = template.model;
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
        title: Text(
          widget.isEditing ? 'Modifica oggetto' : 'Nuovo oggetto',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              if (!widget.isEditing) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedTemplateId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Usa un oggetto già inserito',
                    prefixIcon: const Icon(Icons.auto_awesome_outlined),
                    helperText: _templates.isEmpty && !_loadingTemplates
                        ? 'Nessun oggetto disponibile come suggerimento'
                        : 'Opzionale: precompila nome, categoria, marca e modello',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Inserisci manualmente'),
                    ),
                    ..._templates.map(
                      (asset) => DropdownMenuItem<String?>(
                        value: asset.id,
                        child: Text(
                          [
                            asset.name,
                            if (asset.brand.trim().isNotEmpty)
                              asset.brand.trim(),
                          ].join(' • '),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: _loadingTemplates
                      ? null
                      : (value) {
                          setState(() {
                            _selectedTemplateId = value;
                          });

                          if (value == null) return;

                          HomeAsset? selected;
                          for (final asset in _templates) {
                            if (asset.id == value) {
                              selected = asset;
                              break;
                            }
                          }

                          if (selected != null) {
                            _applyTemplate(selected);
                          }
                        },
                ),
                const SizedBox(height: 14),
              ],

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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
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
