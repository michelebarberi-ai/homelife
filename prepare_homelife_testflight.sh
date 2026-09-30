#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🚀 HomeLife — Preparazione TestFlight"

cp pubspec.yaml pubspec.yaml.before_testflight
cp ios/Runner.xcodeproj/project.pbxproj ios/Runner.xcodeproj/project.pbxproj.before_testflight

python3 - <<'PY'
from pathlib import Path
import re

# Versione Flutter
p = Path("pubspec.yaml")
text = p.read_text()
text = re.sub(
    r"^version:\s*.*$",
    "version: 0.7.1+1",
    text,
    flags=re.MULTILINE,
)
p.write_text(text)

# Bundle ID Xcode
p = Path("ios/Runner.xcodeproj/project.pbxproj")
text = p.read_text()

text = text.replace(
    "com.example.homelife.RunnerTests",
    "com.michelebarberi.homelife.RunnerTests",
)
text = text.replace(
    "com.example.homelife",
    "com.michelebarberi.homelife",
)

p.write_text(text)
PY

# Display name iOS
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName HomeLife" ios/Runner/Info.plist 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string HomeLife" ios/Runner/Info.plist

echo ""
echo "📦 Aggiorno dipendenze..."
flutter pub get

echo ""
echo "🔎 Controllo progetto..."
flutter analyze

echo ""
echo "✅ Preparazione locale completata."
echo ""
echo "Versione:"
grep '^version:' pubspec.yaml
echo ""
echo "Bundle ID:"
grep -n "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj | head -10
echo ""
echo "Display name:"
/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" ios/Runner/Info.plist
