import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/maintenance_record.dart';
import '../../services/asset_store.dart';
import '../../services/maintenance_store.dart';
import 'add_maintenance_screen.dart';

class MaintenanceScreen extends StatefulWidget {
  final String? assetIdFilter;
  final String? assetName;

  const MaintenanceScreen({
    super.key,
    this.assetIdFilter,
    this.assetName,
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _store = MaintenanceStore();

  bool _loading = true;
  List<MaintenanceRecord> _records = [];
  List<HomeAsset> _assets = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final records = await _store.loadAll();
    final assets = await AssetStore().loadAssets();

    if (!mounted) return;

    setState(() {
      _assets = assets;

      _records = widget.assetIdFilter == null
          ? records
          : records
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
    if (date == null) return '—';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatCost(double? cost) {
    if (cost == null) return '';

    return '€ ${cost.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _add() async {
    final added = await Navigator.push<MaintenanceRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          initialAssetId: widget.assetIdFilter,
        ),
      ),
    );

    if (added != null) {
      await _reload();
    }
  }

  Future<void> _edit(MaintenanceRecord record) async {
    final updated = await Navigator.push<MaintenanceRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          existingRecord: record,
        ),
      ),
    );

    if (updated != null) {
      await _reload();
    }
  }

  Future<void> _delete(MaintenanceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare manutenzione?'),
        content: Text(
          'Vuoi eliminare "${record.title}" dallo storico?',
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

    if (confirmed == true) {
      await _store.delete(record.id);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.assetName == null
        ? 'Manutenzioni'
        : 'Manutenzioni';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Manutenzione'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              if (widget.assetName != null) ...[
                Text(
                  widget.assetName!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
              ],

              Text(
                widget.assetName == null
                    ? 'Storico degli interventi e prossime scadenze.'
                    : 'Storico degli interventi per questo oggetto.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 22),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_records.isEmpty)
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.home_repair_service_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Nessuna manutenzione registrata',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Aggiungi il primo intervento.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('Aggiungi manutenzione'),
                      ),
                    ],
                  ),
                )
              else
                ..._records.map(
                  (record) {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final performed = DateTime(
                      record.performedDate.year,
                      record.performedDate.month,
                      record.performedDate.day,
                    );

                    final isScheduled = !performed.isBefore(today);

                    final next = isScheduled
                        ? 'Programmato per ${_formatDate(record.performedDate)}'
                        : record.nextDueDate == null
                            ? 'Nessuna prossima scadenza'
                            : 'Prossima: ${_formatDate(record.nextDueDate)}';

                    final cost = _formatCost(record.cost);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: const Icon(
                            Icons.home_repair_service_outlined,
                          ),
                        ),
                        title: Text(
                          record.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          [
                            _assetName(record.assetId),
                            if (!isScheduled)
                              _formatDate(record.performedDate),
                            if (cost.isNotEmpty) cost,
                            next,
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _edit(record);
                            } else if (value == 'delete') {
                              _delete(record);
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
                        onTap: () => _edit(record),
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
