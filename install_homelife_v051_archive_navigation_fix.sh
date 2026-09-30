#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "📁 HomeLife v0.5.1 — Fix navigazione Archivio"

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

      if (_filter != 'Tutti' &&
          !_documents.any((doc) => doc.category == _filter)) {
        _filter = 'Tutti';
      }
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
        return Icons.description_outlined;
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

    final openedFromAsset = widget.assetName != null;

    return Scaffold(
      appBar: openedFromAsset
          ? AppBar(
              title: const Text('Documenti'),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Documento'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      openedFromAsset ? 'Archivio' : 'Archivio',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  if (!openedFromAsset)
                    FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                      label: const Text('Documento'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                openedFromAsset
                    ? 'Documenti collegati a ${widget.assetName}.'
                    : 'Documenti, fatture, garanzie e contratti.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              if (openedFromAsset) ...[
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
                          child: Icon(_categoryIcon(document.category)),
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

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ Navigazione Archivio corretta."
echo "Ora esegui: flutter run"
