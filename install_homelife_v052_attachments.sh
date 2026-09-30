#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "📎 HomeLife v0.5.2 — Allegati PDF/immagini"

flutter pub add file_picker
flutter pub add path_provider
flutter pub add open_filex

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
  final String? attachmentPath;
  final String? attachmentName;

  const ArchiveDocument({
    required this.id,
    required this.title,
    required this.category,
    this.assetId,
    this.documentDate,
    this.expiryDate,
    this.reference = '',
    this.notes = '',
    this.attachmentPath,
    this.attachmentName,
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
        'attachmentPath': attachmentPath,
        'attachmentName': attachmentName,
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
      attachmentPath: map['attachmentPath'] as String?,
      attachmentName: map['attachmentName'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ArchiveDocument.fromJson(String source) =>
      ArchiveDocument.fromMap(
        jsonDecode(source) as Map<String, dynamic>,
      );
}
DART

cat > lib/services/archive_attachment_service.dart <<'DART'
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class ArchiveAttachmentResult {
  final String path;
  final String name;

  const ArchiveAttachmentResult({
    required this.path,
    required this.name,
  });
}

class ArchiveAttachmentService {
  Future<ArchiveAttachmentResult?> pickAndStore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'heic',
      ],
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final sourcePath = picked.path;

    if (sourcePath == null) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final archiveDir = Directory(
      '${docsDir.path}/homelife_archive',
    );

    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }

    final safeName = picked.name.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );

    final targetPath =
        '${archiveDir.path}/${DateTime.now().microsecondsSinceEpoch}_$safeName';

    final source = File(sourcePath);
    final copied = await source.copy(targetPath);

    return ArchiveAttachmentResult(
      path: copied.path,
      name: picked.name,
    );
  }

  Future<void> deleteIfExists(String? path) async {
    if (path == null || path.isEmpty) return;

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
DART

cat > lib/screens/archive/add_document_screen.dart <<'DART'
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/archive_document.dart';
import '../../models/home_asset.dart';
import '../../services/archive_attachment_service.dart';
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
  final _attachmentService = ArchiveAttachmentService();

  late final TextEditingController _title;
  late final TextEditingController _reference;
  late final TextEditingController _notes;

  late String _category;
  String? _assetId;
  DateTime? _documentDate;
  DateTime? _expiryDate;

  String? _attachmentPath;
  String? _attachmentName;

  bool _saving = false;
  bool _loadingAssets = true;
  bool _pickingAttachment = false;

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

    _attachmentPath = doc?.attachmentPath;
    _attachmentName = doc?.attachmentName;

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
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, null),
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
    );

    if (!mounted) return;
    setState(() => _documentDate = value);
  }

  Future<void> _pickExpiryDate() async {
    final value = await _showDatePicker(
      title: 'Scadenza',
      currentValue: _expiryDate,
    );

    if (!mounted) return;
    setState(() => _expiryDate = value);
  }

  Future<void> _pickAttachment() async {
    setState(() => _pickingAttachment = true);

    try {
      final result = await _attachmentService.pickAndStore();

      if (result == null || !mounted) return;

      final oldPath = _attachmentPath;

      setState(() {
        _attachmentPath = result.path;
        _attachmentName = result.name;
      });

      if (oldPath != null &&
          oldPath != widget.existingDocument?.attachmentPath) {
        await _attachmentService.deleteIfExists(oldPath);
      }
    } finally {
      if (mounted) {
        setState(() => _pickingAttachment = false);
      }
    }
  }

  Future<void> _removeAttachment() async {
    final path = _attachmentPath;

    setState(() {
      _attachmentPath = null;
      _attachmentName = null;
    });

    if (path != null &&
        path != widget.existingDocument?.attachmentPath) {
      await _attachmentService.deleteIfExists(path);
    }
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
      attachmentPath: _attachmentPath,
      attachmentName: _attachmentName,
    );

    if (widget.isEditing) {
      await ArchiveStore().update(document);

      final oldPath = widget.existingDocument?.attachmentPath;
      if (oldPath != null && oldPath != _attachmentPath) {
        await _attachmentService.deleteIfExists(oldPath);
      }
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

  Widget _attachmentCard() {
    final hasAttachment =
        _attachmentPath != null && _attachmentName != null;

    if (!hasAttachment) {
      return OutlinedButton.icon(
        onPressed: _pickingAttachment ? null : _pickAttachment,
        icon: _pickingAttachment
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.attach_file),
        label: const Text('Allega PDF o immagine'),
      );
    }

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.attach_file),
        ),
        title: Text(
          _attachmentName!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: const Text('Allegato salvato in HomeLife'),
        trailing: IconButton(
          tooltip: 'Rimuovi allegato',
          onPressed: _removeAttachment,
          icon: const Icon(Icons.close),
        ),
        onTap: _pickAttachment,
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
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

              _attachmentCard(),

              const SizedBox(height: 28),

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

# Aggiunge apertura allegato e icona graffetta nella lista Archivio
python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/archive/archive_screen.dart")
text = p.read_text()

if "package:open_filex/open_filex.dart" not in text:
    text = text.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:open_filex/open_filex.dart';",
        1,
    )

if "Future<void> _openAttachment" not in text:
    anchor = """  Future<void> _delete(ArchiveDocument document) async {
"""
    method = """  Future<void> _openAttachment(
    ArchiveDocument document,
  ) async {
    final path = document.attachmentPath;
    if (path == null || path.isEmpty) {
      await _edit(document);
      return;
    }

    await OpenFilex.open(path);
  }

"""
    text = text.replace(anchor, method + anchor, 1)

old_trailing = """                        trailing: PopupMenuButton<String>(
"""
new_trailing = """                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (document.attachmentPath != null)
                              IconButton(
                                tooltip: 'Apri allegato',
                                onPressed: () => _openAttachment(document),
                                icon: const Icon(Icons.attach_file),
                              ),
                            PopupMenuButton<String>(
"""

if old_trailing not in text:
    raise SystemExit("❌ Non trovo trailing dei documenti.")
text = text.replace(old_trailing, new_trailing, 1)

old_menu_end = """                          ],
                        ),
                        onTap: () => _edit(document),
"""

new_menu_end = """                          ],
                            ),
                          ],
                        ),
                        onTap: () => document.attachmentPath != null
                            ? _openAttachment(document)
                            : _edit(document),
"""

if old_menu_end not in text:
    raise SystemExit("❌ Non trovo chiusura menu documento.")
text = text.replace(old_menu_end, new_menu_end, 1)

p.write_text(text)
PY

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.5.2 installata."
echo "Ora esegui: flutter run"
