import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String
      id; // Using barcode as ID usually, but keeping separate ID is safer
  final String name;
  final String barcode;
  final double price;
  final int stock;
  final String unitType; // 'pieces' or 'bulk'

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.stock = 0,
    this.unitType = 'pieces',
  });

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    int? stock,
    String? unitType,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      unitType: unitType ?? this.unitType,
    );
  }

  @override
  List<Object?> get props => [id, name, barcode, price, stock, unitType];
}
