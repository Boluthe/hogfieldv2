import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/sound_helper.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../product/data/models/product_model.dart';

class StaffScannerView extends StatefulWidget {
  const StaffScannerView({super.key});

  @override
  State<StaffScannerView> createState() => _StaffScannerViewState();
}

class _StaffScannerViewState extends State<StaffScannerView> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );

  bool _isCameraOn = true;
  bool _isFlashOn = false;
  ProductModel? _scannedProduct;
  TextEditingController? _searchController;

  Timer? _timer;
  int _secondsRemaining = 15;
  static const int _maxDuration = 15;

  DateTime? _lastScanTime;
  String? _lastScanBarcode;

  @override
  void dispose() {
    _timer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  void _onProductScanned(ProductModel product) {
    SoundHelper.playScanSound();

    _timer?.cancel();
    setState(() {
      _scannedProduct = product;
      _secondsRemaining = _maxDuration;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _clearScannedProduct();
        }
      });
    });
  }

  void _clearScannedProduct() {
    _timer?.cancel();
    setState(() {
      _scannedProduct = null;
      _secondsRemaining = _maxDuration;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    final now = DateTime.now();

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final rawValue = barcode.rawValue!;

        if (_lastScanBarcode == rawValue && _lastScanTime != null) {
          if (now.difference(_lastScanTime!).inMilliseconds < 1500) {
            continue;
          }
        }

        _lastScanBarcode = rawValue;
        _lastScanTime = now;

        final product = HiveDatabase.productBox.values.firstWhere(
          (p) => p.barcode == rawValue,
          orElse: () => const ProductModel(
            id: '',
            name: '',
            barcode: '',
            price: 0,
            stock: 0,
            unitType: '',
          ),
        );

        if (product.id.isNotEmpty) {
          _onProductScanned(product);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No product found for barcode: $rawValue'),
                backgroundColor: Colors.orange[800],
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text(
              'Staff Price Checker',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () {
              context.read<AuthBloc>().add(LogoutEvent());
              context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Scanner Area
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: _buildScannerSection(),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Autocomplete<ProductModel>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<ProductModel>.empty();
                }
                return HiveDatabase.productBox.values.where((ProductModel product) {
                  return product.name
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()) ||
                      product.barcode.contains(textEditingValue.text);
                });
              },
              displayStringForOption: (ProductModel option) => option.name,
              onSelected: (ProductModel selection) {
                _onProductScanned(selection);
                _searchController?.clear();
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                _searchController = textEditingController;
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search product by name or barcode...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () => textEditingController.clear(),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                );
              },
            ),
          ),

          // Main Display: Single Product Large Card or Empty State
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _scannedProduct != null
                  ? _buildLargeProductCard(_scannedProduct!)
                  : _buildEmptyState(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          if (!_isCameraOn) _buildCameraOffState(),

          // Overlay Actions
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                if (_isCameraOn)
                  _buildOverlayButton(
                    icon: _isFlashOn ? Icons.flashlight_off : Icons.flashlight_on,
                    onPressed: () {
                      setState(() => _isFlashOn = !_isFlashOn);
                      _scannerController.toggleTorch();
                    },
                  ),
                const SizedBox(height: 8),
                _buildOverlayButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  onPressed: () {
                    setState(() => _isCameraOn = !_isCameraOn);
                    if (_isCameraOn) {
                      _scannerController.start();
                    } else {
                      _scannerController.stop();
                    }
                  },
                ),
              ],
            ),
          ),

          // Bounding Box
          if (_isCameraOn)
            Center(
              child: Container(
                width: 200,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraOffState() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white70, size: 40),
          const SizedBox(height: 8),
          const Text('Camera Turned Off', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.videocam),
            label: const Text('Turn On Camera'),
            onPressed: () {
              setState(() => _isCameraOn = true);
              _scannerController.start();
            },
          )
        ],
      ),
    );
  }

  Widget _buildOverlayButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ready to Scan',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Point the camera at an item barcode or search above to view price and product information.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeProductCard(ProductModel product) {
    final double progress = _secondsRemaining / _maxDuration;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timer Progress Bar Header
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _secondsRemaining <= 5 ? Colors.redAccent : AppTheme.primaryColor,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Clearing in ${_secondsRemaining}s',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _secondsRemaining <= 5 ? Colors.red : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearScannedProduct,
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Main Product Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Product Name
                  Text(
                    product.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PRICE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'UNIT PRICE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₦${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stock & Details Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailCard(
                          icon: Icons.inventory_2_outlined,
                          title: 'Stock Available',
                          value: '${product.stock} ${product.unitType}',
                          valueColor: product.stock <= (product.lowStockThreshold ?? 5)
                              ? Colors.red[700]!
                              : Colors.green[700]!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailCard(
                          icon: Icons.category_outlined,
                          title: 'Unit Type',
                          value: product.unitType.toUpperCase(),
                          valueColor: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailCard(
                          icon: Icons.qr_code,
                          title: 'Barcode',
                          value: product.barcode.isEmpty ? 'N/A' : product.barcode,
                          valueColor: Colors.black87,
                        ),
                      ),
                      if (product.unitType == 'bulk') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDetailCard(
                            icon: Icons.widgets_outlined,
                            title: 'Pieces/Carton',
                            value: '${product.piecesPerCarton}',
                            valueColor: Colors.black87,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
