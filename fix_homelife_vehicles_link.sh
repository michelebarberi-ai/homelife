#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🚗 HomeLife — Fix collegamento Veicoli"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("lib/screens/house/house_screen.dart")
text = p.read_text()

# Import
if "import 'vehicles_screen.dart';" not in text:
    text = text.replace(
        "import 'rooms_screen.dart';",
        "import 'rooms_screen.dart';\nimport 'vehicles_screen.dart';",
    )

# Metodo apertura veicoli
if "Future<void> _openVehicles()" not in text:
    anchor = "  Future<void> _openMaintenance() async {"
    method = """  Future<void> _openVehicles() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const VehiclesScreen(),
      ),
    );

    if (mounted) {
      await _reload();
    }
  }

"""
    if anchor not in text:
        raise SystemExit("❌ Non trovo il punto dove inserire _openVehicles().")
    text = text.replace(anchor, method + anchor, 1)

# Sostituisce in modo robusto il blocco Veicoli
pattern = re.compile(
    r"""_topTile\(
\s*Icons\.directions_car_outlined,\s*
'Veicoli',\s*
'Auto, moto e altri mezzi',(?:\s*
onTap:\s*[^,\n]+,)?\s*
\),""",
    re.MULTILINE,
)

replacement = """_topTile(
              Icons.directions_car_outlined,
              'Veicoli',
              'Auto, moto e altri mezzi',
              onTap: _openVehicles,
            ),"""

text, count = pattern.subn(replacement, text, count=1)

if count == 0:
    # fallback semplice sul blocco più comune
    old = """            _topTile(
              Icons.directions_car_outlined,
              'Veicoli',
              'Auto, moto e altri mezzi',
            ),"""
    if old in text:
        text = text.replace(old, replacement, 1)
    elif "onTap: _openVehicles" not in text:
        raise SystemExit("❌ Non riesco a trovare il blocco Veicoli.")

p.write_text(text)
PY

echo ""
echo "🔎 Controllo..."
flutter analyze

echo ""
echo "✅ Collegamento Veicoli corretto."
echo "Ora esegui: flutter run"
