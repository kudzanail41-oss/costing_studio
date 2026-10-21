import 'package:flutter/material.dart';
import '../models/costing_project.dart';

class CostDraft {
  CostDraft({required this.name, required this.amount});
  final String name;
  final double amount;
}

class CostEditSheet extends StatefulWidget {
  const CostEditSheet({super.key, required this.categories, this.initial});
  final List<String> categories;
  final CostLine? initial;

  @override
  State<CostEditSheet> createState() => _CostEditSheetState();
}

class _CostEditSheetState extends State<CostEditSheet> {
  static const customChoice = '_custom';
  late String selection;
  late TextEditingController customName;
  late TextEditingController unitCost;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    selection = initial != null && widget.categories.contains(initial.name)
        ? initial.name
        : widget.categories.first;
    customName = TextEditingController();
    unitCost = TextEditingController(text: initial == null ? '' : initial.unitCost.toStringAsFixed(2));
  }

  @override
  void dispose() {
    customName.dispose();
    unitCost.dispose();
    super.dispose();
  }

  void submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final name = selection == customChoice ? customName.text.trim() : selection;
    final amount = double.parse(unitCost.text.replaceAll(',', '.').trim());
    Navigator.of(context).pop(CostDraft(name: name, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(height: 4, width: 42,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(9)))),
                const SizedBox(height: 20),
                Text(widget.initial == null ? 'Add a cost item' : 'Edit cost item',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Costs are entered per unit, in rand.',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selection,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cost category'),
                  items: [
                    ...widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                    const DropdownMenuItem(value: customChoice, child: Text('＋ Add custom category')),
                  ],
                  onChanged: (value) => setState(() => selection = value ?? selection),
                ),
                if (selection == customChoice) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: customName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Custom item name', hintText: 'e.g. Eyelets'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter an item name' : null,
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: unitCost,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(prefixText: 'R ', labelText: 'Unit cost', hintText: '0.00'),
                  validator: (v) {
                    final num = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                    return num == null || !num.isFinite || num < 0 ? 'Enter a valid nonnegative amount' : null;
                  },
                  onFieldSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: submit, child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12), child: Text('Save cost item'))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
