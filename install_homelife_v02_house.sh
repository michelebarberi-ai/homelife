#!/bin/zsh
set -e

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Esegui questo script dalla cartella principale di HomeLife."
  exit 1
fi

echo "🏠 HomeLife v0.2 — Casa + Oggetti"
flutter pub add shared_preferences

mkdir -p lib/models lib/services lib/screens/house

cat > lib/models/home_asset.dart <<'DART'
import 'dart:convert';

class HomeAsset {
  final String id;
  final String name;
  final String category;
  final String brand;
  final String model;
  final DateTime? purchaseDate;
  final double? price;
  final DateTime? warrantyExpiry;
  final String notes;

  const HomeAsset({
    required this.id,
    required this.name,
    required this.category,
    this.brand = '',
    this.model = '',
    this.purchaseDate,
    this.price,
    this.warrantyExpiry,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'brand': brand,
        'model': model,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'price': price,
        'warrantyExpiry': warrantyExpiry?.toIso8601String(),
        'notes': notes,
      };

  factory HomeAsset.fromMap(Map<String, dynamic> map) => HomeAsset(
        id: map['id'] as String,
        name: map['name'] as String,
        category: map['category'] as String,
        brand: (map['brand'] as String?) ?? '',
        model: (map['model'] as String?) ?? '',
        purchaseDate: map['purchaseDate'] == null ? null : DateTime.tryParse(map['purchaseDate'] as String),
        price: (map['price'] as num?)?.toDouble(),
        warrantyExpiry: map['warrantyExpiry'] == null ? null : DateTime.tryParse(map['warrantyExpiry'] as String),
        notes: (map['notes'] as String?) ?? '',
      );

  String toJson() => jsonEncode(toMap());
  factory HomeAsset.fromJson(String source) => HomeAsset.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
DART

cat > lib/services/asset_store.dart <<'DART'
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_asset.dart';

class AssetStore {
  static const _key = 'homelife_assets_v1';

  Future<List<HomeAsset>> loadAssets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    final assets = raw.map((e) {
      try { return HomeAsset.fromJson(e); } catch (_) { return null; }
    }).whereType<HomeAsset>().toList();
    assets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return assets;
  }

  Future<void> addAsset(HomeAsset asset) async {
    final prefs = await SharedPreferences.getInstance();
    final assets = await loadAssets()..add(asset);
    await prefs.setStringList(_key, assets.map((e) => e.toJson()).toList());
  }

  Future<void> deleteAsset(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final assets = await loadAssets()..removeWhere((e) => e.id == id);
    await prefs.setStringList(_key, assets.map((e) => e.toJson()).toList());
  }
}
DART

cat > lib/screens/house/add_asset_screen.dart <<'DART'
import 'package:flutter/material.dart';
import '../../models/home_asset.dart';
import '../../services/asset_store.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});
  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();
  String _category = 'Elettrodomestico';
  DateTime? _purchaseDate;
  DateTime? _warrantyExpiry;
  bool _saving = false;

  static const _categories = [
    'Elettrodomestico','Elettronica','Impianto','Arredamento','Giardino','Piscina','Sicurezza','Smart Home','Altro'
  ];

  @override
  void dispose() {
    _name.dispose(); _brand.dispose(); _model.dispose(); _price.dispose(); _notes.dispose();
    super.dispose();
  }

  String _date(DateTime? d) => d == null ? 'Non impostata' : '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  Future<void> _pickPurchase() async {
    final d = await showDatePicker(context: context, initialDate: _purchaseDate ?? DateTime.now(), firstDate: DateTime(1990), lastDate: DateTime.now());
    if (d != null) setState(() => _purchaseDate = d);
  }

  Future<void> _pickWarranty() async {
    final d = await showDatePicker(context: context, initialDate: _warrantyExpiry ?? DateTime.now().add(const Duration(days:730)), firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days:365*15)));
    if (d != null) setState(() => _warrantyExpiry = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final p = _price.text.trim().replaceAll(',', '.');
    final asset = HomeAsset(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(), category: _category,
      brand: _brand.text.trim(), model: _model.text.trim(),
      purchaseDate: _purchaseDate, price: p.isEmpty ? null : double.tryParse(p),
      warrantyExpiry: _warrantyExpiry, notes: _notes.text.trim(),
    );
    await AssetStore().addAsset(asset);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo oggetto')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20,12,20,40),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText:'Nome', hintText:'Es. Lavastoviglie cucina', prefixIcon: Icon(Icons.label_outline)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci un nome' : null,
              ),
              const SizedBox(height:14),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText:'Categoria', prefixIcon: Icon(Icons.category_outlined)),
                items: _categories.map((e) => DropdownMenuItem(value:e, child:Text(e))).toList(),
                onChanged: (v) { if (v != null) setState(() => _category = v); },
              ),
              const SizedBox(height:14),
              Row(children:[
                Expanded(child: TextFormField(controller:_brand, decoration: const InputDecoration(labelText:'Marca'))),
                const SizedBox(width:12),
                Expanded(child: TextFormField(controller:_model, decoration: const InputDecoration(labelText:'Modello'))),
              ]),
              const SizedBox(height:14),
              TextFormField(controller:_price, keyboardType: const TextInputType.numberWithOptions(decimal:true), decoration: const InputDecoration(labelText:'Prezzo di acquisto', prefixIcon:Icon(Icons.euro))),
              const SizedBox(height:14),
              Card(child: Column(children:[
                ListTile(leading: const Icon(Icons.shopping_bag_outlined), title: const Text('Data di acquisto'), subtitle: Text(_date(_purchaseDate)), trailing: const Icon(Icons.chevron_right), onTap:_pickPurchase),
                const Divider(height:1),
                ListTile(leading: const Icon(Icons.verified_outlined), title: const Text('Scadenza garanzia'), subtitle: Text(_date(_warrantyExpiry)), trailing: const Icon(Icons.chevron_right), onTap:_pickWarranty),
              ])),
              const SizedBox(height:14),
              TextFormField(controller:_notes, maxLines:4, decoration: const InputDecoration(labelText:'Note', alignLabelWithHint:true)),
              const SizedBox(height:24),
              FilledButton.icon(onPressed:_saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Salvataggio...' : 'Salva oggetto')),
            ],
          ),
        ),
      ),
    );
  }
}
DART

cat > lib/screens/house/asset_detail_screen.dart <<'DART'
import 'package:flutter/material.dart';
import '../../models/home_asset.dart';
import '../../services/asset_store.dart';

class AssetDetailScreen extends StatelessWidget {
  final HomeAsset asset;
  const AssetDetailScreen({super.key, required this.asset});

  String _date(DateTime? d) => d == null ? 'Non indicata' : '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  String _price(double? p) => p == null ? 'Non indicato' : '€ ${p.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(context:context, builder:(context) => AlertDialog(
      title: const Text('Eliminare oggetto?'),
      content: Text('Vuoi eliminare "${asset.name}"?'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false), child:const Text('Annulla')),
        FilledButton(onPressed:()=>Navigator.pop(context,true), child:const Text('Elimina')),
      ],
    ));
    if (ok == true) {
      await AssetStore().deleteAsset(asset.id);
      if (context.mounted) Navigator.pop(context,true);
    }
  }

  Widget _row(BuildContext context, IconData icon, String title, String value) => ListTile(
    contentPadding:EdgeInsets.zero,
    leading:CircleAvatar(backgroundColor:Theme.of(context).colorScheme.primaryContainer, child:Icon(icon)),
    title:Text(title), subtitle:Text(value, style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600)),
  );

  @override
  Widget build(BuildContext context) {
    final bm = [if(asset.brand.isNotEmpty) asset.brand, if(asset.model.isNotEmpty) asset.model].join(' ');
    return Scaffold(
      appBar:AppBar(title:Text(asset.name), actions:[IconButton(onPressed:()=>_delete(context), icon:const Icon(Icons.delete_outline))]),
      body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(20,8,20,40), children:[
        Container(
          padding:const EdgeInsets.all(22),
          decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer, borderRadius:BorderRadius.circular(24)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
            const Icon(Icons.inventory_2_outlined,size:38), const SizedBox(height:18),
            Text(asset.name, style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
            const SizedBox(height:6), Text(asset.category), if(bm.isNotEmpty) Text(bm),
          ]),
        ),
        const SizedBox(height:16),
        _row(context,Icons.shopping_bag_outlined,'Acquistato',_date(asset.purchaseDate)),
        _row(context,Icons.euro,'Prezzo',_price(asset.price)),
        _row(context,Icons.verified_outlined,'Garanzia',_date(asset.warrantyExpiry)),
        const SizedBox(height:16),
        Text('Collegamenti', style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
        const SizedBox(height:10),
        const Card(child:Column(children:[
          ListTile(leading:Icon(Icons.description_outlined), title:Text('Documenti'), subtitle:Text('Fatture, manuali e garanzie'), trailing:Text('Prossimamente')),
          Divider(height:1),
          ListTile(leading:Icon(Icons.home_repair_service_outlined), title:Text('Manutenzioni'), subtitle:Text('Storico e prossimi interventi'), trailing:Text('Prossimamente')),
          Divider(height:1),
          ListTile(leading:Icon(Icons.sensors_outlined), title:Text('Smart Home'), subtitle:Text('Stato e controllo dispositivo'), trailing:Text('Prossimamente')),
        ])),
        if(asset.notes.trim().isNotEmpty) ...[
          const SizedBox(height:18),
          Text('Note', style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
          const SizedBox(height:8), Card(child:Padding(padding:const EdgeInsets.all(16), child:Text(asset.notes))),
        ],
      ])),
    );
  }
}
DART

cat > lib/screens/house/house_screen.dart <<'DART'
import 'package:flutter/material.dart';
import '../../models/home_asset.dart';
import '../../services/asset_store.dart';
import 'add_asset_screen.dart';
import 'asset_detail_screen.dart';

class HouseScreen extends StatefulWidget {
  const HouseScreen({super.key});
  @override
  State<HouseScreen> createState() => _HouseScreenState();
}

class _HouseScreenState extends State<HouseScreen> {
  final _store = AssetStore();
  bool _loading = true;
  List<HomeAsset> _assets = [];

  @override
  void initState() { super.initState(); _reload(); }

  Future<void> _reload() async {
    final a = await _store.loadAssets();
    if (!mounted) return;
    setState(() { _assets = a; _loading = false; });
  }

  Future<void> _add() async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder:(_) => const AddAssetScreen()));
    if (changed == true) await _reload();
  }

  Future<void> _open(HomeAsset asset) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder:(_) => AssetDetailScreen(asset:asset)));
    if (changed == true) await _reload();
  }

  IconData _icon(String c) {
    switch(c) {
      case 'Elettrodomestico': return Icons.kitchen_outlined;
      case 'Elettronica': return Icons.devices_outlined;
      case 'Impianto': return Icons.settings_input_component_outlined;
      case 'Arredamento': return Icons.chair_outlined;
      case 'Giardino': return Icons.park_outlined;
      case 'Piscina': return Icons.pool_outlined;
      case 'Sicurezza': return Icons.shield_outlined;
      case 'Smart Home': return Icons.sensors_outlined;
      default: return Icons.inventory_2_outlined;
    }
  }

  Widget _tile(IconData i, String t, String s) => Card(
    margin:const EdgeInsets.only(bottom:10),
    child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:8), leading:CircleAvatar(child:Icon(i)), title:Text(t,style:const TextStyle(fontWeight:FontWeight.w700)), subtitle:Text(s), trailing:const Icon(Icons.chevron_right)),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(child:RefreshIndicator(onRefresh:_reload, child:ListView(
      padding:const EdgeInsets.fromLTRB(20,18,20,120),
      children:[
        Row(children:[
          Expanded(child:Text('Casa', style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold))),
          FilledButton.icon(onPressed:_add, icon:const Icon(Icons.add), label:const Text('Oggetto')),
        ]),
        const SizedBox(height:4),
        Text('La memoria digitale della tua casa.', style:Theme.of(context).textTheme.bodyLarge?.copyWith(color:Colors.grey.shade600)),
        const SizedBox(height:24),
        _tile(Icons.grid_view_rounded,'Stanze','Organizza casa per ambienti'),
        _tile(Icons.directions_car_outlined,'Veicoli','Auto, moto e altri mezzi'),
        _tile(Icons.home_repair_service_outlined,'Manutenzioni','Interventi fatti e prossime scadenze'),
        const SizedBox(height:24),
        Row(children:[Expanded(child:Text('Oggetti',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))), Text('${_assets.length}')]),
        const SizedBox(height:12),
        if(_loading)
          const Padding(padding:EdgeInsets.all(30), child:Center(child:CircularProgressIndicator()))
        else if(_assets.isEmpty)
          Container(
            padding:const EdgeInsets.all(24),
            decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22)),
            child:Column(children:[
              Icon(Icons.inventory_2_outlined,size:44,color:Theme.of(context).colorScheme.primary),
              const SizedBox(height:14), const Text('Nessun oggetto registrato',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
              const SizedBox(height:6), const Text('Aggiungi il primo elettrodomestico, impianto o dispositivo della casa.',textAlign:TextAlign.center),
              const SizedBox(height:16), FilledButton.icon(onPressed:_add, icon:const Icon(Icons.add), label:const Text('Aggiungi il primo oggetto')),
            ]),
          )
        else
          ..._assets.map((asset) => Card(
            margin:const EdgeInsets.only(bottom:10),
            child:ListTile(
              contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
              leading:CircleAvatar(child:Icon(_icon(asset.category))),
              title:Text(asset.name,style:const TextStyle(fontWeight:FontWeight.w700)),
              subtitle:Text([asset.category, if(asset.brand.isNotEmpty) asset.brand].join(' • ')),
              trailing:const Icon(Icons.chevron_right),
              onTap:()=>_open(asset),
            ),
          )),
      ],
    )));
  }
}
DART

echo ""
echo "🔎 flutter analyze"
flutter analyze

echo ""
echo "✅ HomeLife v0.2 installata."
echo "Avvia con: flutter run"
