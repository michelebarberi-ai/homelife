#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🔧 HomeLife v0.4.2 — Manutenzioni programmate in Home"

python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/home/home_screen.dart")
text = p.read_text()

# Sostituisce la logica di caricamento delle manutenzioni:
# - intervento futuro = programmato
# - intervento passato = usa prossima scadenza
old = """    final upcoming = records
        .where((record) {
          final due = record.nextDueDate;
          if (due == null) return false;

          final normalized = DateTime(due.year, due.month, due.day);
          return !normalized.isBefore(today);
        })
        .toList()
      ..sort((a, b) {
        return a.nextDueDate!.compareTo(b.nextDueDate!);
      });"""

new = """    final upcoming = records
        .where((record) {
          final performed = DateTime(
            record.performedDate.year,
            record.performedDate.month,
            record.performedDate.day,
          );

          if (!performed.isBefore(today)) {
            return true;
          }

          final due = record.nextDueDate;
          if (due == null) return false;

          final normalized = DateTime(
            due.year,
            due.month,
            due.day,
          );

          return !normalized.isBefore(today);
        })
        .toList()
      ..sort((a, b) {
        DateTime effectiveDate(MaintenanceRecord record) {
          final performed = DateTime(
            record.performedDate.year,
            record.performedDate.month,
            record.performedDate.day,
          );

          if (!performed.isBefore(today)) {
            return performed;
          }

          return record.nextDueDate!;
        }

        return effectiveDate(a).compareTo(effectiveDate(b));
      });"""

if old not in text:
    raise SystemExit("❌ Non trovo la logica Home prevista. Mandami home_screen.dart.")

text = text.replace(old, new)

# Sostituisce il blocco visuale della scadenza
old2 = """                  final due = record.nextDueDate!;
                  final assetName = _assetName(record.assetId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: const CircleAvatar(
                        child: Icon(
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
                        '$assetName • ${_relativeDueText(due)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openMaintenance,
                    ),
                  );"""

new2 = """                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final performed = DateTime(
                    record.performedDate.year,
                    record.performedDate.month,
                    record.performedDate.day,
                  );

                  final isScheduled = !performed.isBefore(today);

                  final effectiveDate = isScheduled
                      ? performed
                      : record.nextDueDate!;

                  final assetName = _assetName(record.assetId);

                  final timingText = isScheduled
                      ? _relativeDueText(effectiveDate)
                          .replaceFirst('Scade', 'Programmato')
                      : _relativeDueText(effectiveDate);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        child: Icon(
                          isScheduled
                              ? Icons.event_available_outlined
                              : Icons.home_repair_service_outlined,
                        ),
                      ),
                      title: Text(
                        record.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '$assetName • $timingText',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openMaintenance,
                    ),
                  );"""

if old2 not in text:
    raise SystemExit("❌ Non trovo il blocco grafico Home previsto.")

text = text.replace(old2, new2)
p.write_text(text)
PY

python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/house/maintenance_screen.dart")
text = p.read_text()

old = """                    final next = record.nextDueDate == null
                        ? 'Nessuna prossima scadenza'
                        : 'Prossima: ${_formatDate(record.nextDueDate)}';

                    final cost = _formatCost(record.cost);"""

new = """                    final now = DateTime.now();
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

                    final cost = _formatCost(record.cost);"""

if old not in text:
    raise SystemExit("❌ Non trovo il blocco manutenzioni previsto.")

text = text.replace(old, new)

old2 = """                            _assetName(record.assetId),
                            _formatDate(record.performedDate),
                            if (cost.isNotEmpty) cost,
                            next,"""

new2 = """                            _assetName(record.assetId),
                            if (!isScheduled)
                              _formatDate(record.performedDate),
                            if (cost.isNotEmpty) cost,
                            next,"""

if old2 not in text:
    raise SystemExit("❌ Non trovo il testo scheda manutenzione previsto.")

text = text.replace(old2, new2)

p.write_text(text)
PY

# Etichetta più chiara nel form
python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/house/add_maintenance_screen.dart")
text = p.read_text()

text = text.replace(
    "title: 'Data intervento',",
    "title: 'Data intervento / programmata',"
)

text = text.replace(
    "label: 'Data intervento',",
    "label: 'Data intervento / programmata',"
)

p.write_text(text)
PY

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.4.2 installata."
echo "Ora esegui: flutter run"
