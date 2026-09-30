#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "📷 HomeLife v0.5.4 — Fotocamera + anteprima allegato"

mkdir -p lib/services
mkdir -p lib/screens/archive

cat > lib/services/archive_attachment_service.dart <<'DART'
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _imagePicker = ImagePicker();

  Future<ArchiveAttachmentResult?> pickFileAndStore() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'heic',
      ],
    );

    if (picked == null || picked.path == null) return null;

    return _copyIntoArchive(
      sourcePath: picked.path!,
      originalName: picked.name,
    );
  }

  Future<ArchiveAttachmentResult?> pickPhotoAndStore() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (picked == null) return null;

    return _copyIntoArchive(
      sourcePath: picked.path,
      originalName: picked.name.isEmpty
          ? 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : picked.name,
    );
  }

  Future<ArchiveAttachmentResult?> takePhotoAndStore() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (picked == null) return null;

    return _copyIntoArchive(
      sourcePath: picked.path,
      originalName:
          'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  Future<ArchiveAttachmentResult> _copyIntoArchive({
    required String sourcePath,
    required String originalName,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final archiveDir = Directory(
      '${docsDir.path}/homelife_archive',
    );

    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }

    final safeName = originalName.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );

    final targetPath =
        '${archiveDir.path}/${DateTime.now().microsecondsSinceEpoch}_$safeName';

    final copied = await File(sourcePath).copy(targetPath);

    return ArchiveAttachmentResult(
      path: copied.path,
      name: originalName,
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
import 'dart:io';

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

  bool _isImageAttachment() {
    final value = (_attachmentName ?? _attachmentPath ?? '').toLowerCase();

    return value.endsWith('.jpg') ||
        value.endsWith('.jpeg') ||
        value.endsWith('.png') ||
        value.endsWith('.heic');
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

  Future<void> _replaceAttachment(
    Future<ArchiveAttachmentResult?> Function() loader,
  ) async {
    setState(() => _pickingAttachment = true);

    try {
      final result = await loader();

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
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Non è stato possibile aprire questa sorgente. '
            'Sul simulatore la fotocamera potrebbe non essere disponibile.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _pickingAttachment = false);
      }
    }
  }

  Future<void> _pickFileAttachment() async {
    await _replaceAttachment(
      _attachmentService.pickFileAndStore,
    );
  }

  Future<void> _pickPhotoAttachment() async {
    await _replaceAttachment(
      _attachmentService.pickPhotoAndStore,
    );
  }

  Future<void> _takePhotoAttachment() async {
    await _replaceAttachment(
      _attachmentService.takePhotoAndStore,
    );
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

  Widget _sourceButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                _pickingAttachment ? null : _pickFileAttachment,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Scegli PDF / File'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                _pickingAttachment ? null : _pickPhotoAttachment,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Scegli foto dalla libreria'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                _pickingAttachment ? null : _takePhotoAttachment,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Scatta foto'),
          ),
        ),
      ],
    );
  }

  Widget _attachmentCard() {
    final hasAttachment =
        _attachmentPath != null && _attachmentName != null;

    if (!hasAttachment) {
      return _sourceButtons();
    }

    return Column(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isImageAttachment() &&
                  File(_attachmentPath!).existsSync())
                SizedBox(
                  height: 190,
                  child: Image.file(
                    File(_attachmentPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 44,
                        ),
                      );
                    },
                  ),
                )
              else
                const SizedBox(
                  height: 110,
                  child: Center(
                    child: Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 52,
                    ),
                  ),
                ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.attach_file),
                ),
                title: Text(
                  _attachmentName!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle:
                    const Text('Allegato salvato in HomeLife'),
                trailing: IconButton(
                  tooltip: 'Rimuovi allegato',
                  onPressed: _removeAttachment,
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _sourceButtons(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Modifica documento'
              : 'Nuovo documento',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              140,
            ),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Titolo',
                  hintText: 'Es. Fattura lavastoviglie',
                  prefixIcon:
                      Icon(Icons.description_outlined),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
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
                  prefixIcon:
                      Icon(Icons.inventory_2_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child:
                        Text('Casa / documento generale'),
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
                  hintText:
                      'Dettagli utili sul documento...',
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
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
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

python3 - <<'PY'
from pathlib import Path

p = Path("ios/Runner/Info.plist")
text = p.read_text()

if "<key>NSCameraUsageDescription</key>" not in text:
    block = """\t<key>NSCameraUsageDescription</key>
\t<string>HomeLife usa la fotocamera per fotografare fatture, ricevute, garanzie e altri documenti.</string>
"""
    text = text.replace(
        "</dict>\n</plist>",
        block + "</dict>\n</plist>"
    )

p.write_text(text)
PY

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.5.4 installata."
echo "Riavvia completamente l'app:"
echo "  flutter clean"
echo "  flutter pub get"
echo "  flutter run"
