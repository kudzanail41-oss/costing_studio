import 'dart:math' as math;

/// Amounts are stored as Rands PER UNIT. Quantities apply to all cost lines.
class CostLine {
  CostLine({required this.id, required this.name, required this.unitCost});

  final String id;
  String name;
  double unitCost;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unitCost': unitCost,
      };

  factory CostLine.fromJson(Map<String, dynamic> map) => CostLine(
        id: '${map['id'] ?? newId()}',
        name: '${map['name'] ?? 'Other'}',
        unitCost: positiveNumber(map['unitCost']),
      );
}

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

double positiveNumber(Object? input) {
  final value = switch (input) {
    num n => n.toDouble(),
    String s => double.tryParse(s.replaceAll(',', '').trim()) ?? 0,
    _ => 0.0,
  };
  return value.isFinite ? math.max(0, value) : 0;
}

class CostingProject {
  CostingProject({
    required this.id,
    required this.product,
    required this.client,
    required this.description,
    required this.quantity,
    required this.sellingPrice,
    required this.targetMargin,
    required this.costs,
    this.imageBase64,
  });

  final String id;
  String product;
  String client;
  String description;
  int quantity;
  double sellingPrice;
  double targetMargin;
  List<CostLine> costs;
  String? imageBase64;

  double get costPerUnit => costs.fold(0, (sum, line) => sum + line.unitCost);
  double get projectCost => costPerUnit * quantity;
  double get revenue => sellingPrice * quantity;
  double get profitPerUnit => sellingPrice - costPerUnit;
  double get projectProfit => revenue - projectCost;
  double get gpMargin => sellingPrice <= 0 ? 0 : profitPerUnit / sellingPrice * 100;
  double get maximumCostForTarget => sellingPrice * (1 - targetMargin / 100);
  double get reductionRequired => math.max(0, costPerUnit - maximumCostForTarget);
  double get requiredSellingPrice =>
      targetMargin >= 100 ? double.infinity : costPerUnit / (1 - targetMargin / 100);
  bool get targetMet => sellingPrice > 0 && gpMargin + 0.000001 >= targetMargin;

  Map<String, dynamic> toJson() => {
        'id': id,
        'product': product,
        'client': client,
        'description': description,
        'quantity': quantity,
        'sellingPrice': sellingPrice,
        'targetMargin': targetMargin,
        'costs': costs.map((e) => e.toJson()).toList(),
        'imageBase64': imageBase64,
      };

  factory CostingProject.fromJson(Map<String, dynamic> map) {
    final rawCosts = map['costs'];
    return CostingProject(
      id: '${map['id'] ?? newId()}',
      product: '${map['product'] ?? 'Untitled product'}',
      client: '${map['client'] ?? ''}',
      description: '${map['description'] ?? ''}',
      quantity: positiveNumber(map['quantity']).toInt(),
      sellingPrice: positiveNumber(map['sellingPrice']),
      targetMargin: positiveNumber(map['targetMargin']).clamp(0.0, 99.0).toDouble(),
      costs: rawCosts is List
          ? rawCosts.whereType<Map>().map((v) => CostLine.fromJson(Map<String, dynamic>.from(v))).toList()
          : [],
      imageBase64: map['imageBase64'] is String ? map['imageBase64'] as String : null,
    );
  }
}

const defaultCategories = <String>[
  'Labour',
  'Lining',
  'Finishes',
  'Webbing',
  'Glue',
  'Zips',
  'Thread',
  'UV Ink Branding',
  'Laser Branding',
  'Gold Foil Ink',
  'Packaging',
  'PU Leather',
  'Leather',
  'Fabric',
];

String groupFor(String category) {
  if (const {'PU Leather', 'Leather', 'Fabric'}.contains(category)) return 'Materials';
  if (const {'UV Ink Branding', 'Laser Branding', 'Gold Foil Ink'}.contains(category)) return 'Branding';
  if (category == 'Packaging') return 'Packaging';
  if (const {'Labour', 'Lining', 'Finishes', 'Webbing', 'Glue', 'Zips', 'Thread'}.contains(category)) {
    return 'Production & components';
  }
  return 'Other';
}

const groupOrder = <String>[
  'Materials', 'Production & components', 'Branding', 'Packaging', 'Other',
];
