import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _barcode = '';
  double _price = 0.0;
  int _stock = 0;
  String _unitType = 'pieces';
  int? _lowStockThreshold;
  int _piecesPerCarton = 1;
  String? _parentProductId;
  late TextEditingController _barcodeController;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcode = result;
        _barcodeController.text = result;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final productState = context.read<ProductBloc>().state;
      final existingProduct =
          productState.products.where((p) => p.barcode == _barcode).firstOrNull;

      if (existingProduct != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product with barcode "$_barcode" already exists!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final product = Product(
        id: const Uuid().v4(),
        name: _name,
        barcode: _barcode,
        price: _price,
        stock: _stock,
        unitType: _unitType,
        lowStockThreshold: _lowStockThreshold,
        piecesPerCarton: _piecesPerCarton,
        parentProductId: _parentProductId,
      );

      context.read<ProductBloc>().add(AddProduct(product));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 28, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Add Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InputLabel(text: 'Barcode'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          decoration: const InputDecoration(
                            hintText: 'Scan or enter barcode',
                          ),
                          validator:
                              AppValidators.required('Please enter a barcode'),
                          onSaved: (value) => _barcode = _barcodeController.text.trim(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: _scanBarcode,
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap the icon to open camera scanner',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Product Name'),
                  TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'e.g. Basmati Rice',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a name'),
                    onSaved: (value) => _name = value!,
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Price'),
                  TextFormField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: '₦ ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    validator: AppValidators.price,
                    onSaved: (value) => _price = double.parse(value!),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const InputLabel(text: 'Initial Stock'),
                            TextFormField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: '0'),
                              validator: (value) => value!.isEmpty ? 'Required' : null,
                              onSaved: (value) => _stock = int.parse(value!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const InputLabel(text: 'Unit Type'),
                            DropdownButtonFormField<String>(
                              value: _unitType,
                              items: const [
                                DropdownMenuItem(value: 'pieces', child: Text('Pieces')),
                                DropdownMenuItem(value: 'bulk', child: Text('Bulk / Carton')),
                              ],
                              onChanged: (value) => setState(() => _unitType = value!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const InputLabel(text: 'Low Stock Alert Level (Optional)'),
                            TextFormField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: _unitType == 'bulk' ? 'Default: 10' : 'Default: 20',
                              ),
                              onSaved: (value) => _lowStockThreshold = int.tryParse(value ?? ''),
                            ),
                          ],
                        ),
                      ),
                      if (_unitType == 'pieces') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const InputLabel(text: 'Pieces per Carton'),
                              TextFormField(
                                initialValue: '1',
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: 'e.g. 12'),
                                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                                onSaved: (value) => _piecesPerCarton = int.parse(value!),
                              ),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                  if (_unitType == 'pieces') ...[
                    const SizedBox(height: 24),
                    const InputLabel(text: 'Link to Bulk Carton Product (Optional)'),
                    BlocBuilder<ProductBloc, ProductState>(
                      builder: (context, state) {
                        final bulkProducts = state.products.where((p) => p.unitType == 'bulk').toList();
                        return DropdownButtonFormField<String?>(
                          value: _parentProductId,
                          isExpanded: true,
                          hint: const Text('Select Bulk Product'),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('None (Standalone)')),
                            ...bulkProducts.map((p) => DropdownMenuItem<String?>(
                                  value: p.id,
                                  child: Text('${p.name} (Stock: ${p.stock})'),
                                )),
                          ],
                          onChanged: (val) => setState(() => _parentProductId = val),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _submit,
          icon: Icons.add_circle,
          label: 'Add Product',
        ));
  }
}
