import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gp_costing_studio/models/costing_project.dart';
import 'package:gp_costing_studio/services/costing_export.dart';

CostingProject sample() => CostingProject(
  id: 'example', product: 'Sample Product', client: '', description: '',
  quantity: 100, sellingPrice: 100, targetMargin: 30,
  costs: [
    CostLine(id: '1', name: 'Fabric', unitCost: 50),
    CostLine(id: '2', name: 'Labour', unitCost: 20),
  ],
);

void main() {
  test('CSV includes itemised costs and summary amounts', () {
    final p = sample();
    final csv = CostingExport.csvText(p);
    expect(csv.contains('"Fabric"'), isTrue);
    expect(csv.contains('"Labour"'), isTrue);
    expect(csv.contains('"Total cost per unit (ZAR)","70.00"'), isTrue);
    expect(csv.contains('"Total project cost (ZAR)","7000.00"'), isTrue);
    expect(csv.contains('"Actual GP margin (%)","30.00"'), isTrue);
  });
  test('CSV mitigates formula injection in custom names', () {
    final p = sample();
    p.product = '=2+2';
    p.costs.add(CostLine(id: '3', name: '+SUM(A1:A2)', unitCost: 3));
    final csv = CostingExport.csvText(p);
    expect(csv.contains('"\'=2+2"'), isTrue);
    expect(csv.contains('"\'+SUM(A1:A2)"'), isTrue);
    expect(CostingExport.csvBytes(p).take(3).toList(), [0xEF, 0xBB, 0xBF]);
  });
  test('PDF cost rows contain only actual line items, no group subtotals', () {
    final rows = CostingExport.pdfCostRows(sample());
    expect(rows, [
      ['Fabric', 'R50.00', 'R5,000.00'],
      ['Labour', 'R20.00', 'R2,000.00'],
    ]);
    expect(rows.length, sample().costs.length);
    expect(rows.expand((row) => row).join(' '), isNot(contains('Group subtotal')));
  });
  test('PDF generation produces a PDF document', () async {
    final bytes = await CostingExport.pdfBytes(sample());
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}
