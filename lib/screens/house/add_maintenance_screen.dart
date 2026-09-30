import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/home_asset.dart';
import '../../models/maintenance_record.dart';
import '../../services/asset_store.dart';
import '../../services/maintenance_store.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final MaintenanceRecord? existingRecord;
  final String? initialAssetId;

  const AddMaintenanceScreen({
    super.key,
    this.existingRecord,
    this.initialAssetId,
  });

  bool get isEditing => existingRecord != null;

  @override
  State<AddMaintenanceScreen> createState() =>
      _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState
    extends State<AddMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _cost;
  late final TextEditingController _notes;

  List<HomeAsset> _assets = [];
  String? _assetId;

  late DateTime _performedDate;
  DateTime? _nextDueDate;

  bool _loadingAssets = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final record = widget.existingRecord;

    _title = TextEditingController(text: record?.title ?? '');
    _cost = TextEditingController(
      text: record?.cost == null
          ? ''
          : record!.cost!.toStringAsFixed(2).replaceAll('.', ','),
    );
    _notes = TextEditingController(text: record?.notes ?? '');

    _assetId = record?.assetId ?? widget.initialAssetId;
    _performedDate = record?.performedDate ?? DateTime.now();
    _nextDueDate = record?.nextDueDate;

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
    _cost.dispose();
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
    required DateTime? value,
    bool allowNone = false,
  }) {
    DateTime tempDate = value ?? DateTime.now();

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
                        DateTime.now().add(const Duration(days: 365 * 20)),
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

  Future<void> _pickPerformedDate() async {
    final value = await _showDatePicker(
      title: 'Data intervento / programmata',
      value: _performedDate,
    );

    if (value != null && mounted) {
      setState(() => _performedDate = value);
    }
  }

  Future<void> _pickNextDueDate() async {
    final value = await _showDatePicker(
      title: 'Prossima scadenza',
      value: _nextDueDate,
      allowNone: true,
    );

    if (!mounted) return;

    setState(() {
      _nextDueDate = value;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final normalizedCost = _cost.text.trim().replaceAll(',', '.');
    final parsedCost =
        normalizedCost.isEmpty ? null : double.tryParse(normalizedCost);

    final record = MaintenanceRecord(
      id: widget.existingRecord?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      assetId: _assetId,
      performedDate: _performedDate,
      nextDueDate: _nextDueDate,
      cost: parsedCost,
      notes: _notes.text.trim(),
    );

    if (widget.isEditing) {
      await MaintenanceStore().update(record);
    } else {
      await MaintenanceStore().add(record);
    }

    if (!mounted) return;
    Navigator.pop(context, record);
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required IconData icon,
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
          widget.isEditing
              ? 'Modifica manutenzione'
              : 'Nuova manutenzione',
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
                  labelText: 'Intervento',
                  hintText: 'Es. Pulizia filtro',
                  prefixIcon: Icon(Icons.build_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci il tipo di intervento';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String?>(
                initialValue: _assetId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Oggetto',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Casa / manutenzione generale'),
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

              _dateField(
                label: 'Data intervento / programmata',
                value: _performedDate,
                onTap: _pickPerformedDate,
                icon: Icons.event_available_outlined,
              ),
              const SizedBox(height: 12),

              _dateField(
                label: 'Prossima scadenza',
                value: _nextDueDate,
                onTap: _pickNextDueDate,
                icon: Icons.notifications_active_outlined,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _cost,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Costo',
                  prefixIcon: Icon(Icons.euro),
                  hintText: '0,00',
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                  hintText: 'Ricambi usati, tecnico, dettagli...',
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
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _saving
                      ? 'Salvataggio...'
                      : widget.isEditing
                          ? 'Salva modifiche'
                          : 'Salva manutenzione',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
