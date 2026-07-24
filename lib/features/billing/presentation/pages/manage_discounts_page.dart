import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/data/hive_database.dart';
import '../../data/models/discount_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/input_label.dart';
import '../../../../core/services/cloud_sync_service.dart';

class ManageDiscountsPage extends StatefulWidget {
  const ManageDiscountsPage({super.key});

  @override
  State<ManageDiscountsPage> createState() => _ManageDiscountsPageState();
}

class _ManageDiscountsPageState extends State<ManageDiscountsPage> {
  final _codeController = TextEditingController();
  final _percentageController = TextEditingController();

  void _addDiscount() {
    if (_codeController.text.isEmpty || _percentageController.text.isEmpty) return;
    
    final code = _codeController.text.trim().toUpperCase();
    final percentage = double.tryParse(_percentageController.text.trim()) ?? 0.0;
    
    if (percentage <= 0 || percentage > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid percentage (1-100)')));
      return;
    }

    final discount = DiscountModel(code: code, percentage: percentage / 100.0);
    HiveDatabase.discountBox.put(code, discount);
    
    CloudSyncService.pushAll();
    
    _codeController.clear();
    _percentageController.clear();
    setState(() {});
  }

  void _deleteDiscount(String code) {
    HiveDatabase.discountBox.delete(code);
    CloudSyncService.pushAll();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final discounts = HiveDatabase.discountBox.values.toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Discounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add New Discount', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const InputLabel(text: 'Code'),
                            TextField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(hintText: 'e.g. SUMMER20'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const InputLabel(text: '% Off'),
                            TextField(
                              controller: _percentageController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'e.g. 20'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    onPressed: _addDiscount,
                    icon: Icons.add,
                    label: 'Create Discount',
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Active Discounts', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: discounts.isEmpty
                  ? const Center(child: Text('No active discounts.'))
                  : ListView.builder(
                      itemCount: discounts.length,
                      itemBuilder: (context, index) {
                        final d = discounts[index];
                        return Card(
                          child: ListTile(
                            title: Text(d.code, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${(d.percentage * 100).toStringAsFixed(0)}% Off'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteDiscount(d.code),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
