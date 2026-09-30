#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "📡 HomeLife v0.7.1 — Ricerca dispositivi rete locale"

flutter pub add flutter_local_device_discovery

mkdir -p lib/screens/house

cat > lib/screens/house/network_device_discovery_screen.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_local_device_discovery/flutter_local_device_discovery.dart';

import '../../models/smart_device.dart';
import '../../services/smart_device_store.dart';

class NetworkDeviceDiscoveryScreen extends StatefulWidget {
  const NetworkDeviceDiscoveryScreen({super.key});

  @override
  State<NetworkDeviceDiscoveryScreen> createState() =>
      _NetworkDeviceDiscoveryScreenState();
}

class _NetworkDeviceDiscoveryScreenState
    extends State<NetworkDeviceDiscoveryScreen> {
  final _discovery = FlutterLocalDeviceDiscovery();
  final _store = SmartDeviceStore();

  bool _scanning = false;
  bool _loadingSaved = true;

  List<LocalDevice> _found = [];
  List<SmartDevice> _saved = [];

  String? _error;
  String? _status;

  static const _serviceTypes = <String>{
    '_http._tcp',
    '_https._tcp',
    '_ipp._tcp',
    '_printer._tcp',
    '_googlecast._tcp',
    '_airplay._tcp',
    '_raop._tcp',
    '_hap._tcp',
    '_matter._tcp',
    '_matterc._udp',
    '_matterd._udp',
  };

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _store.loadAll();

    if (!mounted) return;

    setState(() {
      _saved = saved;
      _loadingSaved = false;
    });
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _found = [];
      _error = null;
      _status = 'Ricerca in corso…';
    });

    try {
      final snapshot = await _discovery.discover(
        const LocalDiscoveryRequest(
          mode: LocalDiscoveryMode.snapshot,
          duration: Duration(seconds: 8),
          protocols: {
            LocalDiscoveryProtocol.mdns,
            LocalDiscoveryProtocol.dnsSd,
          },
          serviceTypes: _serviceTypes,
          resolveServices: true,
          classifyDevices: true,
          deduplicateResults: true,
          includeIpv4: true,
          includeIpv6: true,
          maxDevices: 100,
          maxServices: 500,
        ),
      );

      final devices = [...snapshot.devices]
        ..sort(
          (a, b) => _displayName(a)
              .toLowerCase()
              .compareTo(_displayName(b).toLowerCase()),
        );

      if (!mounted) return;

      setState(() {
        _found = devices;
        _status = devices.isEmpty
            ? 'Nessun dispositivo rilevato'
            : '${devices.length} dispositiv${devices.length == 1 ? 'o' : 'i'} rilevat${devices.length == 1 ? 'o' : 'i'}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'La ricerca non è riuscita. Verifica che HomeLife abbia accesso alla rete locale e che il dispositivo sia sulla stessa rete Wi-Fi.';
        _status = null;
      });
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  String _displayName(LocalDevice device) {
    final name = device.displayName.trim();
    if (name.isNotEmpty) return name;

    final hostname = device.hostname?.trim();
    if (hostname != null && hostname.isNotEmpty) return hostname;

    return 'Dispositivo di rete';
  }

  String _host(LocalDevice device) {
    final ipv4 = device.ipv4Address?.address;
    if (ipv4 != null && ipv4.isNotEmpty) return ipv4;

    final hostname = device.hostname;
    if (hostname != null && hostname.trim().isNotEmpty) {
      return hostname.trim();
    }

    if (device.addresses.isNotEmpty) {
      return device.addresses.first.address;
    }

    return '';
  }

  Set<String> _serviceNames(LocalDevice device) {
    return {
      for (final service in device.services)
        service.serviceType.toLowerCase(),
    };
  }

  String _smartProtocol(LocalDevice device) {
    final services = _serviceNames(device);

    if (services.any(
      (value) =>
          value.contains('_matter._tcp') ||
          value.contains('_matterc._udp') ||
          value.contains('_matterd._udp'),
    )) {
      return 'Matter';
    }

    if (services.any((value) => value.contains('_hap._tcp'))) {
      return 'HomeKit';
    }

    return 'Wi-Fi';
  }

  String _smartType(LocalDevice device) {
    final services = _serviceNames(device).join(' ');
    final raw = [
      device.type.name,
      device.displayName,
      device.hostname ?? '',
      services,
      ...device.capabilities.map((item) => item.name),
    ].join(' ').toLowerCase();

    if (raw.contains('doorbell')) return 'Campanello';
    if (raw.contains('camera') || raw.contains('onvif')) {
      return 'Telecamera';
    }
    if (raw.contains('thermostat') ||
        raw.contains('temperaturecontroller')) {
      return 'Termostato';
    }
    if (raw.contains('light') ||
        raw.contains('lamp') ||
        raw.contains('bulb')) {
      return 'Luce';
    }
    if (raw.contains('plug') ||
        raw.contains('outlet') ||
        raw.contains('switch')) {
      return 'Presa';
    }
    if (raw.contains('sensor')) return 'Sensore';
    if (raw.contains('appliance')) return 'Elettrodomestico';

    return 'Altro';
  }

  IconData _icon(LocalDevice device) {
    switch (_smartType(device)) {
      case 'Luce':
        return Icons.lightbulb_outline;
      case 'Presa':
        return Icons.electrical_services_outlined;
      case 'Termostato':
        return Icons.thermostat_outlined;
      case 'Sensore':
        return Icons.sensors_outlined;
      case 'Telecamera':
        return Icons.videocam_outlined;
      case 'Campanello':
        return Icons.notifications_active_outlined;
      case 'Elettrodomestico':
        return Icons.kitchen_outlined;
      default:
        return Icons.router_outlined;
    }
  }

  bool _alreadySaved(LocalDevice device) {
    final host = _host(device).toLowerCase();
    final name = _displayName(device).toLowerCase();

    return _saved.any((saved) {
      final sameHost = host.isNotEmpty &&
          saved.host.trim().toLowerCase() == host;

      final sameName =
          saved.name.trim().toLowerCase() == name;

      return sameHost || sameName;
    });
  }

  String _serviceSummary(LocalDevice device) {
    final services = device.services
        .map((item) => item.serviceType)
        .toSet()
        .toList()
      ..sort();

    if (services.isEmpty) {
      return device.type.name == 'unknown'
          ? 'Servizio di rete'
          : device.type.name;
    }

    final first = services.take(3).join(' • ');
    if (services.length > 3) {
      return '$first • +${services.length - 3}';
    }

    return first;
  }

  Future<void> _addDevice(LocalDevice device) async {
    if (_alreadySaved(device)) return;

    final smart = SmartDevice(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _displayName(device),
      type: _smartType(device),
      brand: device.manufacturer?.trim() ?? '',
      model: device.model?.trim() ?? '',
      protocol: _smartProtocol(device),
      host: _host(device),
      roomId: null,
      isOnline: true,
      isControllable: false,
      isOn: false,
      batteryPercent: null,
      notes:
          'Rilevato automaticamente dalla rete locale tramite Bonjour/DNS-SD.',
    );

    await _store.add(smart);
    await _loadSaved();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${smart.name} aggiunto a HomeLife',
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.wifi_find_outlined,
            size: 50,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          const Text(
            'Cerca dispositivi nella rete',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'HomeLife cercherà dispositivi che pubblicano servizi compatibili sulla rete locale.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.wifi_find_outlined),
            label: const Text('Avvia ricerca'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerca dispositivi'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
          children: [
            Text(
              'Ricerca dispositivi individuabili sulla stessa rete Wi-Fi.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'La ricerca non equivale a un controllo completo della rete: alcuni dispositivi non pubblicano servizi visibili e potrebbero non comparire.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 20),

            if (_scanning)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Ricerca dispositivi…',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Può richiedere circa 8 secondi.',
                    ),
                  ],
                ),
              )
            else ...[
              if (_status != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _status!,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _scan,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Riprova'),
                    ),
                  ],
                ),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_error!)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],

              if (_status == null &&
                  _error == null &&
                  _found.isEmpty)
                _emptyState(),

              if (_status != null &&
                  _found.isEmpty &&
                  _error == null) ...[
                const SizedBox(height: 14),
                _emptyState(),
              ],

              if (_found.isNotEmpty) ...[
                const SizedBox(height: 14),
                ..._found.map(
                  (device) {
                    final saved = _alreadySaved(device);
                    final host = _host(device);
                    final details = <String>[
                      if (device.manufacturer != null &&
                          device.manufacturer!
                              .trim()
                              .isNotEmpty)
                        device.manufacturer!.trim(),
                      if (device.model != null &&
                          device.model!.trim().isNotEmpty)
                        device.model!.trim(),
                      if (host.isNotEmpty) host,
                    ];

                    return Card(
                      margin:
                          const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          4,
                          6,
                          8,
                          6,
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                child: Icon(_icon(device)),
                              ),
                              title: Text(
                                _displayName(device),
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if (details.isNotEmpty)
                                    details.join(' • '),
                                  _serviceSummary(device),
                                ].join('\n'),
                              ),
                            ),
                            Align(
                              alignment:
                                  Alignment.centerRight,
                              child: saved
                                  ? const Padding(
                                      padding:
                                          EdgeInsets.only(
                                        right: 10,
                                        bottom: 6,
                                      ),
                                      child: Chip(
                                        avatar: Icon(
                                          Icons.check,
                                          size: 16,
                                        ),
                                        label: Text(
                                          'Già aggiunto',
                                        ),
                                      ),
                                    )
                                  : FilledButton.icon(
                                      onPressed:
                                          _loadingSaved
                                              ? null
                                              : () =>
                                                  _addDevice(
                                                    device,
                                                  ),
                                      icon: const Icon(
                                        Icons.add,
                                      ),
                                      label: const Text(
                                        'Aggiungi a HomeLife',
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
DART

# Inserisce il pulsante Cerca dispositivi nello Smart Home Hub.
python3 - <<'PY'
from pathlib import Path

p = Path("lib/screens/house/smart_home_screen.dart")
text = p.read_text()

if "network_device_discovery_screen.dart" not in text:
    text = text.replace(
        "import 'add_smart_device_screen.dart';",
        "import 'add_smart_device_screen.dart';\nimport 'network_device_discovery_screen.dart';",
        1,
    )

if "Future<void> _discoverDevices()" not in text:
    anchor = "  Future<void> _add() async {"
    method = """  Future<void> _discoverDevices() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NetworkDeviceDiscoveryScreen(),
      ),
    );

    await _reload();
  }

"""
    if anchor not in text:
        raise SystemExit("❌ Non trovo il punto per inserire la ricerca.")
    text = text.replace(anchor, method + anchor, 1)

needle = """              const SizedBox(height: 22),

              if (_loading)
"""

replacement = """              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _discoverDevices,
                  icon: const Icon(Icons.wifi_find_outlined),
                  label: const Text('Cerca dispositivi nella rete'),
                ),
              ),

              const SizedBox(height: 18),

              if (_loading)
"""

if "Cerca dispositivi nella rete" not in text:
    if needle not in text:
        raise SystemExit("❌ Non trovo il punto grafico per il pulsante ricerca.")
    text = text.replace(needle, replacement, 1)

p.write_text(text)
PY

# Configurazione iOS rete locale / Bonjour.
python3 - <<'PY'
from pathlib import Path
import plistlib

p = Path("ios/Runner/Info.plist")

with p.open("rb") as f:
    data = plistlib.load(f)

data["NSLocalNetworkUsageDescription"] = (
    "HomeLife usa la rete locale per trovare dispositivi smart "
    "presenti sulla tua rete Wi-Fi."
)

services = set(data.get("NSBonjourServices", []))
services.update({
    "_http._tcp",
    "_https._tcp",
    "_ipp._tcp",
    "_printer._tcp",
    "_googlecast._tcp",
    "_airplay._tcp",
    "_raop._tcp",
    "_hap._tcp",
    "_matter._tcp",
    "_matterc._udp",
    "_matterd._udp",
})

data["NSBonjourServices"] = sorted(services)

with p.open("wb") as f:
    plistlib.dump(
        data,
        f,
        fmt=plistlib.FMT_XML,
        sort_keys=False,
    )
PY

echo ""
echo "🔎 Controllo codice..."
flutter analyze

echo ""
echo "✅ HomeLife v0.7.1 installata."
echo ""
echo "IMPORTANTE: abbiamo aggiunto un plugin nativo e permessi iOS."
echo "Riavvia completamente:"
echo "  flutter clean"
echo "  flutter pub get"
echo "  flutter run"
