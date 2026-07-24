import 'package:hive/hive.dart';

part 'discount_model.g.dart';

@HiveType(typeId: 5)
class DiscountModel {
  @HiveField(0)
  final String code;

  @HiveField(1)
  final double percentage; // 0.0 to 1.0 (e.g., 0.20 for 20% off)

  DiscountModel({
    required this.code,
    required this.percentage,
  });

  factory DiscountModel.fromJson(Map<String, dynamic> json) {
    return DiscountModel(
      code: json['code'] as String,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'percentage': percentage,
    };
  }
}
