#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🇮🇹 HomeLife — Localizzazione italiana"

# Assicura che flutter_localizations sia presente
if ! grep -q "flutter_localizations:" pubspec.yaml; then
  flutter pub add flutter_localizations --sdk=flutter
fi

python3 - <<'PY'
from pathlib import Path

p = Path("lib/main.dart")
text = p.read_text()

# Aggiunge import localizations se manca
imp = "import 'package:flutter_localizations/flutter_localizations.dart';\n"
if imp not in text:
    text = text.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\n" + imp
    )

# Inserisce locale/delegates/supporto localizzazioni nel MaterialApp
needle = """      debugShowCheckedModeBanner: false,
      title: 'HomeLife',
"""
replacement = """      debugShowCheckedModeBanner: false,
      title: 'HomeLife',
      locale: const Locale('it', 'IT'),
      supportedLocales: const [
        Locale('it', 'IT'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
"""

if "GlobalCupertinoLocalizations.delegate" not in text:
    if needle not in text:
        raise SystemExit("❌ Non trovo il punto previsto in lib/main.dart")
    text = text.replace(needle, replacement)

p.write_text(text)
PY

flutter pub get

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ Localizzazione italiana applicata."
echo "Ora esegui: flutter run"
