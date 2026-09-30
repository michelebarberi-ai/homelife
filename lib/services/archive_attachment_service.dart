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
