import 'package:flutter_test/flutter_test.dart';
import 'package:gp_costing_studio/data/starter_seed.dart';
import 'package:gp_costing_studio/models/costing_project.dart';

CostingProject example() => CostingProject(
  id: 'example', product: 'Sample Product', client: '', description: '',
  quantity: 100, sellingPrice: 100, targetMargin: 30,
  costs: [
    CostLine(id: '1', name: 'Fabric', unitCost: 50),
    CostLine(id: '2', name: 'Labour', unitCost: 20),
  ],
);

void main() {
  test('Public starter contains no confidential customer amounts', () {
    final project = starterSeed();
    expect(project.costs, isEmpty);
    expect(project.quantity, 1);
    expect(project.sellingPrice, 0);
    expect(project.targetMargin, 30);
  });
  test('Gross profit math works at a 30% target', () {
    final p = example();
    expect(p.costPerUnit, closeTo(70, 1e-6));
    expect(p.projectCost, closeTo(7000, 1e-6));
    expect(p.revenue, closeTo(10000, 1e-6));
    expect(p.profitPerUnit, closeTo(30, 1e-6));
    expect(p.projectProfit, closeTo(3000, 1e-6));
    expect(p.gpMargin, closeTo(30, 1e-6));
    expect(p.targetMet, isTrue);
  });
  test('Targets 40% and 50% show necessary reductions', () {
    final p = example()..targetMargin = 40;
    expect(p.maximumCostForTarget, closeTo(60, 1e-6));
    expect(p.reductionRequired, closeTo(10, 1e-6));
    p.targetMargin = 50;
    expect(p.maximumCostForTarget, closeTo(50, 1e-6));
    expect(p.reductionRequired, closeTo(20, 1e-6));
  });
  test('Zero selling price avoids division by zero', () {
    final p = example()..sellingPrice = 0;
    expect(p.gpMargin, 0);
    expect(p.targetMet, isFalse);
  });
}
