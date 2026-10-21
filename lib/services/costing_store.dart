import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/starter_seed.dart';
import '../models/costing_project.dart';

/// MVP offline storage: a JSON array saved on this device/browser.
/// Future multi-user cloud sync should use a proper database, not preferences.
class CostingStore extends ChangeNotifier {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const _storageKey = 'gp_costing_projects_v1';

  List<CostingProject> projects = [];
  List<String> customCategories = [];
  String? selectedId;
  bool ready = false;
  String? loadError;
  Future<void> _writeQueue = Future<void>.value();

  CostingProject get current => projects.firstWhere(
        (p) => p.id == selectedId,
        orElse: () => projects.first,
      );

  List<String> get categories {
    final names = <String>{...defaultCategories, ...customCategories};
    for (final project in projects) {
      names.addAll(project.costs.map((e) => e.name));
    }
    return names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> load() async {
    try {
      final raw = await _preferences.getString(_storageKey);
      if (raw == null) {
        projects = [starterSeed()];
        selectedId = projects.first.id;
        _save();
      } else {
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        projects = (parsed['projects'] as List<dynamic>)
            .whereType<Map>()
            .map((p) => CostingProject.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        customCategories = (parsed['customCategories'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList();
        if (projects.isEmpty) projects = [starterSeed()];
        final savedId = parsed['selectedId'] as String?;
        selectedId = projects.any((p) => p.id == savedId) ? savedId : projects.first.id;
      }
    } catch (e) {
      loadError = 'Could not load saved projects. Existing data has not been overwritten.';
      projects = [starterSeed()];
      selectedId = projects.first.id;
    }
    ready = true;
    notifyListeners();
  }

  void _save() {
    if (loadError != null) return;
    final data = jsonEncode({
      'projects': projects.map((e) => e.toJson()).toList(),
      'customCategories': customCategories,
      'selectedId': selectedId,
    });
    _writeQueue = _writeQueue.then((_) => _preferences.setString(_storageKey, data))
        .catchError((Object e) {
          debugPrint('Costing Studio save failed: $e');
        });
  }

  void changed() {
    _save();
    notifyListeners();
  }

  void select(String id) {
    if (projects.any((p) => p.id == id)) {
      selectedId = id;
      changed();
    }
  }

  void createProject() {
    final id = newId();
    projects.insert(0, CostingProject(
      id: id,
      product: 'New product',
      client: '',
      description: '',
      quantity: 1,
      sellingPrice: 0,
      targetMargin: 30,
      costs: [],
    ));
    selectedId = id;
    changed();
  }

  void duplicateCurrent() {
    final p = current;
    final copy = CostingProject.fromJson(p.toJson());
    final id = newId();
    projects.insert(0, CostingProject(
      id: id,
      product: '${copy.product} (copy)',
      client: copy.client,
      description: copy.description,
      quantity: copy.quantity,
      sellingPrice: copy.sellingPrice,
      targetMargin: copy.targetMargin,
      costs: copy.costs.map((line) => CostLine(
        id: newId(), name: line.name, unitCost: line.unitCost,
      )).toList(),
      imageBase64: copy.imageBase64,
    ));
    selectedId = id;
    changed();
  }

  void deleteCurrent() {
    if (projects.length <= 1) return;
    projects.removeWhere((p) => p.id == selectedId);
    selectedId = projects.first.id;
    changed();
  }

  void addOrUpdateCost({String? id, required String name, required double amount}) {
    if (!categories.contains(name)) customCategories.add(name);
    final items = current.costs;
    final index = items.indexWhere((e) => e.id == id);
    if (index >= 0) {
      items[index].name = name;
      items[index].unitCost = amount;
    } else {
      items.add(CostLine(id: newId(), name: name, unitCost: amount));
    }
    changed();
  }

  void removeCost(String id) {
    current.costs.removeWhere((line) => line.id == id);
    changed();
  }
}
