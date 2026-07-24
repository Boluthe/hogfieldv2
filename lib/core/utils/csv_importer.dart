import 'package:flutter/services.dart';
import '../../features/product/data/models/product_model.dart';
import '../data/hive_database.dart';
import 'package:uuid/uuid.dart';

class CsvImporter {
  static Future<void> seedProductsIfEmpty() async {
    final productBox = HiveDatabase.productBox;

    if (productBox.isNotEmpty) {
      return; // Database already seeded
    }

    try {
      final String csvString =
          await rootBundle.loadString('assets/products.csv');
      final List<String> lines = csvString.split('\n');

      if (lines.isEmpty) return;

      final Map<dynamic, ProductModel> productsToInsert = {};

      // Start from 1 to skip the header row
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final List<String> row = line.split(',');

        if (row.length >= 14) {
          final String id = row[0].isNotEmpty ? row[0] : const Uuid().v4();
          final String barcode = row[2];
          final String name = row[7];
          final double price = double.tryParse(row[12]) ?? 0.0;
          final int stock = int.tryParse(row[13]) ?? 0;

          final product = ProductModel(
            id: id,
            name: name,
            barcode: barcode,
            price: price,
            stock: stock,
            unitType: 'pieces',
          );

          productsToInsert[product.id] = product;
        }
      }

      if (productsToInsert.isNotEmpty) {
        await productBox.putAll(productsToInsert);
        print('Successfully imported ${productsToInsert.length} products from CSV.');
      }
    } catch (e) {
      print('Error parsing CSV: $e');
    }
  }
}
