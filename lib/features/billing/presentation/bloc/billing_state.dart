part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final double discountPercentage;
  final String discountCode;
  final OrderModel? lastOrder;

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.discountPercentage = 0.0,
    this.discountCode = '',
    this.lastOrder,
  });

  double get subtotal => cartItems.fold(0, (sum, item) => sum + item.total);
  double get discountAmount => subtotal * discountPercentage;
  
  double get taxRate {
    final shop = HiveDatabase.shopBox.get('shop_details');
    return shop?.taxRate ?? 0.0;
  }
  
  double get taxAmount => (subtotal - discountAmount) * (taxRate / 100);
  
  double get totalAmount => (subtotal - discountAmount) + taxAmount;

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    double? discountPercentage,
    String? discountCode,
    OrderModel? lastOrder,
    bool clearLastOrder = false,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountCode: discountCode ?? this.discountCode,
      lastOrder: clearLastOrder ? null : (lastOrder ?? this.lastOrder),
    );
  }

  @override
  List<Object?> get props => [
        cartItems,
        error,
        isPrinting,
        printSuccess,
        discountPercentage,
        discountCode,
        lastOrder
      ];
}
