import 'package:flutter/material.dart';

import '../../models/agenda_event.dart';
import '../../services/agenda_store.dart';
import 'add_event_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _store = AgendaStore();

  bool _loading = true;
  List<AgendaEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final events = await _store.loadAll();

    if (!mounted) return;

    setState(() {
      _events = events;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final event = await Navigator.push<AgendaEvent>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEventScreen(),
      ),
    );

    if (event != null) {
      await _reload();
    }
  }

  Future<void> _edit(AgendaEvent event) async {
    final updated = await Navigator.push<AgendaEvent>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventScreen(existingEvent: event),
      ),
    );

    if (updated != null) {
      await _reload();
    }
  }

  Future<void> _delete(AgendaEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare evento?'),
        content: Text('Vuoi eliminare "${event.title}"?'),
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
      await _store.delete(event.id);
      await _reload();
    }
  }

  String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _time(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Agenda',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Evento'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Impegni e appuntamenti della famiglia.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_events.isEmpty)
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Nessun evento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Aggiungi il primo appuntamento.',
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi evento'),
                    ),
                  ],
                ),
              )
            else
              ..._events.map(
                (event) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: const CircleAvatar(
                      child: Icon(Icons.event_outlined),
                    ),
                    title: Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_date(event.dateTime)} • ${_time(event.dateTime)}'
                      '${event.notes.trim().isEmpty ? '' : '\n${event.notes}'}',
                    ),
                    isThreeLine: event.notes.trim().isNotEmpty,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _edit(event);
                        } else if (value == 'delete') {
                          _delete(event);
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
                    onTap: () => _edit(event),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
