#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🖼️ HomeLife v0.5.3 — PDF/File + Foto"

flutter pub add image_picker

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

    final originalName = picked.name.isNotEmpty
        ? picked.name
        : 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';

    return _copyIntoArchive(
      sourcePath: picked.path,
      originalName: originalName,
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

    final source = File(sourcePath);
    final copied = await source.copy(targetPath);

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

python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/archive/add_document_screen.dart")
text = p.read_text()

# Replace old single picker method with two methods
start = text.find("  Future<void> _pickAttachment() async {")
end = text.find("  Future<void> _removeAttachment() async {", start)

if start == -1 or end == -1:
    raise SystemExit("❌ Non trovo il metodo _pickAttachment previsto.")

new_methods = """  Future<void> _pickFileAttachment() async {
    setState(() => _pickingAttachment = true);

    try {
      final result = await _attachmentService.pickFileAndStore();

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

  Future<void> _pickPhotoAttachment() async {
    setState(() => _pickingAttachment = true);

    try {
      final result = await _attachmentService.pickPhotoAndStore();

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

"""
text = text[:start] + new_methods + text[end:]

# Replace attachment card method
start = text.find("  Widget _attachmentCard() {")
end = text.find("  @override\n  Widget build", start)

if start == -1 or end == -1:
    raise SystemExit("❌ Non trovo _attachmentCard.")

new_card = """  Widget _attachmentCard() {
    final hasAttachment =
        _attachmentPath != null && _attachmentName != null;

    if (!hasAttachment) {
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
        ],
      );
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.attach_file),
            ),
            title: Text(
              _attachmentName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text(
              'Allegato salvato in HomeLife',
            ),
            trailing: IconButton(
              tooltip: 'Rimuovi allegato',
              onPressed: _removeAttachment,
              icon: const Icon(Icons.close),
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed:
                      _pickingAttachment ? null : _pickFileAttachment,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Cambia file'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed:
                      _pickingAttachment ? null : _pickPhotoAttachment,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Cambia foto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

"""
text = text[:start] + new_card + text[end:]

p.write_text(text)
PY

# Add iOS Photo Library permission
python3 - <<'PY'
from pathlib import Path

p = Path("ios/Runner/Info.plist")
text = p.read_text()

key = "<key>NSPhotoLibraryUsageDescription</key>"

if key not in text:
    insert = """\t<key>NSPhotoLibraryUsageDescription</key>
\t<string>HomeLife usa la libreria foto per allegare immagini a documenti, ricevute e garanzie.</string>
"""
    text = text.replace(
        "</dict>\n</plist>",
        insert + "</dict>\n</plist>"
    )

p.write_text(text)
PY

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.5.3 installata."
echo "IMPORTANTE: essendo stato aggiunto un plugin iOS, riavvia completamente l'app."
echo ""
echo "Esegui:"
echo "  flutter clean"
echo "  flutter pub get"
echo "  flutter run"
