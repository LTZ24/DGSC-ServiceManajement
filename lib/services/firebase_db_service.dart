// firebase_db_service.dart
//
// Central Firestore database helper for DGSC Mobile.
// Photos are stored LOCALLY via LocalStorageService — no Firebase Storage needed.
// Only the local file path string is saved into Firestore documents.
//
// Collection structure mirrors the MySQL schema:
//   users/                    → customers & admins (profile_photo = local path)
//   customers/                → extended customer profile (linked to users)
//   bookings/                 → service bookings   (device_photo, receipt_photo = local path)
//   services/                 → active repair services
//   spare_parts/              → spare parts inventory
//   notifications/            → in-app notifications
//   password_requests/        → customer password change requests
//   transactions/             → service payment transactions
//   settings/                 → app settings (key-value, doc id = setting_key)
//   store_settings/           → shop config (single 'config' doc)
//   counter_categories/       → counter product categories
//   counter_transactions/     → counter (pulsa, token, etc.) sales
//   counter_expenses/         → counter operational expenses
//   cf_diagnosis_history/     → saved diagnosis results per session
//   activity_logs/            → audit trail of user/admin actions

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseDbService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH  (mirrors: users table)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<UserCredential?> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  /// Register new user in Firebase Auth + creates Firestore user doc.
  /// Also creates a linked customer doc if role == 'customer'.
  static Future<UserCredential?> register({
    required String email,
    required String password,
    required String username,
    String? phone,
    String? address,
    String role = 'customer',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    final now = FieldValue.serverTimestamp();

    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'username': username,
      'phone': phone ?? '',
      'role': role,
      'google_id': null,
      'profile_picture': null,
      'created_at': now,
      'updated_at': now,
    });

    // Mirror MySQL `customers` table for customer accounts
    if (role == 'customer') {
      await _db.collection('customers').add({
        'user_id': uid,
        'name': username,
        'phone': phone ?? '',
        'email': email,
        'address': address ?? '',
        'created_at': now,
        'updated_at': now,
      });
    }

    return cred;
  }

  static Future<void> signOut() => _auth.signOut();

  static User? get currentUser => _auth.currentUser;

  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  static Future<void> updateUserProfile(
          String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });

  // ═══════════════════════════════════════════════════════════════════════════
  // CUSTOMERS  (mirrors: customers table)
  // ═══════════════════════════════════════════════════════════════════════════

  static Stream<QuerySnapshot> customersStream() =>
      _db.collection('customers').orderBy('name').snapshots();

  static Future<QuerySnapshot> getCustomerByUserId(String uid) =>
      _db.collection('customers').where('user_id', isEqualTo: uid).get();

  static Future<void> updateCustomer(
          String docId, Map<String, dynamic> data) =>
      _db.collection('customers').doc(docId).update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Future<DocumentReference> addCustomer(
          Map<String, dynamic> data) =>
      _db.collection('customers').add({
        ...data,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Future<void> deleteCustomer(String docId) =>
      _db.collection('customers').doc(docId).delete();

  // ═══════════════════════════════════════════════════════════════════════════
  // BOOKINGS  (mirrors: bookings table)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<DocumentReference> addBooking(
      Map<String, dynamic> data) async {
    return _db.collection('bookings').add({
      'customer_id': data['customer_id'] ?? '',
      'customer_name': data['customer_name'] ?? '',
      'customer_phone': data['customer_phone'] ?? '',
      'device_type': data['device_type'] ?? '',      // 'Laptop' | 'Handphone'
      'brand': data['brand'] ?? '',
      'model': data['model'] ?? '',
      'serial_number': data['serial_number'] ?? '',
      'issue_description': data['issue_description'] ?? '',
      'preferred_date': data['preferred_date'] ?? '',
      'preferred_time': data['preferred_time'],
      'status': 'pending', // pending | approved | rejected | converted | cancelled
      'notes': data['notes'] ?? '',
      // Diagnosis fields (populated from CF engine result)
      'diagnosis_category': data['diagnosis_category'],
      'diagnosis_result': data['diagnosis_result'],
      'diagnosis_cf_percentage': data['diagnosis_cf_percentage'],
      'diagnosis_symptoms': data['diagnosis_symptoms'], // JSON array of symptom IDs
      // Local photo paths
      'device_photo': data['device_photo'],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot> userBookingsStream(String uid) {
    return _db
        .collection('bookings')
        .where('customer_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> allBookingsStream() {
    return _db
        .collection('bookings')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  static Future<void> updateBookingStatus(String id, String status,
          {String? notes}) =>
      _db.collection('bookings').doc(id).update({
        'status': status,
        if (notes != null) 'notes': notes,
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Future<void> updateBooking(String id, Map<String, dynamic> data) =>
      _db.collection('bookings').doc(id).update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });

  // ═══════════════════════════════════════════════════════════════════════════
  // SERVICES  (mirrors: services table)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate service code like MySQL's 'SRV202511130001'
  static String generateServiceCode() {
    final now = DateTime.now();
    final seq = (now.millisecondsSinceEpoch % 9999).toString().padLeft(4, '0');
    return 'SRV${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$seq';
  }

  static Future<DocumentReference> addService(Map<String, dynamic> data) =>
      _db.collection('services').add({
        'service_code': generateServiceCode(),
        'origin_booking_id': data['origin_booking_id'],
        'customer_id': data['customer_id'] ?? '',
        'customer_name': data['customer_name'] ?? '',
        'customer_phone': data['customer_phone'] ?? '',
        'customer_email': data['customer_email'] ?? '',
        'device_type': data['device_type'] ?? '',
        'device_brand': data['device_brand'] ?? '',
        'model': data['model'] ?? '',
        'serial_number': data['serial_number'] ?? '',
        'problem': data['problem'] ?? '',
        'spare_parts_used': data['spare_parts_used'],
        'cost': data['cost'] ?? 0.0,
        'technician': data['technician'] ?? '',
        'status': data['status'] ?? 'pending',
        // pending | in_progress | completed | sudah_diambil
        'device_photo': data['device_photo'],
        'receipt_photo': data['receipt_photo'],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Stream<QuerySnapshot> servicesStream() {
    return _db
        .collection('services')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> userServicesStream(String customerId) {
    return _db
        .collection('services')
        .where('customer_id', isEqualTo: customerId)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  static Future<void> updateService(String id, Map<String, dynamic> data) =>
      _db.collection('services').doc(id).update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Future<void> deleteService(String id) =>
      _db.collection('services').doc(id).delete();

  // Advance status: pending → in_progress → completed → sudah_diambil
  static Future<void> advanceServiceStatus(String id, String current) {
    const order = ['pending', 'in_progress', 'completed', 'sudah_diambil'];
    final idx = order.indexOf(current);
    final next = (idx >= 0 && idx < order.length - 1) ? order[idx + 1] : current;
    return updateService(id, {'status': next});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SPARE PARTS  (mirrors: spare_parts table)
  // ═══════════════════════════════════════════════════════════════════════════

  static Stream<QuerySnapshot> sparePartsStream() =>
      _db.collection('spare_parts').orderBy('part_name').snapshots();

  static Future<DocumentReference> addSparePart(
          Map<String, dynamic> data) =>
      _db.collection('spare_parts').add({
        'part_name': data['part_name'] ?? '',
        'category': data['category'] ?? '',
        'stock_quantity': data['stock_quantity'] ?? 0,
        'unit_price': data['unit_price'] ?? 0.0,
        'supplier': data['supplier'] ?? '',
        'minimum_stock': data['minimum_stock'] ?? 5,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Future<void> updateSparePart(
          String id, Map<String, dynamic> data) =>
      _db.collection('spare_parts').doc(id).update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Future<void> updateSparePartStock(String id, int qty) =>
      _db.collection('spare_parts').doc(id).update({
        'stock_quantity': qty,
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Future<void> deleteSparePart(String id) =>
      _db.collection('spare_parts').doc(id).delete();

  // Low-stock query (mirrors v_low_stock_parts view)
  static Future<QuerySnapshot> getLowStockParts() => _db
      .collection('spare_parts')
      .where('stock_quantity', isLessThan: 5)
      .get();

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS  (mirrors: notifications table)
  // ═══════════════════════════════════════════════════════════════════════════

  static Stream<QuerySnapshot> notificationsStream(String uid) {
    return _db
        .collection('notifications')
        .where('user_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(30)
        .snapshots();
  }

  static Future<void> addNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? relatedId,
  }) =>
      _db.collection('notifications').add({
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'related_id': relatedId,
        'is_read': false,
        'created_at': FieldValue.serverTimestamp(),
      });

  static Future<void> markNotificationRead(String id) =>
      _db.collection('notifications').doc(id).update({'is_read': true});

  static Future<void> markAllNotificationsRead(String uid) async {
    final snaps = await _db
        .collection('notifications')
        .where('user_id', isEqualTo: uid)
        .where('is_read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final d in snaps.docs) {
      batch.update(d.reference, {'is_read': true});
    }
    await batch.commit();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PASSWORD REQUESTS  (mirrors: password_requests table)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<DocumentReference> addPasswordRequest(
          String userId, String email, String username, [String newPasswordHash = '']) =>
      _db.collection('password_requests').add({
        'user_id': userId,
        'email': email,
        'username': username,
        'new_password_hash': newPasswordHash,
        'status': 'pending', // pending | approved | rejected
        'requested_at': FieldValue.serverTimestamp(),
        'reviewed_at': null,
        'reviewed_by': null,
        'notes': '',
      });

  static Stream<QuerySnapshot> pendingPasswordRequestsStream() => _db
      .collection('password_requests')
      .where('status', isEqualTo: 'pending')
      .orderBy('requested_at', descending: true)
      .snapshots();

  static Future<void> reviewPasswordRequest(
          String id, String status, String adminUid,
          {String? notes}) =>
      _db.collection('password_requests').doc(id).update({
        'status': status,
        'reviewed_at': FieldValue.serverTimestamp(),
        'reviewed_by': adminUid,
        'notes': notes ?? '',
      });

  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSACTIONS  (mirrors: transactions table)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<DocumentReference> addTransaction({
    required String serviceId,
    required double amount,
    String paymentStatus = 'pending',
    String? paymentMethod,
  }) =>
      _db.collection('transactions').add({
        'service_id': serviceId,
        'amount': amount,
        'payment_status': paymentStatus, // pending | paid | cancelled
        'payment_method': paymentMethod,
        'transaction_date': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Stream<QuerySnapshot> transactionsStream() =>
      _db.collection('transactions').orderBy('transaction_date', descending: true).snapshots();

  static Future<void> updateTransactionStatus(String id, String status) =>
      _db.collection('transactions').doc(id).update({
        'payment_status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });

  // Mirror of v_revenue_summary: revenue grouped by date
  static Future<Map<String, double>> getRevenueSummary() async {
    final snap = await _db
        .collection('transactions')
        .where('payment_status', isEqualTo: 'paid')
        .get();
    final Map<String, double> result = {};
    for (final d in snap.docs) {
      final ts = d['transaction_date'];
      if (ts == null) continue;
      final date = (ts as Timestamp).toDate();
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      result[key] = (result[key] ?? 0.0) + (d['amount'] as num).toDouble();
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS  (mirrors: settings table — key-value store)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get a single setting value by key
  static Future<String?> getSetting(String key) async {
    final doc = await _db.collection('settings').doc(key).get();
    return doc.exists ? (doc.data()?['value']) as String? : null;
  }

  /// Get all settings as a Map<key, value>
  static Future<Map<String, String>> getAllSettings() async {
    final snap = await _db.collection('settings').get();
    return {
      for (final d in snap.docs)
        d.id: (d.data()['value'] ?? '').toString(),
    };
  }

  static Future<void> setSetting(String key, String value,
      {String type = 'text', String? description}) =>
      _db.collection('settings').doc(key).set({
        'value': value,
        'type': type,
        'description': description ?? '',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  // ═══════════════════════════════════════════════════════════════════════════
  // STORE SETTINGS  (mirrors: store_settings table)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> getStoreSettings() async {
    final doc = await _db.collection('store_settings').doc('config').get();
    return doc.exists ? doc.data() : null;
  }

  static Future<void> saveStoreSettings(Map<String, dynamic> data) =>
      _db
          .collection('store_settings')
          .doc('config')
          .set(data, SetOptions(merge: true));

  // ═══════════════════════════════════════════════════════════════════════════
  // COUNTER CATEGORIES  (mirrors: counter_categories table)
  // ═══════════════════════════════════════════════════════════════════════════

  static Stream<QuerySnapshot> counterCategoriesStream() => _db
      .collection('counter_categories')
      .where('is_active', isEqualTo: true)
      .orderBy('sort_order')
      .snapshots();

  static Future<void> addCounterCategory(Map<String, dynamic> data) =>
      _db.collection('counter_categories').add({
        'name': data['name'] ?? '',
        'icon': data['icon'] ?? 'fas fa-tag',
        'color': data['color'] ?? '#667eea',
        'sort_order': data['sort_order'] ?? 0,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
      });

  static Future<void> updateCounterCategory(
          String id, Map<String, dynamic> data) =>
      _db.collection('counter_categories').doc(id).update(data);

  // ═══════════════════════════════════════════════════════════════════════════
  // COUNTER TRANSACTIONS  (mirrors: counter_transactions table)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<DocumentReference> addCounterTransaction(
          Map<String, dynamic> data) =>
      _db.collection('counter_transactions').add({
        'transaction_date': data['transaction_date'] ??
            FieldValue.serverTimestamp(),
        'category_id': data['category_id'],
        'product_name': data['product_name'] ?? '',
        'customer_info': data['customer_info'] ?? '',
        'modal_price': (data['modal_price'] ?? 0.0).toDouble(),
        'selling_price': (data['selling_price'] ?? 0.0).toDouble(),
        // Profit is computed in Dart (not stored DB formula like MySQL)
        'profit': ((data['selling_price'] ?? 0.0) -
                (data['modal_price'] ?? 0.0))
            .toDouble(),
        'payment_method': data['payment_method'] ?? 'cash',
        'receipt_image': data['receipt_image'],
        'ocr_raw_text': data['ocr_raw_text'],
        'notes': data['notes'] ?? '',
        'created_by': data['created_by'],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Stream<QuerySnapshot> counterTransactionsStream(
          {DateTime? date}) {
    Query q = _db.collection('counter_transactions');
    if (date != null) {
      final start = Timestamp.fromDate(
          DateTime(date.year, date.month, date.day));
      final end = Timestamp.fromDate(
          DateTime(date.year, date.month, date.day, 23, 59, 59));
      q = q
          .where('transaction_date', isGreaterThanOrEqualTo: start)
          .where('transaction_date', isLessThanOrEqualTo: end);
    }
    return q.orderBy('transaction_date', descending: true).snapshots();
  }

  static Future<void> updateCounterTransaction(
          String id, Map<String, dynamic> data) {
    // Recalculate profit whenever prices change
    if (data.containsKey('selling_price') || data.containsKey('modal_price')) {
      // Fetch current doc first if only one price is updated — simpler: always require both
      final modal = (data['modal_price'] ?? 0.0).toDouble();
      final sell = (data['selling_price'] ?? 0.0).toDouble();
      data['profit'] = sell - modal;
    }
    return _db.collection('counter_transactions').doc(id).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteCounterTransaction(String id) =>
      _db.collection('counter_transactions').doc(id).delete();

  /// Daily summary for counter — total revenue, profit, count
  static Future<Map<String, dynamic>> getCounterDailySummary(
      DateTime date) async {
    final snap = await counterTransactionsStream(date: date).first;
    double revenue = 0, profit = 0;
    for (final d in snap.docs) {
      revenue += (d['selling_price'] as num? ?? 0).toDouble();
      profit += (d['profit'] as num? ?? 0).toDouble();
    }
    return {
      'count': snap.docs.length,
      'revenue': revenue,
      'profit': profit,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COUNTER EXPENSES  (mirrors: counter_expenses table)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<DocumentReference> addCounterExpense(
          Map<String, dynamic> data) =>
      _db.collection('counter_expenses').add({
        'expense_date': data['expense_date'] ?? FieldValue.serverTimestamp(),
        'description': data['description'] ?? '',
        'amount': (data['amount'] ?? 0.0).toDouble(),
        'category': data['category'] ?? 'Operasional',
        'receipt_image': data['receipt_image'],
        'created_by': data['created_by'],
        'created_at': FieldValue.serverTimestamp(),
      });

  static Stream<QuerySnapshot> counterExpensesStream({DateTime? date}) {
    Query q = _db.collection('counter_expenses');
    if (date != null) {
      final start = Timestamp.fromDate(
          DateTime(date.year, date.month, date.day));
      final end = Timestamp.fromDate(
          DateTime(date.year, date.month, date.day, 23, 59, 59));
      q = q
          .where('expense_date', isGreaterThanOrEqualTo: start)
          .where('expense_date', isLessThanOrEqualTo: end);
    }
    return q.orderBy('expense_date', descending: true).snapshots();
  }

  static Future<void> deleteCounterExpense(String id) =>
      _db.collection('counter_expenses').doc(id).delete();

  // ═══════════════════════════════════════════════════════════════════════════
  // CF DIAGNOSIS HISTORY  (mirrors: cf_diagnosis_history table)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save a completed diagnosis session to history.
  /// [results] is the List<CfResult> serialised as List<Map> from CfEngine.
  static Future<DocumentReference> saveDiagnosisHistory({
    required int categoryId,
    required String categoryName,
    String? deviceInfo,
    required List<int> selectedSymptomIds,
    required List<Map<String, dynamic>> results,
    required String topDiagnosis,
    required double cfPercentage,
    String? userId,
  }) =>
      _db.collection('cf_diagnosis_history').add({
        'category_id': categoryId,
        'category_name': categoryName,
        'device_info': deviceInfo ?? '',
        'symptoms': selectedSymptomIds,     // List<int>
        'results': results,                  // List<Map> with CF data
        'top_diagnosis': topDiagnosis,
        'cf_percentage': cfPercentage,
        'user_id': userId,                   // null = anonymous
        'created_at': FieldValue.serverTimestamp(),
      });

  static Stream<QuerySnapshot> diagnosisHistoryStream({String? userId}) {
    Query q = _db.collection('cf_diagnosis_history');
    if (userId != null) {
      q = q.where('user_id', isEqualTo: userId);
    }
    return q.orderBy('created_at', descending: true).limit(50).snapshots();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIVITY LOGS  (mirrors: activity_logs table — audit trail)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> logActivity({
    required String userId,
    required String action,      // e.g. 'booking_created', 'service_updated'
    String? targetCollection,
    String? targetId,
    Map<String, dynamic>? meta,
  }) =>
      _db.collection('activity_logs').add({
        'user_id': userId,
        'action': action,
        'target_collection': targetCollection,
        'target_id': targetId,
        'meta': meta ?? {},
        'created_at': FieldValue.serverTimestamp(),
      });

  static Stream<QuerySnapshot> activityLogsStream({String? userId}) {
    Query q = _db.collection('activity_logs');
    if (userId != null) q = q.where('user_id', isEqualTo: userId);
    return q.orderBy('created_at', descending: true).limit(100).snapshots();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DASHBOARD STATS  (computed — no direct MySQL equivalent)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Customer dashboard stats
  static Future<Map<String, int>> getCustomerDashboardStats(
      String uid) async {
    final bookings = await _db
        .collection('bookings')
        .where('customer_id', isEqualTo: uid)
        .get();

    final total = bookings.docs.length;
    final pending = bookings.docs
        .where((d) =>
            d['status'] == 'pending' || d['status'] == 'in_progress')
        .length;
    final completed =
        bookings.docs.where((d) => d['status'] == 'completed').length;

    return {
      'totalBookings': total,
      'pendingCount': pending,
      'completedCount': completed,
    };
  }

  /// Admin dashboard stats across all collections
  static Future<Map<String, dynamic>> getAdminDashboardStats() async {
    final results = await Future.wait([
      _db.collection('bookings').where('status', isEqualTo: 'pending').get(),
      _db.collection('services').where('status', isEqualTo: 'in_progress').get(),
      _db.collection('services').where('status', isEqualTo: 'completed').get(),
      _db.collection('transactions').where('payment_status', isEqualTo: 'paid').get(),
    ]);

    final pendingBookings = results[0].docs.length;
    final activeServices = results[1].docs.length;
    final completedServices = results[2].docs.length;

    double totalRevenue = 0;
    for (final d in results[3].docs) {
      totalRevenue += (d['amount'] as num? ?? 0).toDouble();
    }

    return {
      'pendingBookings': pendingBookings,
      'activeServices': activeServices,
      'completedServices': completedServices,
      'totalRevenue': totalRevenue,
    };
  }

  /// Full admin dashboard data for the dashboard screen
  static Future<Map<String, dynamic>> getAdminDashboardData() async {
    // Run queries individually so one failure doesn't break everything
    QuerySnapshot<Map<String, dynamic>> allSvcSnap;
    QuerySnapshot<Map<String, dynamic>> customersSnap;
    QuerySnapshot<Map<String, dynamic>> paidSnap;
    QuerySnapshot<Map<String, dynamic>> pendingBookSnap;
    QuerySnapshot<Map<String, dynamic>> recentSvcSnap;
    QuerySnapshot<Map<String, dynamic>> lowStockSnap;

    try { allSvcSnap = await _db.collection('services').get(); } catch (_) {
      allSvcSnap = await _db.collection('services').limit(0).get(); }
    try { customersSnap = await _db.collection('customers').get(); } catch (_) {
      customersSnap = await _db.collection('customers').limit(0).get(); }
    try { paidSnap = await _db.collection('transactions').where('payment_status', isEqualTo: 'paid').get(); } catch (_) {
      paidSnap = await _db.collection('transactions').limit(0).get(); }
    try { pendingBookSnap = await _db.collection('bookings').where('status', isEqualTo: 'pending').get(); } catch (_) {
      pendingBookSnap = await _db.collection('bookings').limit(0).get(); }
    // Avoid orderBy which requires a composite index; just grab recent 5 by limit
    try { recentSvcSnap = await _db.collection('services').limit(5).get(); } catch (_) {
      recentSvcSnap = await _db.collection('services').limit(0).get(); }
    try { lowStockSnap = await _db.collection('spare_parts').where('stock_quantity', isEqualTo: 0).get(); } catch (_) {
      lowStockSnap = await _db.collection('spare_parts').limit(0).get(); }

    final allServices = allSvcSnap.docs;
    final totalServices = allServices.length;
    final completedServices = allServices.where((d) => d.data()['status'] == 'completed').length;
    final inProgressServices = allServices.where((d) => d.data()['status'] == 'in_progress').length;
    final pendingServices = allServices.where((d) => d.data()['status'] == 'pending').length;
    final totalCustomers = customersSnap.docs.length;

    double paidRevenue = 0;
    for (final d in paidSnap.docs) {
      paidRevenue += (d.data()['amount'] as num? ?? 0).toDouble();
    }

    final pendingBookings = pendingBookSnap.docs.length;

    final recentServices = recentSvcSnap.docs.map((d) {
      final data = d.data();
      return {
        'service_code': data['service_code'] ?? d.id,
        'customer_name': data['customer_name'] ?? '',
        'problem': data['problem_description'] ?? data['problem'] ?? '',
        'status': data['status'] ?? '',
      };
    }).toList();

    final lowStockParts = lowStockSnap.docs.map((d) {
      final data = d.data();
      return {
        'part_name': data['part_name'] ?? data['name'] ?? '',
        'stock_quantity': (data['stock_quantity'] as num? ?? 0).toInt(),
      };
    }).toList();

    return {
      'totalServices': totalServices,
      'completedServices': completedServices,
      'inProgressServices': inProgressServices,
      'pendingServices': pendingServices,
      'totalCustomers': totalCustomers,
      'paidRevenue': paidRevenue,
      'pendingBookings': pendingBookings,
      'recentServices': recentServices,
      'lowStockParts': lowStockParts,
    };
  }

  /// Send password reset email (used by admin to approve password change request)
  static Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Stream of pending password requests with user info
  static Stream<QuerySnapshot> pendingPasswordRequestsStreamFull() => _db
      .collection('password_requests')
      .where('status', isEqualTo: 'pending')
      .orderBy('requested_at', descending: true)
      .snapshots();
}
