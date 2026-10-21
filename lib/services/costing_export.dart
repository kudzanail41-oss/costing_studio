import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/costing_project.dart';

/// Full breakdown exports. All amounts in cost lines are per unit.
/// PDF is a presentation-ready report (including the product photo).
/// CSV opens in Excel/Sheets with editable amounts, but no live formulas.
class CostingExport {
  static String money(num value) {
    final negative = value < 0 ? '-' : '';
    final pieces = value.abs().toStringAsFixed(2).split('.');
    final whole = pieces.first.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    return '${negative}R$whole.${pieces.last}';
  }

  static String _number(num value) => value.toStringAsFixed(2);
  static String _percentage(double value) => '${value.toStringAsFixed(2)}%';

  static String fileName(CostingProject project) {
    final cleaned = project.product
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final shortName = cleaned.length > 48 ? cleaned.substring(0, 48) : cleaned;
    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return '${shortName.isEmpty ? 'Costing' : shortName}_Breakdown_$stamp';
  }

  static String _csvCell(Object? cell) {
    final isNumber = cell is num;
    var text = cell?.toString() ?? '';
    // Prevent imported project names, notes and category names from being
    // interpreted as spreadsheet formulas when opened in Excel/Sheets.
    if (!isNumber && RegExp(r'^[\s]*[=+@\-\t\r]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  static String _row(List<Object?> cells) =>
      cells.map(_csvCell).join(',');

  /// UTF-8 BOM helps Excel recognise Unicode text and currency labels.
  static Uint8List csvBytes(CostingProject project) =>
      Uint8List.fromList(utf8.encode('\uFEFF${csvText(project)}'));

  static String csvText(CostingProject project) {
    final rows = <List<Object?>>[
      ['COSTING STUDIO - FULL COST BREAKDOWN'],
      ['Product', project.product],
      ['Client', project.client],
      ['Description / specifications', project.description],
      ['Order quantity', project.quantity],
      ['Selling price per unit (ZAR)', _number(project.sellingPrice)],
      ['Target GP margin (%)', _number(project.targetMargin)],
      [],
      ['Group', 'Cost item', 'Unit cost (ZAR)', 'Quantity', 'Total project cost (ZAR)'],
    ];
    for (final group in groupOrder) {
      final lines = project.costs.where((c) => groupFor(c.name) == group);
      for (final line in lines) {
        rows.add([
          group,
          line.name,
          _number(line.unitCost),
          project.quantity,
          _number(line.unitCost * project.quantity),
        ]);
      }
    }
    rows.addAll([
      [],
      ['COSTING SUMMARY', 'Amount', '', '', ''],
      ['Total cost per unit (ZAR)', _number(project.costPerUnit)],
      ['Total project cost (ZAR)', _number(project.projectCost)],
      ['Selling price per unit (ZAR)', _number(project.sellingPrice)],
      ['Total sales revenue (ZAR)', _number(project.revenue)],
      ['Gross profit per unit (ZAR)', _number(project.profitPerUnit)],
      ['Total gross profit (ZAR)', _number(project.projectProfit)],
      ['Actual GP margin (%)', _number(project.gpMargin)],
      ['Target GP margin (%)', _number(project.targetMargin)],
      ['Target met?', project.targetMet ? 'Yes' : 'No'],
      ['Maximum cost per unit at target (ZAR)', _number(project.maximumCostForTarget)],
      ['Cost reduction needed per unit (ZAR)', _number(project.reductionRequired)],
      ['Total project cost reduction needed (ZAR)', _number(project.projectReductionRequired)],
      ['Additional cost allowance per unit (ZAR)', _number(project.availableCostHeadroom)],
      ['Additional project cost allowance (ZAR)', _number(project.availableProjectHeadroom)],
      ['Required selling price at target (ZAR)',
        project.requiredSellingPrice.isFinite ? _number(project.requiredSellingPrice) : 'N/A'],
      [],
      ['Calculation method', 'GP% = (selling price - unit cost) / selling price * 100'],
      ['Currency', 'ZAR'],
      ['Note', 'Cost lines are planning amounts per unit; verify actual supplier and production costs.'],
      ['Note', 'CSV contains export-time values, not live Excel formulas.'],
      ['Note', 'The product image, if selected, is included only in the PDF export.'],
    ]);
    return rows.map(_row).join('\r\n');
  }

  static Future<Uint8List> pdfBytes(CostingProject project) async {
    final document = pw.Document(
      title: '${project.product} - Cost breakdown',
      author: 'Costing Studio',
    );
    const charcoal = PdfColor.fromInt(0xFF252B2D);
    const gold = PdfColor.fromInt(0xFFD4AD44);
    const light = PdfColor.fromInt(0xFFF6F6F3);
    const muted = PdfColor.fromInt(0xFF667173);
    const green = PdfColor.fromInt(0xFF276F5A);

    pw.MemoryImage? productImage;
    if (project.imageBase64 != null) {
      try {
        productImage = pw.MemoryImage(base64Decode(project.imageBase64!));
      } catch (_) {
        // A missing or corrupt image must not prevent saving the costing.
      }
    }

    pw.Widget labelledValue(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(flex: 5, child: pw.Text(label,
          style: const pw.TextStyle(fontSize: 9, color: muted))),
        pw.Expanded(flex: 4, child: pw.Text(value, textAlign: pw.TextAlign.right,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: charcoal))),
      ]),
    );

    final tableData = <List<String>>[];
    for (final group in groupOrder) {
      final lines = project.costs.where((c) => groupFor(c.name) == group).toList();
      if (lines.isEmpty) continue;
      for (final line in lines) {
        tableData.add([
          group,
          line.name,
          money(line.unitCost),
          money(line.unitCost * project.quantity),
        ]);
      }
      tableData.add([
        group,
        'Group subtotal',
        money(lines.fold<double>(0, (sum, l) => sum + l.unitCost)),
        money(lines.fold<double>(0, (sum, l) => sum + l.unitCost) * project.quantity),
      ]);
    }

    document.addPage(pw.MultiPage(
      maxPages: 100,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(35, 37, 35, 40),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: gold, width: 1.5))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('COSTING STUDIO',
              style: pw.TextStyle(fontSize: 11, color: charcoal,
                  fontWeight: pw.FontWeight.bold, letterSpacing: 1.4)),
          pw.Text('FULL COST BREAKDOWN',
              style: const pw.TextStyle(fontSize: 8, color: muted)),
        ]),
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('All amounts in ZAR | Validate costs before quoting',
              style: const pw.TextStyle(fontSize: 8, color: muted)),
          pw.Text('Page ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: muted)),
        ],
      ),
      build: (context) => [
        pw.SizedBox(height: 20),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(project.product.isEmpty ? 'Untitled product' : project.product,
                style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold,
                    color: charcoal)),
              if (project.client.trim().isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text('Client: ${project.client}',
                    style: const pw.TextStyle(fontSize: 10, color: muted)),
              ],
              if (project.description.trim().isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text(project.description,
                    style: const pw.TextStyle(fontSize: 9, color: muted)),
              ],
            ],
          )),
          if (productImage != null) ...[
            pw.SizedBox(width: 20),
            pw.Container(
              height: 95, width: 104,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Image(productImage!, fit: pw.BoxFit.contain),
            ),
          ],
        ]),
        pw.SizedBox(height: 19),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          color: light,
          child: pw.Column(children: [
            labelledValue('Quantity', project.quantity.toString()),
            labelledValue('Selling price per unit', money(project.sellingPrice)),
            labelledValue('Target gross profit margin', _percentage(project.targetMargin)),
            labelledValue('Actual gross profit margin', _percentage(project.gpMargin)),
          ]),
        ),
        pw.SizedBox(height: 20),
        pw.Text('DETAILED COSTS', style: pw.TextStyle(
          fontSize: 12, fontWeight: pw.FontWeight.bold, color: charcoal)),
        pw.SizedBox(height: 8),
        if (tableData.isEmpty)
          pw.Text('No cost items entered.',
              style: const pw.TextStyle(fontSize: 10, color: muted))
        else
          pw.Table.fromTextArray(
            headers: ['Category', 'Cost item', 'Cost / unit', 'Total for project'],
            data: tableData,
            border: pw.TableBorder(
              horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: .35),
              bottom: const pw.BorderSide(color: PdfColors.grey300, width: .5),
            ),
            headerDecoration: const pw.BoxDecoration(color: charcoal),
            headerStyle: pw.TextStyle(color: PdfColors.white,
                fontSize: 9, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8.5, color: charcoal),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2.4),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(2),
            },
            cellAlignments: {
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
        pw.SizedBox(height: 23),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Column(children: [
            pw.Text('PROJECT SUMMARY',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: charcoal)),
            pw.SizedBox(height: 12),
            labelledValue('Total cost per unit', money(project.costPerUnit)),
            labelledValue('Total project cost', money(project.projectCost)),
            labelledValue('Selling price per unit', money(project.sellingPrice)),
            labelledValue('Total sales revenue', money(project.revenue)),
            labelledValue('Gross profit per unit', money(project.profitPerUnit)),
            labelledValue('Total gross profit', money(project.projectProfit)),
            pw.Divider(color: PdfColors.grey300),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('ACTUAL GP MARGIN', style: pw.TextStyle(
                color: charcoal, fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(_percentage(project.gpMargin), style: pw.TextStyle(
                color: project.targetMet ? green : charcoal,
                fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 6),
            labelledValue('Target GP margin', _percentage(project.targetMargin)),
            labelledValue('Target achieved', project.targetMet ? 'Yes' : 'No'),
            labelledValue('Maximum unit cost at target', money(project.maximumCostForTarget)),
            labelledValue('Cost reduction required per unit', money(project.reductionRequired)),
            labelledValue('Additional cost allowance per unit', money(project.availableCostHeadroom)),
            labelledValue('Additional project cost allowance', money(project.availableProjectHeadroom)),
            labelledValue('Required selling price at target',
                project.requiredSellingPrice.isFinite
                    ? money(project.requiredSellingPrice) : 'N/A'),
          ]),
        ),
        pw.SizedBox(height: 13),
        pw.Text('GP margin = (selling price per unit - total cost per unit) / selling price per unit x 100.',
          style: const pw.TextStyle(fontSize: 8, color: muted)),
      ],
    ));
    return document.save();
  }

  /// Returns null when a user cancels a native save-as dialog.
  static Future<String?> save(CostingProject project,
      {required bool asPdf}) async {
    // Freeze the values before async generation in case the project is edited.
    final snapshot = CostingProject.fromJson(project.toJson());
    final bytes = asPdf ? await pdfBytes(snapshot) : csvBytes(snapshot);
    final name = fileName(snapshot);
    final extension = asPdf ? 'pdf' : 'csv';
    final mime = asPdf ? MimeType.pdf : MimeType.csv;
    if (kIsWeb) {
      return FileSaver.instance.saveFile(
        name: name, bytes: bytes, fileExtension: extension, mimeType: mime,
      );
    }
    return FileSaver.instance.saveAs(
      name: name, bytes: bytes, fileExtension: extension, mimeType: mime,
    );
  }
}
