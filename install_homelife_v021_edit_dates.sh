#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🏠 HomeLife v0.2.1 — Modifica oggetti + date iOS"

# Localizzazioni Flutter per controlli/data in italiano
flutter pub add flutter_localizations --sdk=flutter

mkdir -p lib/services
mkdir -p lib/screens/house

cat > lib/services/asset_store.dart <<'DART'
import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_asset.dart';

class AssetStore {
  static const _key = 'homelife_assets_v1';

  Future<List<HomeAsset>> loadAssets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    final assets = raw
        .map((item) {
          try {
            return HomeAsset.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<HomeAsset>()
        .toList();

    assets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return assets;
  }

  Future<void> saveAssets(List<HomeAsset> assets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      assets.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> addAsset(HomeAsset asset) async {
    final assets = await loadAssets();
    assets.add(asset);
    await saveAssets(assets);
  }

  Future<void> updateAsset(HomeAsset updatedAsset) async {
    final assets = await loadAssets();
    final index = assets.indexWhere((asset) => asset.id == updatedAsset.id);

    if (index >= 0) {
      assets[index] = updatedAsset;
    } else {
      assets.add(updatedAsset);
    }

    await saveAssets(assets);
  }

  Future<void> deleteAsset(String id) async {
    final assets = await loadAssets();
    assets.removeWhere((asset) => asset.id == id);
    await saveAssets(assets);
  }
}
DART

cat > lib/screens/house/add_asset_screen.dart <<'DART'
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../services/asset_store.dart';

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

  bool _saving = false;

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
      showDragHandle: false,
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

    setState(() {
      _purchaseDate = result;
    });
  }

  Future<void> _pickWarrantyDate() async {
    final result = await _showIosDatePicker(
      title: 'Garanzia',
      currentValue: _warrantyExpiry,
      minimumDate: DateTime(1990, 1, 1),
      maximumDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );

    if (!mounted) return;

    setState(() {
      _warrantyExpiry = result;
    });
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
import '../../services/asset_store.dart';
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

  @override
  void initState() {
    super.initState();
    _asset = widget.asset;
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

# Modifica HouseScreen solo per adattare il tipo di ritorno dalla schermata Aggiungi.
python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/house/house_screen.dart")
text = p.read_text()

text = text.replace(
"""    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddAssetScreen(),
      ),
    );

    if (changed == true) {
      await _reload();
    }""",
"""    final added = await Navigator.push<HomeAsset>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddAssetScreen(),
      ),
    );

    if (added != null) {
      await _reload();
    }"""
)

p.write_text(text)
PY

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.2.1 installata."
echo "Avvia con: flutter run"
