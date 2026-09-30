#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "📡 HomeLife v0.7.1 — Fix compatibilità discovery 0.1.0"

FILE="lib/screens/house/network_device_discovery_screen.dart"

if [ ! -f "$FILE" ]; then
  echo "❌ Non trovo $FILE"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("lib/screens/house/network_device_discovery_screen.dart")
text = p.read_text()

# 0.1.0 non espone maxDevices/maxServices nel costruttore.
text = re.sub(
    r"\s*maxDevices:\s*100,\s*\n",
    "",
    text,
)
text = re.sub(
    r"\s*maxServices:\s*500,\s*\n",
    "",
    text,
)

# 0.1.0 non espone manufacturer/model come getter di LocalDevice.
text = text.replace(
"""      brand: device.manufacturer?.trim() ?? '',
      model: device.model?.trim() ?? '',""",
"""      brand: '',
      model: '',"""
)

# Rimuove manufacturer/model dal riepilogo visivo dei risultati.
old_details = """                    final details = <String>[
                      if (device.manufacturer != null &&
                          device.manufacturer!
                              .trim()
                              .isNotEmpty)
                        device.manufacturer!.trim(),
                      if (device.model != null &&
                          device.model!.trim().isNotEmpty)
                        device.model!.trim(),
                      if (host.isNotEmpty) host,
                    ];"""

new_details = """                    final details = <String>[
                      if (host.isNotEmpty) host,
                    ];"""

if old_details in text:
    text = text.replace(old_details, new_details, 1)
else:
    # Fallback robusto per eventuali differenze di formattazione.
    text = re.sub(
        r"""                    final details = <String>\[\s*
(?:.|\n)*?
\s*if \(host\.isNotEmpty\) host,\s*
\s*\];""",
        """                    final details = <String>[
                      if (host.isNotEmpty) host,
                    ];""",
        text,
        count=1,
    )

# Controllo di sicurezza: nessun riferimento residuo alle API non presenti.
bad = [
    "device.manufacturer",
    "device.model",
    "maxDevices:",
    "maxServices:",
]
remaining = [item for item in bad if item in text]
if remaining:
    raise SystemExit(
        "❌ Sono rimasti riferimenti incompatibili: " + ", ".join(remaining)
    )

p.write_text(text)
PY

echo ""
echo "🔎 flutter analyze"
flutter analyze

echo ""
echo "✅ Fix applicato."
echo ""
echo "Ora esegui:"
echo "  flutter clean"
echo "  flutter pub get"
echo "  flutter run"
