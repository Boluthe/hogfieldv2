import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/hive_database.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/billing/data/models/order_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/billing/data/models/discount_model.dart';

/// CloudSyncService implements an Offline-First hybrid architecture:
///
/// 1. The app always reads/writes to local Hive (instant, works offline).
/// 2. This service attaches real-time Firestore listeners that automatically
///    pull cloud changes into Hive the moment they happen on any device.
/// 3. A periodic push timer (every 10 min) + manual push ensures local
///    writes also get pushed to the cloud.
class CloudSyncService {
  static Timer? _pushTimer;
  static bool _isPushing = false;

  // Active Firestore listeners — keep references so we can cancel them on logout
  static StreamSubscription<QuerySnapshot>? _productsListener;
  static StreamSubscription<QuerySnapshot>? _ordersListener;
  static StreamSubscription<DocumentSnapshot>? _settingsListener;
  static StreamSubscription<DocumentSnapshot>? _shopListener;
  static StreamSubscription<QuerySnapshot>? _discountsListener;

  /// Call this on successful login. Starts real-time listeners AND a
  /// periodic push timer so local data also flows up to the cloud.
  static void start() {
    _startRealTimeListeners();
    _startPushTimer();
  }

  /// Call this on logout to clean up all listeners and timers.
  static void stop() {
    _productsListener?.cancel();
    _ordersListener?.cancel();
    _settingsListener?.cancel();
    _shopListener?.cancel();
    _discountsListener?.cancel();
    _pushTimer?.cancel();
    print('CloudSyncService: Stopped all listeners and timers.');
  }

  // ---------------------------------------------------------------------------
  // REAL-TIME PULL LISTENERS
  // Each listener fires instantly when the Firestore document/collection
  // changes on ANY device, automatically updating local Hive.
  // ---------------------------------------------------------------------------

  static void _startRealTimeListeners() {
    // --- Products ---
    _productsListener?.cancel();
    _productsListener = FirebaseFirestore.instance
        .collection('products')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;
      final Map<dynamic, ProductModel> remoteProducts = {};
      for (var doc in snapshot.docs) {
        try {
          final p = ProductModel.fromJson(doc.data());
          remoteProducts[p.id] = p;
        } catch (_) {}
      }
      await HiveDatabase.productBox.putAll(remoteProducts);
      print('CloudSyncService: Products updated from cloud (${remoteProducts.length} items).');
    }, onError: (e) => print('CloudSyncService: Products listener error: $e'));

    // --- Orders ---
    _ordersListener?.cancel();
    _ordersListener = FirebaseFirestore.instance
        .collection('orders')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;
      final Map<dynamic, OrderModel> remoteOrders = {};
      for (var doc in snapshot.docs) {
        try {
          final o = OrderModel.fromJson(doc.data());
          remoteOrders[o.id] = o;
        } catch (_) {}
      }
      await HiveDatabase.ordersBox.putAll(remoteOrders);
      print('CloudSyncService: Orders updated from cloud (${remoteOrders.length} items).');
    }, onError: (e) => print('CloudSyncService: Orders listener error: $e'));

    // --- PINs / Settings ---
    _settingsListener?.cancel();
    _settingsListener = FirebaseFirestore.instance
        .collection('settings')
        .doc('shop')
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data()!;
      final box = HiveDatabase.settingsBox;
      if (data.containsKey('admin_pin')) box.put('admin_pin', data['admin_pin']);
      if (data.containsKey('cashier_pin')) box.put('cashier_pin', data['cashier_pin']);
      if (data.containsKey('staff_pin')) box.put('staff_pin', data['staff_pin']);
      print('CloudSyncService: PINs synced from cloud.');
    }, onError: (e) => print('CloudSyncService: Settings listener error: $e'));

    // --- Business / Shop Info ---
    _shopListener?.cancel();
    _shopListener = FirebaseFirestore.instance
        .collection('settings')
        .doc('business_info')
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data()!;
      final box = HiveDatabase.shopBox;
      
      final currentShop = box.get('shop_details') as ShopModel? ??
          const ShopModel(
            name: 'Dinesh Shop',
            addressLine1: 'Samrajpet, Mecheri',
            addressLine2: 'Salem - 636453',
            phoneNumber: '+917010674588',
            upiId: 'dineshsowndar@oksbi',
            footerText: 'Thank you, Visit again!!!',
            taxRate: 0.0,
            taxName: 'VAT',
          );

      final updatedShop = ShopModel(
        name: data.containsKey('shopName') ? data['shopName'] : currentShop.name,
        addressLine1: data.containsKey('addressLine1') ? data['addressLine1'] : currentShop.addressLine1,
        addressLine2: data.containsKey('addressLine2') ? data['addressLine2'] : currentShop.addressLine2,
        phoneNumber: data.containsKey('phoneNumber') ? data['phoneNumber'] : currentShop.phoneNumber,
        upiId: data.containsKey('upiId') ? data['upiId'] : currentShop.upiId,
        footerText: data.containsKey('footerText') ? data['footerText'] : currentShop.footerText,
        taxRate: data.containsKey('taxRate') ? (data['taxRate'] as num).toDouble() : currentShop.taxRate,
        taxName: data.containsKey('taxName') ? data['taxName'] : currentShop.taxName,
      );

      box.put('shop_details', updatedShop);
      print('CloudSyncService: Business info synced from cloud.');
    }, onError: (e) => print('CloudSyncService: Shop listener error: $e'));

    // --- Discounts ---
    _discountsListener?.cancel();
    _discountsListener = FirebaseFirestore.instance.collection('discounts').snapshots().listen((snapshot) async {
      final Map<String, DiscountModel> remoteDiscounts = {};
      for (var doc in snapshot.docs) {
        try {
          final d = DiscountModel.fromJson(doc.data());
          remoteDiscounts[d.code] = d;
        } catch (_) {}
      }
      await HiveDatabase.discountBox.clear();
      await HiveDatabase.discountBox.putAll(remoteDiscounts);
      print('CloudSyncService: Discounts updated from cloud.');
    });

    print('CloudSyncService: Real-time listeners started.');
  }

  // ---------------------------------------------------------------------------
  // PERIODIC PUSH (LOCAL → CLOUD)
  // Pushes local Hive data to Firestore so other devices can receive it
  // via their real-time listeners. Runs on login + every 10 minutes.
  // ---------------------------------------------------------------------------

  static void _startPushTimer() {
    _pushTimer?.cancel();
    // Push immediately on login
    pushAll();
    // Then every 10 minutes
    _pushTimer = Timer.periodic(const Duration(minutes: 10), (_) => pushAll());
  }

  /// Manually push all local data to the cloud right now.
  /// Other devices will receive the changes instantly via their listeners.
  static Future<void> pushAll() async {
    if (_isPushing) return;
    _isPushing = true;

    try {
      await Future.wait([
        _pushProducts(),
        _pushOrders(),
        _pushSettings(),
        _pushDiscounts(),
      ]);
      print('CloudSyncService: Push completed successfully.');
    } catch (e) {
      print('CloudSyncService: Push failed: $e');
    } finally {
      _isPushing = false;
    }
  }

  static Future<void> _pushProducts() async {
    final box = HiveDatabase.productBox;
    if (box.isEmpty) return;
    final collection = FirebaseFirestore.instance.collection('products');

    // Firestore batch write limit is 500 docs. Chunk if needed.
    final items = box.values.toList();
    for (int i = 0; i < items.length; i += 400) {
      final chunk = items.sublist(i, i + 400 > items.length ? items.length : i + 400);
      final batch = FirebaseFirestore.instance.batch();
      for (var p in chunk) {
        batch.set(collection.doc(p.id), p.toJson(), SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  static Future<void> _pushOrders() async {
    final box = HiveDatabase.ordersBox;
    if (box.isEmpty) return;
    final firestore = FirebaseFirestore.instance.collection('orders');

    final items = box.values.toList();
    for (int i = 0; i < items.length; i += 400) {
      final chunk = items.sublist(i, i + 400 > items.length ? items.length : i + 400);
      final batch = FirebaseFirestore.instance.batch();
      for (var o in chunk) {
        batch.set(firestore.doc(o.id), o.toJson(), SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  static Future<void> _pushSettings() async {
    final box = HiveDatabase.settingsBox;
    final shopBox = HiveDatabase.shopBox;
    final firestore = FirebaseFirestore.instance.collection('settings');

    // PINs
    await firestore.doc('shop').set({
      'admin_pin': box.get('admin_pin', defaultValue: '1969'),
      'cashier_pin': box.get('cashier_pin', defaultValue: '1234'),
      'staff_pin': box.get('staff_pin', defaultValue: '0000'),
    }, SetOptions(merge: true));

    // Business Info
    final shop = shopBox.get('shop_details') as ShopModel? ??
        const ShopModel(
          name: 'Dinesh Shop',
          addressLine1: 'Samrajpet, Mecheri',
          addressLine2: 'Salem - 636453',
          phoneNumber: '+917010674588',
          upiId: 'dineshsowndar@oksbi',
          footerText: 'Thank you, Visit again!!!',
          taxRate: 0.0,
          taxName: 'VAT',
        );

    await firestore.doc('business_info').set({
      'shopName': shop.name,
      'addressLine1': shop.addressLine1,
      'addressLine2': shop.addressLine2,
      'phoneNumber': shop.phoneNumber,
      'upiId': shop.upiId,
      'footerText': shop.footerText,
      'taxRate': shop.taxRate,
      'taxName': shop.taxName,
    }, SetOptions(merge: true));
  }

  static Future<void> _pushDiscounts() async {
    final box = HiveDatabase.discountBox;
    final batch = FirebaseFirestore.instance.batch();

    final snapshot = await FirebaseFirestore.instance.collection('discounts').get();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    for (var discount in box.values) {
      final docRef = FirebaseFirestore.instance.collection('discounts').doc(discount.code);
      batch.set(docRef, discount.toJson());
    }

    await batch.commit();
  }
}
