import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/hive_database.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/billing/data/models/order_model.dart';

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
      if (data.containsKey('shopName')) box.put('shopName', data['shopName']);
      if (data.containsKey('address')) box.put('address', data['address']);
      if (data.containsKey('phone')) box.put('phone', data['phone']);
      if (data.containsKey('taxRate')) box.put('taxRate', (data['taxRate'] as num).toDouble());
      print('CloudSyncService: Business info synced from cloud.');
    }, onError: (e) => print('CloudSyncService: Shop listener error: $e'));

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
    final firestore = FirebaseFirestore.instance.collection('products');

    // Firestore batch write limit is 500 docs. Chunk if needed.
    final items = box.values.toList();
    for (int i = 0; i < items.length; i += 400) {
      final chunk = items.sublist(i, i + 400 > items.length ? items.length : i + 400);
      final batch = FirebaseFirestore.instance.batch();
      for (var p in chunk) {
        batch.set(firestore.doc(p.id), p.toJson(), SetOptions(merge: true));
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
    await firestore.doc('business_info').set({
      'shopName': shopBox.get('shopName', defaultValue: 'My Shop'),
      'address': shopBox.get('address', defaultValue: '123 Main St'),
      'phone': shopBox.get('phone', defaultValue: '555-0123'),
      'taxRate': shopBox.get('taxRate', defaultValue: 0.0),
    }, SetOptions(merge: true));
  }
}
