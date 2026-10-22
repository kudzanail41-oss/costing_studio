import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/costing_project.dart';
import '../services/costing_store.dart';
import '../services/costing_export.dart';
import '../widgets/cost_edit_sheet.dart';

String rand(num value) {
  final minus = value < 0 ? '-' : '';
  final parts = value.abs().toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '${minus}R$whole.${parts[1]}';
}

String marginText(double margin) => '${margin.toStringAsFixed(2)}%';

class CostingHomeScreen extends StatefulWidget {
  const CostingHomeScreen({super.key, required this.store});
  final CostingStore store;

  @override
  State<CostingHomeScreen> createState() => _CostingHomeScreenState();
}

class _CostingHomeScreenState extends State<CostingHomeScreen> {
  late TextEditingController product;
  late TextEditingController client;
  late TextEditingController description;
  late TextEditingController quantity;
  late TextEditingController selling;
  late TextEditingController customTarget;

  CostingStore get store => widget.store;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    product = TextEditingController();
    client = TextEditingController();
    description = TextEditingController();
    quantity = TextEditingController();
    selling = TextEditingController();
    customTarget = TextEditingController();
    _syncInputs();
  }

  void _syncInputs() {
    final p = store.current;
    product.text = p.product;
    client.text = p.client;
    description.text = p.description;
    quantity.text = p.quantity.toString();
    selling.text = p.sellingPrice.toStringAsFixed(2);
    customTarget.text = p.targetMargin.toStringAsFixed(1);
  }

  @override
  void dispose() {
    for (final c in [product, client, description, quantity, selling, customTarget]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 900, maxHeight: 900, imageQuality: 72,
      );
      if (selected == null || !mounted) return;
      final bytes = await selected.readAsBytes();
      // Keep storage small for the offline MVP.
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        throw Exception('Image is too large after compression. Choose another image.');
      }
      store.current.imageBase64 = base64Encode(bytes);
      store.changed();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image could not be added: $e')));
    }
  }

  Future<void> _editCost([CostLine? line]) async {
    final result = await showModalBottomSheet<CostDraft>(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: false,
      builder: (_) => CostEditSheet(categories: store.categories, initial: line),
    );
    if (result != null) {
      store.addOrUpdateCost(id: line?.id, name: result.name, amount: result.amount);
    }
  }

  Future<void> _confirmDelete() async {
    if (store.projects.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keep at least one project.')));
      return;
    }
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete this costing?'),
      content: Text('"${store.current.product}" will be removed from this device.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ));
    if (accepted == true) {
      store.deleteCurrent();
      _syncInputs();
    }
  }

  Future<void> _showExportOptions() async {
    if (_exporting) return;
    final exportPdf = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(
              title: Text('Export full cost breakdown',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              subtitle: Text('Includes all cost items, project totals and GP calculations.'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Download PDF'),
              subtitle: const Text('Formatted report with your product photo'),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Download Excel-compatible CSV'),
              subtitle: const Text('Editable cost amounts; no live spreadsheet formulas'),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
          ]),
        ),
      ),
    );
    if (exportPdf == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final saved = await CostingExport.save(store.current, asPdf: exportPdf);
      if (!mounted || saved == null) return; // User cancelled the file dialog.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Cost breakdown ${exportPdf ? 'PDF' : 'CSV'} saved.'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save cost breakdown: $error'),
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _sectionHeader(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
    ]),
  );

  Widget _numberField(String label, TextEditingController controller, void Function(String) onChange,
      {String? prefix, bool integers = false}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integers),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(integers ? r'[0-9]' : r'[0-9.,]'))],
      decoration: InputDecoration(labelText: label, prefixText: prefix),
      onChanged: onChange,
    );
  }

  Widget _overviewCard(CostingProject p) {
    final good = p.targetMet;
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF22282A), borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('CURRENT GROSS PROFIT MARGIN',
              style: TextStyle(color: Colors.white.withOpacity(.68), fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 1))),
          Tooltip(message: '(Selling price − unit cost) ÷ selling price × 100',
              child: Icon(Icons.info_outline, color: Colors.white.withOpacity(.6), size: 18)),
        ]),
        const SizedBox(height: 6),
        Text(marginText(p.gpMargin), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900,
          letterSpacing: -1.7, color: Colors.white)),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: p.targetMargin <= 0 ? 0 : (p.gpMargin / p.targetMargin).clamp(0, 1).toDouble(),
            minHeight: 7, backgroundColor: const Color(0xFF465052),
            valueColor: AlwaysStoppedAnimation(good ? const Color(0xFF7FC6A4) : const Color(0xFFE9C24D)),
          )),
        const SizedBox(height: 12),
        Row(children: [
          Icon(good ? Icons.check_circle_outline : Icons.tune_outlined,
              color: good ? const Color(0xFF89D7B4) : const Color(0xFFF1C84C), size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(
              p.sellingPrice <= 0 ? 'Enter a selling price to calculate GP' :
              good ? 'At or above target · ${marginText(p.targetMargin)}' :
              'Target ${marginText(p.targetMargin)} · Reduce costs by ${rand(p.reductionRequired)} / unit',
              style: const TextStyle(color: Colors.white, fontSize: 13))),
        ]),
      ]),
    );
  }

  /// Always show guidance for the selected target, even when current GP is
  /// already greater than 30/40/50%. This is advisory; no costs are edited.
  Widget _targetAdviceCard(CostingProject p) {
    final hasPrice = p.sellingPrice > 0;
    final hasCosts = p.costs.isNotEmpty && p.costPerUnit > 0;
    final shortfall = p.reductionRequired > 0.005;
    final headroom = p.availableCostHeadroom > 0.005;

    Widget numberRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5E686B)))),
        const SizedBox(width: 10),
        Text(value, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );

    final title = !hasPrice ? 'Enter a selling price' :
        !hasCosts ? 'Add your production costs' :
        shortfall ? 'A cost adjustment is needed' :
        headroom ? 'You are above your GP target' :
        'You are on your GP target';

    String explanation;
    if (!hasPrice) {
      explanation = 'Set the unit selling price above to calculate the '
          'maximum cost allowed for your selected GP target.';
    } else if (!hasCosts) {
      explanation = 'Add cost items to receive realistic suggestions. '
          'A zero-cost product gives a misleading GP margin.';
    } else if (shortfall) {
      explanation = 'To reach ${marginText(p.targetMargin)} while keeping '
          'the selling price at ${rand(p.sellingPrice)}, reduce production '
          'costs by ${rand(p.reductionRequired)} per unit '
          '(${rand(p.projectReductionRequired)} for ${p.quantity} units). '
          'Alternatively, raise the selling price by '
          '${rand(p.priceIncreaseRequired)} to at least '
          '${rand(p.requiredSellingPrice)} per unit.';
    } else if (headroom) {
      explanation = 'Your current GP is ${marginText(p.gpMargin)}, which is '
          '${p.marginDifference.toStringAsFixed(2)} percentage points above '
          'your ${marginText(p.targetMargin)} target. You can accommodate '
          'up to ${rand(p.availableCostHeadroom)} MORE production cost per '
          'unit (${rand(p.availableProjectHeadroom)} overall) before falling '
          'below the target. Or, keeping costs fixed, you could reduce your '
          'selling price to ${rand(p.requiredSellingPrice)} per unit. '
          'Neither adjustment is required.';
    } else {
      explanation = 'Your existing costs and selling price already produce '
          'the selected ${marginText(p.targetMargin)} GP target. There is '
          'no extra cost allowance at this price.';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(shortfall ? Icons.tune_outlined : Icons.lightbulb_outline,
                size: 20, color: const Color(0xFF327783)),
            const SizedBox(width: 8),
            Expanded(child: Text('GP TARGET GUIDANCE · '
                '${marginText(p.targetMargin)}',
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 7),
          Text(explanation, style: const TextStyle(fontSize: 13, height: 1.5)),
          if (hasPrice && hasCosts) ...[
            const Divider(height: 22),
            numberRow('Current cost per unit', rand(p.costPerUnit)),
            numberRow('Maximum cost at ${marginText(p.targetMargin)} GP',
                rand(p.maximumCostForTarget)),
            numberRow(shortfall ? 'Cost reduction required / unit' :
                'Extra cost allowance / unit',
                rand(shortfall ? p.reductionRequired : p.availableCostHeadroom)),
            numberRow('Selling price for target GP',
                p.requiredSellingPrice.isFinite
                    ? rand(p.requiredSellingPrice) : 'N/A'),
            const SizedBox(height: 8),
            const Text('These are budget comparisons, not automatic changes. '
                'Edit individual cost items below to test your figures.',
                style: TextStyle(fontSize: 11,
                    color: Color(0xFF626D70), height: 1.5)),
          ],
        ]),
      ),
    );
  }

  /// One amount per line with a light separator: easier to scan on phones.
  Widget _summaryLine(String label, String value, {bool prominent = false}) =>
    Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(border: Border(
        bottom: BorderSide(color: Color(0xFFE2E5E5), width: .7))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: TextStyle(
          fontSize: 13, color: prominent ? const Color(0xFF252B2D) :
            const Color(0xFF5E686B),
          fontWeight: prominent ? FontWeight.w700 : FontWeight.normal))),
        const SizedBox(width: 12),
        Text(value, textAlign: TextAlign.right, style: TextStyle(
          fontSize: prominent ? 15 : 13,
          color: const Color(0xFF252B2D), fontWeight: FontWeight.w800)),
      ]),
    );

  Widget _targetSelector(CostingProject p) {
    final choices = [30.0, 40.0, 50.0];
    final isCustom = !choices.any((v) => (p.targetMargin - v).abs() < 0.0001);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Target GP margin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final target in choices)
          ChoiceChip(label: Text('${target.toInt()}%'), selected: (p.targetMargin - target).abs() < .0001,
            onSelected: (_) {p.targetMargin = target; store.changed();}),
        ChoiceChip(label: const Text('Custom'), selected: isCustom,
            onSelected: (_) {
              final parsed = double.tryParse(customTarget.text);
              final next = parsed != null && parsed.isFinite && parsed >= 0 && parsed < 100 &&
                  !choices.contains(parsed) ? parsed : 35.0;
              p.targetMargin = next;
              customTarget.text = next.toStringAsFixed(1);
              store.changed();
            }),
      ]),
      if (isCustom) ...[
        const SizedBox(height: 12),
        SizedBox(width: 190, child: TextField(
          controller: customTarget,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Custom margin', suffixText: '%'),
          onChanged: (value) {
            final n = double.tryParse(value.replaceAll(',', '.'));
            if (n != null && n.isFinite && n >= 0 && n < 100) {
              p.targetMargin = n;
              store.changed();
            }
          },
        )),
        const SizedBox(height: 4),
        Text('Enter a target from 0% to below 100%.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
      ],
    ]);
  }

  Widget _costGroups(CostingProject p) {
    return Column(children: [
      for (final group in groupOrder)
        if (p.costs.any((line) => groupFor(line.name) == group))
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              key: PageStorageKey('${p.id}-$group'),
              title: Text(group, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Text('${p.costs.where((line) => groupFor(line.name) == group).length} cost items',
                  style: const TextStyle(fontSize: 11)),
              // Let ExpansionTile display its normal arrow. No category totals:
              // overall totals are already visible in the summary below.
              children: [
                const Divider(height: 1),
                for (final line in p.costs.where((line) => groupFor(line.name) == group))
                  ListTile(
                    dense: true,
                    title: Text(line.name),
                    subtitle: const Text('Per unit', style: TextStyle(fontSize: 11)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(rand(line.unitCost), style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(tooltip: 'Edit item', icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _editCost(line)),
                      IconButton(tooltip: 'Remove item', icon: const Icon(Icons.close, size: 18),
                          onPressed: () => store.removeCost(line.id)),
                    ]),
                    onTap: () => _editCost(line),
                  ),
              ],
            ),
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: store, builder: (context, _) {
      final p = store.current;
      final isWide = MediaQuery.sizeOf(context).width > 560;
      return Scaffold(
        appBar: AppBar(title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calculate_outlined, size: 24), SizedBox(width: 8),
          Text('Costing Studio', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
        ]), actions: [
          IconButton(tooltip: 'New costing', icon: const Icon(Icons.add_circle_outline), onPressed: () {
            store.createProject(); _syncInputs();
          }),
          PopupMenuButton<String>(tooltip: 'Project actions', onSelected: (choice) {
            if (choice == 'copy') {store.duplicateCurrent(); _syncInputs();}
            if (choice == 'delete') _confirmDelete();
          }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'copy', child: Text('Duplicate project')),
            PopupMenuItem(value: 'delete', child: Text('Delete project')),
          ]),
        ]),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), children: [
            if (store.loadError != null)
              Padding(padding: const EdgeInsets.only(bottom: 12), child:
                Text(store.loadError!, style: const TextStyle(color: Colors.red))),
            Row(children: [
              const Text('PROJECT', style: TextStyle(fontWeight: FontWeight.w800,
                  letterSpacing: 1.1, fontSize: 11)),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                isExpanded: true, value: p.id, borderRadius: BorderRadius.circular(14),
                items: store.projects.map((project) => DropdownMenuItem(
                  value: project.id, child: Text(project.product, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (id) {if (id != null) {store.select(id); _syncInputs();}},
              ))),
            ]),
            const SizedBox(height: 10),
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
              InkWell(onTap: _pickPhoto, borderRadius: BorderRadius.circular(12), child:
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(
                  width: 84, height: 92, color: const Color(0xFFF0F0EE),
                  child: p.imageBase64 == null
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 28),
                        SizedBox(height: 5), Text('Add photo', style: TextStyle(fontSize: 10))])
                    : Image.memory(base64Decode(p.imageBase64!), fit: BoxFit.cover),
                )),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.product, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(p.client.isEmpty ? 'No client added' : p.client,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                const SizedBox(height: 8),
                TextButton.icon(onPressed: _pickPhoto,
                    icon: const Icon(Icons.image_outlined, size: 17), label: Text(p.imageBase64 == null ? 'Add product image' : 'Change image')),
              ])),
            ]))),
            const SizedBox(height: 14),
            Card(child: ExpansionTile(title: const Text('Product details',
              style: TextStyle(fontWeight: FontWeight.w700)), childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                TextField(controller: product, textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Product name'),
                  onChanged: (v) {p.product=v; store.changed();}),
                const SizedBox(height: 12),
                TextField(controller: client, textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Client'),
                  onChanged: (v) {p.client=v; store.changed();}),
                const SizedBox(height: 12),
                TextField(controller: description, maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes / specifications'),
                  onChanged: (v) {p.description=v; store.changed();}),
              ])),
            const SizedBox(height: 18),
            _sectionHeader('Pricing & quantity', 'Enter the selling price and number of units.'),
            if (isWide)
              Row(children: [
                Expanded(child: _numberField('Selling price / unit', selling,
                    (v) {p.sellingPrice = positiveNumber(v.replaceAll(',', '.')); store.changed();}, prefix: 'R ')),
                const SizedBox(width: 12),
                Expanded(child: _numberField('Quantity', quantity,
                    (v) {p.quantity = positiveNumber(v).toInt(); store.changed();}, integers: true)),
              ])
            else ...[
              _numberField('Selling price / unit', selling,
                  (v) {p.sellingPrice = positiveNumber(v.replaceAll(',', '.')); store.changed();}, prefix: 'R '),
              const SizedBox(height: 12),
              _numberField('Quantity', quantity,
                  (v) {p.quantity = positiveNumber(v).toInt(); store.changed();}, integers: true),
            ],
            const SizedBox(height: 20),
            _targetSelector(p),
            const SizedBox(height: 22),
            _overviewCard(p),
            const SizedBox(height: 12),
            _targetAdviceCard(p),
            const SizedBox(height: 18),
            _sectionHeader('Cost breakdown', 'Tap a section to edit unit costs.'),
            _costGroups(p),
            OutlinedButton.icon(onPressed: () => _editCost(), icon: const Icon(Icons.add),
                label: const Text('Add cost item'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48))),
            const SizedBox(height: 23),
            _sectionHeader('Project summary', 'All totals update as you edit costs.'),
            Card(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
              child: Column(children: [
                _summaryLine('Total cost per unit', rand(p.costPerUnit)),
                _summaryLine('Total project cost', rand(p.projectCost)),
                _summaryLine('Selling price per unit', rand(p.sellingPrice)),
                _summaryLine('Total sales revenue', rand(p.revenue)),
                _summaryLine('Gross profit per unit', rand(p.profitPerUnit)),
                _summaryLine('Total gross profit', rand(p.projectProfit),
                  prominent: true),
                _summaryLine('Actual GP margin', marginText(p.gpMargin),
                  prominent: true),
                _summaryLine('Target GP margin', marginText(p.targetMargin)),
              ]),
            )),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _exporting ? null : _showExportOptions,
              icon: _exporting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined),
              label: Text(_exporting ? 'Preparing download...' : 'Export full cost breakdown'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
            ),
            const SizedBox(height: 14),
            const Text('Gross profit margin = (selling price − cost) ÷ selling price × 100. '
              'Estimates only; verify supplier and production costs before quoting. '
              'Projects are stored locally on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF686F70), height: 1.5)),
          ]))),
      );
    });
  }
}
