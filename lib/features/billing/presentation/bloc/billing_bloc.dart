import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import '../../../../features/product/data/models/product_model.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/data/hive_database.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/order_model.dart';
import '../../../../core/services/cloud_sync_service.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;

  BillingBloc({required this.getProductByBarcodeUseCase})
      : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<ClearCartEvent>(_onClearCart);
    on<ApplyDiscountCodeEvent>(_onApplyDiscountCode);
    on<CheckoutEvent>(_onCheckout);
    on<PrintReceiptEvent>(_onPrintReceipt);
  }

  Future<void> _onScanBarcode(
      ScanBarcodeEvent event, Emitter<BillingState> emit) async {
    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: 'Product not found: ${event.barcode}')),
      (product) {
        add(AddProductToCartEvent(product));
      },
    );
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    // Clear error when adding
    final cleanState = state.copyWith(error: null);

    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.product.id == event.product.id);
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] =
          existingItem.copyWith(quantity: existingItem.quantity + 1);
      emit(cleanState.copyWith(cartItems: backendItems, error: null));
    } else {
      final newItem = CartItem(product: event.product);
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem], error: null));
    }
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  void _onUpdateQuantity(
      UpdateQuantityEvent event, Emitter<BillingState> emit) {
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    emit(const BillingState());
  }

  void _onApplyDiscountCode(ApplyDiscountCodeEvent event, Emitter<BillingState> emit) {
    final code = event.code.toUpperCase();
    
    // Check dynamic discountBox
    final discount = HiveDatabase.discountBox.values.where((d) => d.code.toUpperCase() == code).firstOrNull;
    
    if (discount != null) {
      emit(state.copyWith(discountPercentage: discount.percentage, discountCode: code));
    } else {
      emit(state.copyWith(error: 'Invalid discount code', clearError: false));
      emit(state.copyWith(clearError: true));
    }
  }

  Future<void> _onCheckout(CheckoutEvent event, Emitter<BillingState> emit) async {
    if (state.cartItems.isEmpty) return;

    final items = state.cartItems.map((c) => OrderItemModel.fromCartItem(c)).toList();
    final order = OrderModel(
      id: const Uuid().v4(),
      date: DateTime.now(),
      items: items,
      subtotal: state.subtotal,
      discount: state.discountAmount,
      tax: state.taxAmount,
      total: state.totalAmount,
    );

    // Deduct inventory
    for (final cartItem in state.cartItems) {
      final productModel = HiveDatabase.productBox.get(cartItem.product.id);
      if (productModel != null) {
        final product = productModel.toEntity();
        int availableStock = product.stock;

        // Auto-breakdown check: piece product running short
        if (product.unitType == 'pieces' &&
            cartItem.quantity > availableStock &&
            product.parentProductId != null) {
          final parentModel = HiveDatabase.productBox.get(product.parentProductId!);
          if (parentModel != null) {
            final neededPieces = cartItem.quantity - availableStock;
            final piecesPerCarton = product.piecesPerCarton <= 0 ? 1 : product.piecesPerCarton;
            final cartonsToBreak = (neededPieces / piecesPerCarton).ceil();

            // Decrement parent carton stock by cartonsToBreak
            final updatedParent = parentModel.toEntity().copyWith(
              stock: parentModel.stock - cartonsToBreak,
            );
            await HiveDatabase.productBox.put(updatedParent.id, ProductModel.fromEntity(updatedParent));

            // Increase piece stock by cartonsToBreak * piecesPerCarton
            availableStock += cartonsToBreak * piecesPerCarton;
          }
        }

        final updatedProduct = product.copyWith(
          stock: availableStock - cartItem.quantity,
        );
        await HiveDatabase.productBox.put(product.id, ProductModel.fromEntity(updatedProduct));
      }
    }

    await HiveDatabase.ordersBox.put(order.id, order);
    CloudSyncService.pushAll();

    emit(const BillingState().copyWith(lastOrder: order));
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    final printerHelper = PrinterHelper();

    if (!printerHelper.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          emit(state.copyWith(
              error: 'Failed to auto-connect to printer!', clearError: false));
          emit(state.copyWith(clearError: true));
          return;
        }
      } else {
        emit(state.copyWith(
            error: 'Printer not connected & no saved printer found!',
            clearError: false));
        emit(state.copyWith(clearError: true));
        return;
      }
    }

    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      final items = state.cartItems.isEmpty && state.lastOrder != null
          ? state.lastOrder!.items.map((item) => {
                'name': item.productName,
                'qty': item.quantity,
                'price': item.price,
                'total': item.price * item.quantity,
              }).toList()
          : state.cartItems
              .map((item) => {
                    'name': item.product.name,
                    'qty': item.quantity,
                    'price': item.product.price,
                    'total': item.total,
                  })
              .toList();

      final totalToPrint = state.cartItems.isEmpty && state.lastOrder != null
          ? state.lastOrder!.total
          : state.totalAmount;

      await printerHelper.printReceipt(
          shopName: event.shopName,
          address1: event.address1,
          address2: event.address2,
          phone: event.phone,
          items: items,
          total: totalToPrint,
          footer: event.footer);

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Print failed: $e', clearError: false));
      // Reset error instantly avoids sticky error
      emit(state.copyWith(clearError: true));
    }
  }
}
