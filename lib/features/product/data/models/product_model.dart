import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';

part 'product_model.g.dart'; // Hive generator

@HiveType(typeId: 0)
class ProductModel extends Product {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String barcode;
  @override
  @HiveField(3)
  final double price;
  @override
  @HiveField(4, defaultValue: 0)
  final int stock;
  @override
  @HiveField(5, defaultValue: 'pieces')
  final String unitType;
  @override
  @HiveField(6)
  final int? lowStockThreshold;
  @override
  @HiveField(7, defaultValue: 1)
  final int piecesPerCarton;
  @override
  @HiveField(8)
  final String? parentProductId;

  const ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.stock,
    required this.unitType,
    this.lowStockThreshold,
    this.piecesPerCarton = 1,
    this.parentProductId,
  }) : super(
          id: id,
          name: name,
          barcode: barcode,
          price: price,
          stock: stock,
          unitType: unitType,
          lowStockThreshold: lowStockThreshold,
          piecesPerCarton: piecesPerCarton,
          parentProductId: parentProductId,
        );

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      price: product.price,
      stock: product.stock,
      unitType: product.unitType,
      lowStockThreshold: product.lowStockThreshold,
      piecesPerCarton: product.piecesPerCarton,
      parentProductId: product.parentProductId,
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      price: price,
      stock: stock,
      unitType: unitType,
      lowStockThreshold: lowStockThreshold,
      piecesPerCarton: piecesPerCarton,
      parentProductId: parentProductId,
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      barcode: json['barcode'] as String,
      price: (json['price'] as num).toDouble(),
      stock: json['stock'] as int,
      unitType: json['unitType'] as String? ?? 'pieces',
      lowStockThreshold: json['lowStockThreshold'] as int?,
      piecesPerCarton: json['piecesPerCarton'] as int? ?? 1,
      parentProductId: json['parentProductId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'stock': stock,
      'unitType': unitType,
      'lowStockThreshold': lowStockThreshold,
      'piecesPerCarton': piecesPerCarton,
      'parentProductId': parentProductId,
    };
  }
}
