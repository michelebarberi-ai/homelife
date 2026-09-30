#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "📁 HomeLife v0.5 — Archivio + fix pulsante Home"

mkdir -p lib/models
mkdir -p lib/services
mkdir -p lib/screens/archive

cat > lib/models/archive_document.dart <<'DART'
import 'dart:convert';

class ArchiveDocument {
  final String id;
  final String title;
  final String category;
  final String? assetId;
  final DateTime? documentDate;
  final DateTime? expiryDate;
  final String reference;
  final String notes;

  const ArchiveDocument({
    required this.id,
    required this.title,
    required this.category,
    this.assetId,
    this.documentDate,
    this.expiryDate,
    this.reference = '',
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'assetId': assetId,
        'documentDate': documentDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'reference': reference,
        'notes': notes,
      };

  factory ArchiveDocument.fromMap(Map<String, dynamic> map) {
    return ArchiveDocument(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      assetId: map['assetId'] as String?,
      documentDate: map['documentDate'] == null
          ? null
          : DateTime.tryParse(map['documentDate'] as String),
      expiryDate: map['expiryDate'] == null
          ? null
          : DateTime.tryParse(map['expiryDate'] as String),
      reference: (map['reference'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ArchiveDocument.fromJson(String source) =>
      ArchiveDocument.fromMap(
        jsonDecode(source) as Map<String, dynamic>,
      );
}
DART

cat > lib/services/archive_store.dart <<'DART'
import 'package:shared_preferences/shared_preferences.dart';

import '../models/archive_document.dart';

class ArchiveStore {
  static const _key = 'homelife_archive_documents_v1';

  Future<List<ArchiveDocument>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    final documents = raw
        .map((item) {
          try {
            return ArchiveDocument.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<ArchiveDocument>()
        .toList();

    documents.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );

    return documents;
  }

  Future<void> saveAll(List<ArchiveDocument> documents) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      documents.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> add(ArchiveDocument document) async {
    final documents = await loadAll();
    documents.add(document);
    await saveAll(documents);
  }

  Future<void> update(ArchiveDocument updated) async {
    final documents = await loadAll();
    final index = documents.indexWhere((item) => item.id == updated.id);

    if (index >= 0) {
      documents[index] = updated;
    } else {
      documents.add(updated);
    }

    await saveAll(documents);
  }

  Future<void> delete(String id) async {
    final documents = await loadAll();
    documents.removeWhere((item) => item.id == id);
    await saveAll(documents);
  }
}
DART

cat > lib/screens/archive/add_document_screen.dart <<'DART'
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/archive_document.dart';
import '../../models/home_asset.dart';
import '../../services/archive_store.dart';
import '../../services/asset_store.dart';

class AddDocumentScreen extends StatefulWidget {
  final ArchiveDocument? existingDocument;
  final String? initialAssetId;

  const AddDocumentScreen({
    super.key,
    this.existingDocument,
    this.initialAssetId,
  });

  bool get isEditing => existingDocument != null;

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _reference;
  late final TextEditingController _notes;

  late String _category;
  String? _assetId;
  DateTime? _documentDate;
  DateTime? _expiryDate;

  bool _saving = false;
  bool _loadingAssets = true;
  List<HomeAsset> _assets = [];

  static const _categories = [
    'Fattura',
    'Garanzia',
    'Manuale',
    'Contratto',
    'Assicurazione',
    'Bolletta',
    'Ricevuta',
    'Certificato',
    'Altro',
  ];

  @override
  void initState() {
    super.initState();

    final doc = widget.existingDocument;

    _title = TextEditingController(text: doc?.title ?? '');
    _reference = TextEditingController(text: doc?.reference ?? '');
    _notes = TextEditingController(text: doc?.notes ?? '');

    _category = doc?.category ?? 'Fattura';
    _assetId = doc?.assetId ?? widget.initialAssetId;
    _documentDate = doc?.documentDate;
    _expiryDate = doc?.expiryDate;

    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final assets = await AssetStore().loadAssets();

    if (!mounted) return;

    setState(() {
      _assets = assets;
      _loadingAssets = false;

      if (_assetId != null &&
          !_assets.any((asset) => asset.id == _assetId)) {
        _assetId = null;
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Nessuna data';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<DateTime?> _showDatePicker({
    required String title,
    required DateTime? currentValue,
    required bool allowNone,
  }) async {
    DateTime tempDate = currentValue ?? DateTime.now();

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
                      if (allowNone)
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, null),
                          child: const Text('Nessuna data'),
                        )
                      else
                        const SizedBox(width: 110),
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
                    dateOrder: DatePickerDateOrder.dmy,
                    minimumDate: DateTime(1990, 1, 1),
                    maximumDate:
                        DateTime.now().add(const Duration(days: 365 * 30)),
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

  Future<void> _pickDocumentDate() async {
    final value = await _showDatePicker(
      title: 'Data documento',
      currentValue: _documentDate,
      allowNone: true,
    );

    if (!mounted) return;
    setState(() => _documentDate = value);
  }

  Future<void> _pickExpiryDate() async {
    final value = await _showDatePicker(
      title: 'Scadenza',
      currentValue: _expiryDate,
      allowNone: true,
    );

    if (!mounted) return;
    setState(() => _expiryDate = value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final document = ArchiveDocument(
      id: widget.existingDocument?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      category: _category,
      assetId: _assetId,
      documentDate: _documentDate,
      expiryDate: _expiryDate,
      reference: _reference.text.trim(),
      notes: _notes.text.trim(),
    );

    if (widget.isEditing) {
      await ArchiveStore().update(document);
    } else {
      await ArchiveStore().add(document);
    }

    if (!mounted) return;
    Navigator.pop(context, document);
  }

  Widget _dateField({
    required IconData icon,
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
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
                        fontWeight: value == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color:
                            value == null ? Colors.grey.shade600 : null,
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
          widget.isEditing ? 'Modifica documento' : 'Nuovo documento',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Titolo',
                  hintText: 'Es. Fattura lavastoviglie',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci un titolo';
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
                initialValue: _assetId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Collegato a',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Casa / documento generale'),
                  ),
                  ..._assets.map(
                    (asset) => DropdownMenuItem<String?>(
                      value: asset.id,
                      child: Text(
                        asset.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: _loadingAssets
                    ? null
                    : (value) {
                        setState(() => _assetId = value);
                      },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Numero / riferimento',
                  hintText: 'Opzionale',
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 14),

              _dateField(
                icon: Icons.event_note_outlined,
                label: 'Data documento',
                value: _documentDate,
                onTap: _pickDocumentDate,
              ),
              const SizedBox(height: 12),

              _dateField(
                icon: Icons.notifications_active_outlined,
                label: 'Scadenza',
                value: _expiryDate,
                onTap: _pickExpiryDate,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                  hintText: 'Dettagli utili sul documento...',
                ),
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.attach_file),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Allegato PDF o foto: lo aggiungiamo nel prossimo step.',
                      ),
                    ),
                  ],
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
                    : const Icon(Icons.save_outlined),
                label: Text(
                  widget.isEditing
                      ? 'Salva modifiche'
                      : 'Salva documento',
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

cat > lib/screens/archive/archive_screen.dart <<'DART'
import 'package:flutter/material.dart';

import '../../models/archive_document.dart';
import '../../models/home_asset.dart';
import '../../services/archive_store.dart';
import '../../services/asset_store.dart';
import 'add_document_screen.dart';

class ArchiveScreen extends StatefulWidget {
  final String? assetIdFilter;
  final String? assetName;

  const ArchiveScreen({
    super.key,
    this.assetIdFilter,
    this.assetName,
  });

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final _store = ArchiveStore();

  bool _loading = true;
  List<ArchiveDocument> _documents = [];
  List<HomeAsset> _assets = [];

  String _filter = 'Tutti';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final documents = await _store.loadAll();
    final assets = await AssetStore().loadAssets();

    if (!mounted) return;

    setState(() {
      _assets = assets;
      _documents = widget.assetIdFilter == null
          ? documents
          : documents
              .where((item) => item.assetId == widget.assetIdFilter)
              .toList();
      _loading = false;
    });
  }

  String _assetName(String? assetId) {
    if (assetId == null) return 'Casa';

    for (final asset in _assets) {
      if (asset.id == assetId) return asset.name;
    }

    return 'Oggetto non disponibile';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Fattura':
        return Icons.receipt_long_outlined;
      case 'Garanzia':
        return Icons.verified_outlined;
      case 'Manuale':
        return Icons.menu_book_outlined;
      case 'Contratto':
        return Icons.contract_outlined;
      case 'Assicurazione':
        return Icons.shield_outlined;
      case 'Bolletta':
        return Icons.bolt_outlined;
      case 'Ricevuta':
        return Icons.receipt_outlined;
      case 'Certificato':
        return Icons.workspace_premium_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Future<void> _add() async {
    final added = await Navigator.push<ArchiveDocument>(
      context,
      MaterialPageRoute(
        builder: (_) => AddDocumentScreen(
          initialAssetId: widget.assetIdFilter,
        ),
      ),
    );

    if (added != null) {
      await _reload();
    }
  }

  Future<void> _edit(ArchiveDocument document) async {
    final updated = await Navigator.push<ArchiveDocument>(
      context,
      MaterialPageRoute(
        builder: (_) => AddDocumentScreen(
          existingDocument: document,
        ),
      ),
    );

    if (updated != null) {
      await _reload();
    }
  }

  Future<void> _delete(ArchiveDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare documento?'),
        content: Text('Vuoi eliminare "${document.title}"?'),
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
      await _store.delete(document.id);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>[
      'Tutti',
      ...{
        for (final doc in _documents) doc.category,
      },
    ];

    final visible = _filter == 'Tutti'
        ? _documents
        : _documents.where((doc) => doc.category == _filter).toList();

    return SafeArea(
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Documento'),
        ),
        body: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Archivio',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  if (widget.assetName == null)
                    FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                      label: const Text('Documento'),
                    ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                widget.assetName == null
                    ? 'Documenti, fatture, garanzie e contratti.'
                    : 'Documenti collegati a ${widget.assetName}.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),

              if (widget.assetName != null) ...[
                const SizedBox(height: 10),
                Text(
                  widget.assetName!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],

              const SizedBox(height: 18),

              if (_documents.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: _filter == category,
                          label: Text(category),
                          onSelected: (_) {
                            setState(() => _filter = category);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 18),

              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (visible.isEmpty)
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Nessun documento',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Aggiungi il primo documento all’archivio.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('Aggiungi documento'),
                      ),
                    ],
                  ),
                )
              else
                ...visible.map(
                  (document) {
                    final meta = <String>[
                      document.category,
                      _assetName(document.assetId),
                      if (document.expiryDate != null)
                        'Scade ${_formatDate(document.expiryDate)}',
                    ];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: Icon(
                            _categoryIcon(document.category),
                          ),
                        ),
                        title: Text(
                          document.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(meta.join('\n')),
                        isThreeLine: meta.length >= 3,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _edit(document);
                            } else if (value == 'delete') {
                              _delete(document);
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
                        onTap: () => _edit(document),
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

# Collega Documenti nella scheda oggetto
python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/house/asset_detail_screen.dart")
text = p.read_text()

if "../archive/archive_screen.dart" not in text:
    text = text.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\n\nimport '../archive/archive_screen.dart';",
        1,
    )

if "Future<void> _openDocuments()" not in text:
    anchor = """  Future<void> _openMaintenance() async {
"""
    insert = """  Future<void> _openDocuments() async {
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

"""
    text = text.replace(anchor, insert + anchor, 1)

old = """                  const ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('Documenti'),
                    subtitle:
                        Text('Fatture, manuali e garanzie'),
                    trailing: Text('Prossimamente'),
                  ),"""

new = """                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Documenti'),
                    subtitle:
                        const Text('Fatture, manuali e garanzie'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openDocuments,
                  ),"""

if old not in text:
    raise SystemExit("❌ Non trovo il blocco Documenti in asset_detail_screen.dart")

text = text.replace(old, new, 1)
p.write_text(text)
PY

# Aggiunge spazio sotto Chiedi a HomeLife per non farlo coprire dal FAB
python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/home/home_screen.dart")
text = p.read_text()

needle = """            Container(
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
            ),"""

replacement = needle + """
            const SizedBox(height: 90),"""

if "const SizedBox(height: 90)," not in text:
    if needle not in text:
        raise SystemExit("❌ Non trovo la card Chiedi a HomeLife.")
    text = text.replace(needle, replacement, 1)

p.write_text(text)
PY

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.5 installata."
echo "Ora esegui: flutter run"
