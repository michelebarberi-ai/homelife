import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/agenda_event.dart';
import '../../services/agenda_store.dart';

class AddEventScreen extends StatefulWidget {
  final AgendaEvent? existingEvent;
  final DateTime? initialDate;

  const AddEventScreen({
    super.key,
    this.existingEvent,
    this.initialDate,
  });

  bool get isEditing => existingEvent != null;

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _notes;

  late DateTime _dateTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingEvent;
    final base = widget.initialDate ?? DateTime.now();

    _title = TextEditingController(text: existing?.title ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');

    _dateTime = existing?.dateTime ??
        DateTime(
          base.year,
          base.month,
          base.day,
          DateTime.now().hour + 1,
          0,
        );
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    DateTime temp = _dateTime;

    final result = await showModalBottomSheet<DateTime>(
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
                      const SizedBox(width: 72),
                      const Spacer(),
                      const Text(
                        'Data',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext, temp),
                        child: const Text('Fine'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: temp,
                    dateOrder: DatePickerDateOrder.dmy,
                    minimumDate: DateTime(2020, 1, 1),
                    maximumDate:
                        DateTime.now().add(const Duration(days: 365 * 10)),
                    onDateTimeChanged: (value) {
                      temp = DateTime(
                        value.year,
                        value.month,
                        value.day,
                        temp.hour,
                        temp.minute,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _dateTime = DateTime(
          result.year,
          result.month,
          result.day,
          _dateTime.hour,
          _dateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    DateTime temp = _dateTime;

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 330,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 72),
                      const Spacer(),
                      const Text(
                        'Ora',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext, temp),
                        child: const Text('Fine'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    minuteInterval: 5,
                    initialDateTime: temp,
                    onDateTimeChanged: (value) {
                      temp = DateTime(
                        temp.year,
                        temp.month,
                        temp.day,
                        value.hour,
                        value.minute,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _dateTime = DateTime(
          _dateTime.year,
          _dateTime.month,
          _dateTime.day,
          result.hour,
          result.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final event = AgendaEvent(
      id: widget.existingEvent?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      dateTime: _dateTime,
      notes: _notes.text.trim(),
    );

    if (widget.isEditing) {
      await AgendaStore().update(event);
    } else {
      await AgendaStore().add(event);
    }

    if (!mounted) return;
    Navigator.pop(context, event);
  }

  Widget _pickerCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
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
                      value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
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
        title: Text(widget.isEditing ? 'Modifica evento' : 'Nuovo evento'),
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
                  labelText: 'Evento',
                  hintText: 'Es. Dentista',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci un evento';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _pickerCard(
                icon: Icons.calendar_month_outlined,
                label: 'Data',
                value: _formatDate(_dateTime),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              _pickerCard(
                icon: Icons.schedule_outlined,
                label: 'Ora',
                value: _formatTime(_dateTime),
                onTap: _pickTime,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  widget.isEditing ? 'Salva modifiche' : 'Salva evento',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
