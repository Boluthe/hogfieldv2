import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/cart_item.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/domain/entities/role.dart';
import '../../../../core/data/hive_database.dart';
import '../../../product/data/models/product_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );

  bool _isCameraOn = true;
  bool _isFlashOn = false;
  TextEditingController? _searchController;

  // Cooldown mapping to prevent rapid firing of the same barcode
  final Map<String, DateTime> _lastScanTimes = {};

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    final now = DateTime.now();

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final rawValue = barcode.rawValue!;

        // Cooldown logic: 2 seconds per identical barcode
        if (_lastScanTimes.containsKey(rawValue)) {
          final lastScan = _lastScanTimes[rawValue]!;
          if (now.difference(lastScan).inSeconds < 2) {
            continue;
          }
        }

        _lastScanTimes[rawValue] = now;

        // Vibrate
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          Vibration.vibrate();
        }

        if (mounted) {
          context.read<BillingBloc>().add(ScanBarcodeEvent(rawValue));
        }
        break; // Process one barcode at a time per frame
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState.role == UserRole.none) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/login');
          });
          return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
        }

        if (authState.role == UserRole.admin) {
          return _buildAdminDashboard();
        }

        return Scaffold(
          body: BlocListener<BillingBloc, BillingState>(
        listenWhen: (previous, current) =>
            previous.error != current.error && current.error != null,
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Stack(
          children: [
            // SCANNER VIEW (TOP 50%)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.4,
              child: _buildScannerSection(),
            ),

            // BOTTOM PANEL (BOTTOM 50% + OVERLAP)
            Positioned(
              top: (MediaQuery.of(context).size.height * 0.4) - 24, // overlap
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
      bottomSheet:
          BlocBuilder<AuthBloc, AuthState>(builder: (context, authState) {
        if (authState.role == UserRole.staff) {
          return const SizedBox.shrink(); // Hide checkout for staff
        }
        return BlocBuilder<BillingBloc, BillingState>(builder: (context, state) {
          return PrimaryButton(
            onPressed: state.cartItems.isEmpty
                ? null
                : () async {
                    _scannerController.stop();
                    await context.push('/home/checkout');
                    if (_isCameraOn && mounted) _scannerController.start();
                  },
            icon: Icons.payment,
            label: 'Review Order',
          );
        });
      }),
    );
    });
  }

  Widget _buildAdminDashboard() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutEvent());
              context.go('/login');
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.admin_panel_settings, size: 80, color: AppTheme.primaryColor),
            const SizedBox(height: 24),
            const Text('Welcome, Admin', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            // Low Stock Alert
            Builder(
              builder: (context) {
                final lowStockCount = HiveDatabase.productBox.values.where((p) {
                  if (p.unitType == 'bulk' && p.stock < 10) return true;
                  if (p.unitType == 'pieces' && p.stock < 20) return true;
                  return false;
                }).length;

                if (lowStockCount > 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Low Stock Alert', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              Text('$lowStockCount item(s) are running low on stock!', style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/products'),
                          child: const Text('View', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
            ),
            const SizedBox(height: 48),
            PrimaryButton(
              icon: Icons.bar_chart,
              label: 'Sales Analytics',
              onPressed: () => context.push('/home/sales_history'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              icon: Icons.percent,
              label: 'Manage Discounts',
              onPressed: () => context.push('/manage_discounts'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              icon: Icons.settings,
              label: 'System Settings',
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
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

          // Overlay Actions (Top Right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Column(
              children: [
                _buildOverlayButton(
                  icon: Icons.lock_outline,
                  onPressed: () {
                    context.read<AuthBloc>().add(LogoutEvent());
                    context.go('/login');
                  },
                ),
                const SizedBox(height: 16),
                if (_isCameraOn)
                  _buildOverlayButton(
                    icon:
                        _isFlashOn ? Icons.flashlight_off : Icons.flashlight_on,
                    onPressed: () {
                      setState(() => _isFlashOn = !_isFlashOn);
                      _scannerController.toggleTorch();
                    },
                  ),
                if (_isCameraOn) const SizedBox(height: 16),
                _buildOverlayButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  // color:  Colors.white24 ,
                  onPressed: () {
                    setState(() {
                      _isCameraOn = !_isCameraOn;
                    });
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

          // Central Overlay Bounding Box
          if (_isCameraOn)
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Corners
                    _buildCorner(Alignment.topLeft),
                    _buildCorner(Alignment.topRight),
                    _buildCorner(Alignment.bottomLeft),
                    _buildCorner(Alignment.bottomRight),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraOffState() {
    return Container(
      color: const Color(0xFF1E293B), // slate-800
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFF334155), // slate-700
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child:
                const Icon(Icons.videocam_off, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera is turned off',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Turn on your camera to start scanning barcodes and items automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.videocam),
            label: const Text('Turn on Camera',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              setState(() => _isCameraOn = true);
              _scannerController.start();
            },
          )
        ],
      ),
    );
  }

  Widget _buildOverlayButton(
      {required IconData icon, required VoidCallback onPressed, Color? color}) {
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color ?? Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft ||
                    alignment == Alignment.topRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft ||
                    alignment == Alignment.bottomRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            left: (alignment == Alignment.topLeft ||
                    alignment == Alignment.bottomLeft)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            right: (alignment == Alignment.topRight ||
                    alignment == Alignment.bottomRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 15, offset: Offset(0, -5))
        ],
      ),
      child: Column(
        children: [
          // Drag handle indicator
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Autocomplete<ProductModel>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<ProductModel>.empty();
                }
                return HiveDatabase.productBox.values.where((ProductModel product) {
                  return product.name
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (ProductModel option) => option.name,
              onSelected: (ProductModel selection) async {
                final hasVibrator = await Vibration.hasVibrator();
                if (hasVibrator == true) {
                  Vibration.vibrate();
                }
                if (mounted) {
                  context.read<BillingBloc>().add(ScanBarcodeEvent(selection.barcode));
                }
                // Clear the search bar after selection so they can search again
                _searchController?.clear();
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                _searchController = textEditingController;
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search product by name...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        textEditingController.clear();
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
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

          // Header
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              final totalItems =
                  state.cartItems.fold<int>(0, (sum, i) => sum + i.quantity);
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Scanned Items',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        Text('$totalItems items total',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('TOTAL PRICE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.2)),
                        Text(
                          '₦${state.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),

          // List View
          Expanded(
            child: Stack(children: [
              BlocBuilder<BillingBloc, BillingState>(
                builder: (context, state) {
                  if (state.cartItems.isEmpty) {
                    return _buildEmptyCart();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(
                        left: 15, right: 15, top: 16, bottom: 100),
                    itemCount: state.cartItems.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = state.cartItems[index];
                      return _buildCartItemCard(context, item);
                    },
                  );
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child:
                Icon(Icons.shopping_basket, size: 40, color: Colors.grey[300]),
          ),
          const SizedBox(height: 16),
          const Text('List is empty',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Scanned items will appear here as you scan them with the camera above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(
    BuildContext context,
    CartItem item,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 1,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₦${item.product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _circularIconButton(
                    icon: Icons.remove,
                    onPressed: () {
                      if (item.quantity > 1) {
                        context.read<BillingBloc>().add(UpdateQuantityEvent(
                            item.product.id, item.quantity - 1));
                      } else {
                        context
                            .read<BillingBloc>()
                            .add(RemoveProductFromCartEvent(item.product.id));
                      }
                    }),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _circularIconButton(
                    icon: Icons.add,
                    onPressed: () {
                      context.read<BillingBloc>().add(UpdateQuantityEvent(
                          item.product.id, item.quantity + 1));
                    }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circularIconButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 20, color: Colors.grey[600]),
      ),
    );
  }

  // A floating Details/Checkout Button at the very bottom
  // Added a Stack wrapper below to overlay this button
}
