import 'package:equatable/equatable.dart';

class Shop extends Equatable {
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String phoneNumber;
  final String upiId;
  final String footerText;
  final double taxRate; // e.g. 7.5
  final String taxName; // e.g. "VAT"

  const Shop({
    this.name = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.phoneNumber = '',
    this.upiId = '',
    this.footerText = '',
    this.taxRate = 0.0,
    this.taxName = 'Tax',
  });

  Shop copyWith({
    String? name,
    String? addressLine1,
    String? addressLine2,
    String? phoneNumber,
    String? upiId,
    String? footerText,
    double? taxRate,
    String? taxName,
  }) {
    return Shop(
      name: name ?? this.name,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      upiId: upiId ?? this.upiId,
      footerText: footerText ?? this.footerText,
    );
  }

  @override
  List<Object?> get props =>
      [name, addressLine1, addressLine2, phoneNumber, upiId, footerText, taxRate, taxName];
}
