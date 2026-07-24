import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/primary_button.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/billing_bloc.dart';

class ReceiptPreviewPage extends StatelessWidget {
  const ReceiptPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Digital Receipt'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              context.go('/home');
            },
          ),
        ),
        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            if (state.printSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Receipt printed successfully!'),
                backgroundColor: Colors.green,
              ));
            } else if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
              ));
            }
          },
          builder: (context, billingState) {
            final order = billingState.lastOrder;
            if (order == null) {
              return const Center(child: Text('No recent order found.'));
            }

            return BlocBuilder<ShopBloc, ShopState>(
              builder: (context, shopState) {
                String shopName = 'Shop';
                String address = '';
                String phone = '';
                String footer = '';

                if (shopState is ShopLoaded) {
                  shopName = shopState.shop.name;
                  address = '${shopState.shop.addressLine1}\n${shopState.shop.addressLine2}';
                  phone = shopState.shop.phoneNumber;
                  footer = shopState.shop.footerText;
                }

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(shopName.toUpperCase(),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(address, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text('Ph: $phone', style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 16),
                              Text(DateFormat('MMM dd, yyyy - hh:mm a').format(order.date), style: const TextStyle(fontSize: 12)),
                              const Divider(height: 32, thickness: 1),
                              
                              // Items
                              ...order.items.map((item) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text('${item.quantity} x ${item.productName}')),
                                        Text('₦${(item.price * item.quantity).toStringAsFixed(2)}'),
                                      ],
                                    ),
                                  )),
                              
                              const Divider(height: 32, thickness: 1),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal', style: TextStyle(color: Colors.grey)),
                                  Text('₦${order.subtotal.toStringAsFixed(2)}'),
                                ],
                              ),
                              if (order.discount > 0)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Discount', style: TextStyle(color: Colors.red)),
                                    Text('-₦${order.discount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
                                  ],
                                ),
                              if (order.tax > 0)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Tax', style: TextStyle(color: Colors.grey)),
                                    Text('+₦${order.tax.toStringAsFixed(2)}'),
                                  ],
                                ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  Text('₦${order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              ),
                              const Divider(height: 32, thickness: 1),
                              Text(footer, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
                      ),
                      child: PrimaryButton(
                        onPressed: () {
                          if (shopState is ShopLoaded) {
                            context.read<BillingBloc>().add(
                              PrintReceiptEvent(
                                shopName: shopState.shop.name,
                                address1: shopState.shop.addressLine1,
                                address2: shopState.shop.addressLine2,
                                phone: shopState.shop.phoneNumber,
                                footer: shopState.shop.footerText,
                              )
                            );
                          }
                        },
                        label: 'Print to Thermal Printer',
                        icon: Icons.print,
                        isLoading: billingState.isPrinting,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
