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
