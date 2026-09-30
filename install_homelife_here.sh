#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Non sei dentro una cartella Flutter (pubspec.yaml non trovato)."
  exit 1
fi

echo "🏠 Installazione HomeLife nel progetto corrente..."
rm -rf lib
mkdir -p lib

mkdir -p "lib/core/theme"
cat > "lib/core/theme/app_theme.dart" <<'HOMELIFE_EOF_CORE_THEME_APP_THEME_DART'
import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF496B5A);

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F7F5),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
HOMELIFE_EOF_CORE_THEME_APP_THEME_DART

mkdir -p "lib"
cat > "lib/main.dart" <<'HOMELIFE_EOF_MAIN_DART'
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/agenda/agenda_screen.dart';
import 'screens/archive/archive_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/house/house_screen.dart';
import 'screens/more/more_screen.dart';

void main() {
  runApp(const HomeLifeApp());
}

class HomeLifeApp extends StatelessWidget {
  const HomeLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HomeLife',
      theme: AppTheme.lightTheme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    HomeScreen(),
    AgendaScreen(),
    HouseScreen(),
    ArchiveScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (context) => const SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.event_outlined),
                      title: Text('Nuovo evento'),
                    ),
                    ListTile(
                      leading: Icon(Icons.receipt_long_outlined),
                      title: Text('Nuovo documento'),
                    ),
                    ListTile(
                      leading: Icon(Icons.home_repair_service_outlined),
                      title: Text('Nuova manutenzione'),
                    ),
                    ListTile(
                      leading: Icon(Icons.euro_outlined),
                      title: Text('Nuova spesa'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.house_outlined),
            selectedIcon: Icon(Icons.house),
            label: 'Casa',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Archivio',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'Altro',
          ),
        ],
      ),
    );
  }
}
HOMELIFE_EOF_MAIN_DART

mkdir -p "lib/screens/agenda"
cat > "lib/screens/agenda/agenda_screen.dart" <<'HOMELIFE_EOF_SCREENS_AGENDA_AGENDA_SCREEN_DART'
import 'package:flutter/material.dart';

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Agenda',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
HOMELIFE_EOF_SCREENS_AGENDA_AGENDA_SCREEN_DART

mkdir -p "lib/screens/archive"
cat > "lib/screens/archive/archive_screen.dart" <<'HOMELIFE_EOF_SCREENS_ARCHIVE_ARCHIVE_SCREEN_DART'
import 'package:flutter/material.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Archivio',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
HOMELIFE_EOF_SCREENS_ARCHIVE_ARCHIVE_SCREEN_DART

mkdir -p "lib/screens/home"
cat > "lib/screens/home/home_screen.dart" <<'HOMELIFE_EOF_SCREENS_HOME_HOME_SCREEN_DART'
import 'package:flutter/material.dart';

import '../../widgets/dashboard_card.dart';
import '../../widgets/home_card.dart';
import '../../widgets/section_title.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          Text(
            'Buon pomeriggio',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ecco cosa succede oggi a casa.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 28),

          const SectionTitle(title: 'Oggi'),
          const HomeCard(
            icon: Icons.calendar_today,
            title: '17:30',
            subtitle: 'Allenamento',
          ),
          const HomeCard(
            icon: Icons.inventory_2_outlined,
            title: '19:00',
            subtitle: 'Ritirare pacco',
          ),

          const SizedBox(height: 18),
          const SectionTitle(title: 'Da ricordare'),
          const HomeCard(
            icon: Icons.directions_car_outlined,
            title: 'Assicurazione auto',
            subtitle: 'Scade tra 18 giorni',
          ),
          const HomeCard(
            icon: Icons.build_outlined,
            title: 'Controllo caldaia',
            subtitle: 'Tra 24 giorni',
          ),

          const SizedBox(height: 18),
          const SectionTitle(title: 'Casa'),
          const Row(
            children: [
              Expanded(
                child: DashboardCard(
                  icon: Icons.build_circle_outlined,
                  value: '3',
                  label: 'Manutenzioni',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: DashboardCard(
                  icon: Icons.verified_outlined,
                  value: '2',
                  label: 'Garanzie',
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const SectionTitle(title: 'Questo mese'),
          const HomeCard(
            icon: Icons.euro,
            title: '€ 1.426',
            subtitle: 'Spese registrate',
          ),

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Chiedi a HomeLife',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
HOMELIFE_EOF_SCREENS_HOME_HOME_SCREEN_DART

mkdir -p "lib/screens/house"
cat > "lib/screens/house/house_screen.dart" <<'HOMELIFE_EOF_SCREENS_HOUSE_HOUSE_SCREEN_DART'
import 'package:flutter/material.dart';

class HouseScreen extends StatelessWidget {
  const HouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: const [
          Text(
            'Casa',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),
          _HouseTile(
            icon: Icons.chair_outlined,
            title: 'Stanze',
            subtitle: 'Soggiorno, cucina, camere, garage...',
          ),
          _HouseTile(
            icon: Icons.devices_other_outlined,
            title: 'Oggetti',
            subtitle: 'Elettrodomestici, impianti e dispositivi',
          ),
          _HouseTile(
            icon: Icons.directions_car_outlined,
            title: 'Veicoli',
            subtitle: 'Auto, moto e altri mezzi',
          ),
          _HouseTile(
            icon: Icons.home_repair_service_outlined,
            title: 'Manutenzioni',
            subtitle: 'Interventi fatti e prossime scadenze',
          ),
        ],
      ),
    );
  }
}

class _HouseTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HouseTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        minVerticalPadding: 18,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
HOMELIFE_EOF_SCREENS_HOUSE_HOUSE_SCREEN_DART

mkdir -p "lib/screens/more"
cat > "lib/screens/more/more_screen.dart" <<'HOMELIFE_EOF_SCREENS_MORE_MORE_SCREEN_DART'
import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Altro',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
HOMELIFE_EOF_SCREENS_MORE_MORE_SCREEN_DART

mkdir -p "lib/widgets"
cat > "lib/widgets/dashboard_card.dart" <<'HOMELIFE_EOF_WIDGETS_DASHBOARD_CARD_DART'
import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(label),
        ],
      ),
    );
  }
}
HOMELIFE_EOF_WIDGETS_DASHBOARD_CARD_DART

mkdir -p "lib/widgets"
cat > "lib/widgets/home_card.dart" <<'HOMELIFE_EOF_WIDGETS_HOME_CARD_DART'
import 'package:flutter/material.dart';

class HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const HomeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
HOMELIFE_EOF_WIDGETS_HOME_CARD_DART

mkdir -p "lib/widgets"
cat > "lib/widgets/section_title.dart" <<'HOMELIFE_EOF_WIDGETS_SECTION_TITLE_DART'
import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
HOMELIFE_EOF_WIDGETS_SECTION_TITLE_DART

echo ""
echo "🔎 flutter analyze"
flutter analyze
echo ""
echo "✅ HomeLife installato nel progetto corrente."
echo "Ora esegui: flutter run"
