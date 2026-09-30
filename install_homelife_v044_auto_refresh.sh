#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🔄 HomeLife v0.4.4 — Refresh automatico Home"

cat > lib/main.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
      locale: const Locale('it', 'IT'),
      supportedLocales: const [
        Locale('it', 'IT'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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

  int _homeRefreshVersion = 0;
  int _agendaRefreshVersion = 0;
  int _houseRefreshVersion = 0;

  List<Widget> get _pages => [
        HomeScreen(
          key: ValueKey('home-$_homeRefreshVersion'),
        ),
        AgendaScreen(
          key: ValueKey('agenda-$_agendaRefreshVersion'),
        ),
        HouseScreen(
          key: ValueKey('house-$_houseRefreshVersion'),
        ),
        const ArchiveScreen(),
        const MoreScreen(),
      ];

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;

      // Quando si rientra in una sezione, la ricreiamo così
      // ricarica i dati persistenti aggiornati dalle altre tab.
      if (index == 0) {
        _homeRefreshVersion++;
      } else if (index == 1) {
        _agendaRefreshVersion++;
      } else if (index == 2) {
        _houseRefreshVersion++;
      }
    });
  }

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
        onDestinationSelected: _selectTab,
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
DART

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ Refresh automatico applicato."
echo "Ora esegui: flutter run"
