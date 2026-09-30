import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_asset.dart';

class AssetStore {
  static const _key = 'homelife_assets_v1';

  Future<List<HomeAsset>> loadAssets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    final assets = raw
        .map((item) {
          try {
            return HomeAsset.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<HomeAsset>()
        .toList();

    assets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return assets;
  }

  Future<void> saveAssets(List<HomeAsset> assets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      assets.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> addAsset(HomeAsset asset) async {
    final assets = await loadAssets();
    assets.add(asset);
    await saveAssets(assets);
  }

  Future<void> updateAsset(HomeAsset updatedAsset) async {
    final assets = await loadAssets();
    final index = assets.indexWhere((asset) => asset.id == updatedAsset.id);

    if (index >= 0) {
      assets[index] = updatedAsset;
    } else {
      assets.add(updatedAsset);
    }

    await saveAssets(assets);
  }

  Future<void> deleteAsset(String id) async {
    final assets = await loadAssets();
    assets.removeWhere((asset) => asset.id == id);
    await saveAssets(assets);
  }
}
