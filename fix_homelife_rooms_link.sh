#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("lib/screens/house/house_screen.dart")
text = p.read_text()

# Assicura l'import
if "import 'rooms_screen.dart';" not in text:
    text = text.replace(
        "import 'asset_detail_screen.dart';",
        "import 'asset_detail_screen.dart';\nimport 'rooms_screen.dart';"
    )

# Assicura che _topTile accetti onTap
pattern_sig = re.compile(
    r"""Widget _topTile\(\s*
        IconData icon,\s*
        String title,\s*
        String subtitle,\s*
      \)""",
    re.VERBOSE,
)

if pattern_sig.search(text):
    text = pattern_sig.sub(
        """Widget _topTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  })""",
        text,
        count=1,
    )

# Aggiunge onTap al ListTile di _topTile se manca
top_tile_start = text.find("Widget _topTile(")
if top_tile_start != -1:
    next_method = text.find("\n  @override", top_tile_start)
    if next_method == -1:
        next_method = len(text)

    block = text[top_tile_start:next_method]

    if "onTap: onTap" not in block:
        block = block.replace(
            "        trailing: const Icon(Icons.chevron_right),",
            "        trailing: const Icon(Icons.chevron_right),\n        onTap: onTap,",
            1,
        )
        text = text[:top_tile_start] + block + text[next_method:]

# Sostituisce in modo robusto il blocco Stanze
room_block_pattern = re.compile(
    r"""_topTile\(
\s*Icons\.grid_view_rounded,\s*
'Stanze',\s*
'Organizza casa per ambienti',\s*
\),""",
    re.VERBOSE,
)

replacement = """_topTile(
              Icons.grid_view_rounded,
              'Stanze',
              'Organizza casa per ambienti',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RoomsScreen(),
                  ),
                );
                await _reload();
              },
            ),"""

text, count = room_block_pattern.subn(replacement, text, count=1)

if count == 0 and "RoomsScreen()" not in text:
    raise SystemExit(
        "❌ Non sono riuscito a trovare il blocco Stanze. Mandami lib/screens/house/house_screen.dart"
    )

p.write_text(text)
PY

echo "🔎 flutter analyze"
flutter analyze

echo ""
echo "✅ Collegamento Stanze corretto."
