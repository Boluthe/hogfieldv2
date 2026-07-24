import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String
      id; // Using barcode as ID usually, but keeping separate ID is safer
  final String name;
  final String barcode;
  final double price;
  final int stock;
  final String unitType; // 'pieces' or 'bulk'
  final int? lowStockThreshold;
  final int piecesPerCarton;
  final String? parentProductId;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.stock = 0,
    this.unitType = 'pieces',
    this.lowStockThreshold,
    this.piecesPerCarton = 1,
    this.parentProductId,
  });

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    int? stock,
    String? unitType,
    int? lowStockThreshold,
    int? piecesPerCarton,
    String? parentProductId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      unitType: unitType ?? this.unitType,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      piecesPerCarton: piecesPerCarton ?? this.piecesPerCarton,
      parentProductId: parentProductId ?? this.parentProductId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        barcode,
        price,
        stock,
        unitType,
        lowStockThreshold,
        piecesPerCarton,
        parentProductId,
      ];
}
