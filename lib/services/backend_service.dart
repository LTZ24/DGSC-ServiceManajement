 import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'backend_types.dart';
import 'ppob_catalog_service.dart';

class BackendService {
  static supabase.SupabaseClient get _db => supabase.Supabase.instance.client;
  static const String _resetRoleStorageKey = 'password_reset_role';
  static const String _googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String _googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: _googleWebClientId.isEmpty ? null : _googleWebClientId,
    clientId: defaultTargetPlatform == TargetPlatform.iOS &&
            _googleIosClientId.isNotEmpty
        ? _googleIosClientId
        : null,
  );

  static const Set<String> _timestampFields = {
    'created_at',
    'updated_at',
    'requested_at',
    'reviewed_at',
    'transaction_date',
    'expense_date',
    'completed_at',
    'taken_at',
    'published_at',
    'draft_updated_at',
  };

  static const String _diagnosisBucket = 'diagnosis-data';

  static Map<String, dynamic> _serviceHistoryEntry({
    required String status,
    required String title,
    String? description,
    String? actor,
    Map<String, dynamic>? meta,
  }) {
    return {
      'status': status,
      'title': title,
      'description': description ?? '',
      'actor': actor ?? '',
      'meta': meta ?? <String, dynamic>{},
      'created_at': Timestamp.now(),
    };
  }

  static dynamic _normalizeValue(dynamic value, {String? key}) {
    if (value is FieldValue && value.isServerTimestamp) {
      return DateTime.now().toUtc().toIso8601String();
    }
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is List) {
      return value.map((item) => _normalizeValue(item)).toList();
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString():
              _normalizeValue(entry.value, key: entry.key.toString()),
      };
    }
    return value;
  }

  static Map<String, dynamic> _normalizeData(Map<String, dynamic> data) {
    return {
      for (final entry in data.entries)
        entry.key: _normalizeValue(entry.value, key: entry.key),
    };
  }

  static dynamic _deserializeValue(String? key, dynamic value) {
    if (value is List) {
      return value
          .map((item) => item is Map
              ? _deserializeRow(Map<String, dynamic>.from(item))
              : _deserializeValue(null, item))
          .toList();
    }
    if (value is Map) {
      return _deserializeRow(Map<String, dynamic>.from(value));
    }
    if (value is String && key != null && _timestampFields.contains(key)) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return Timestamp.fromDate(parsed.toLocal());
      }
    }
    return value;
  }

  static Map<String, dynamic> _deserializeRow(Map<String, dynamic> row) {
    return {
      for (final entry in row.entries)
        entry.key: _deserializeValue(entry.key, entry.value),
    };
  }

  static QuerySnapshot<Map<String, dynamic>> _toQuerySnapshot(
    List<Map<String, dynamic>> rows,
  ) {
    return QuerySnapshot<Map<String, dynamic>>(
      docs: rows
          .map(
            (row) => QueryDocumentSnapshot<Map<String, dynamic>>(
              id: row['id'].toString(),
              data: _deserializeRow(row),
            ),
          )
          .toList(),
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> _streamToSnapshot(
    Stream<List<Map<String, dynamic>>> stream,
  ) {
    return stream.map((rows) => _toQuerySnapshot(rows));
  }

  static Stream<List<Map<String, dynamic>>> _filterRowsByField(
    Stream<List<Map<String, dynamic>>> stream,
    String field,
    dynamic value,
  ) {
    return stream.map(
      (rows) => rows.where((row) => row[field] == value).toList(),
    );
  }

  static Stream<List<Map<String, dynamic>>> _filterRowsByDay(
    Stream<List<Map<String, dynamic>>> stream,
    String field,
    DateTime date,
  ) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return stream.map(
      (rows) => rows.where((row) {
        final raw = row[field]?.toString();
        final parsed = raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
        if (parsed == null) return false;
        return !parsed.isBefore(start) && parsed.isBefore(end);
      }).toList(),
    );
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> _listToSnapshot(
    Future<List<Map<String, dynamic>>> future,
  ) async {
    final rows = await future;
    return _toQuerySnapshot(rows);
  }

  static User? get currentUser {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    final metadata = user.userMetadata ?? {};
    return User(
      uid: user.id,
      email: user.email,
      displayName: metadata['display_name']?.toString() ??
          metadata['username']?.toString(),
    );
  }

  static List<String> _phoneCandidates(String rawValue) {
    final trimmed = rawValue.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    final candidates = <String>{
      if (trimmed.isNotEmpty) trimmed,
      if (digits.isNotEmpty) digits,
      if (digits.startsWith('0') && digits.length > 1)
        '62${digits.substring(1)}',
      if (digits.startsWith('62')) '0${digits.substring(2)}',
      if (trimmed.startsWith('+') && trimmed.length > 1) trimmed.substring(1),
      if (!trimmed.startsWith('+') && digits.startsWith('62')) '+$digits',
    };
    return candidates.where((value) => value.isNotEmpty).toList();
  }

  static Future<String?> _resolveEmailForSignIn(String identifier) async {
    final normalized = identifier.trim();
    if (normalized.isEmpty) return null;

    if (normalized.contains('@')) {
      return normalized.toLowerCase();
    }

    final usernameRows = await _db
        .from('users')
        .select('email')
        .ilike('username', normalized)
        .limit(1);
    if (usernameRows.isNotEmpty) {
      return usernameRows.first['email']?.toString();
    }

    final customerNameRows = await _db
        .from('customers')
        .select('email')
        .ilike('name', normalized)
        .limit(1);
    if (customerNameRows.isNotEmpty) {
      return customerNameRows.first['email']?.toString();
    }

    for (final phone in _phoneCandidates(normalized)) {
      final byPhoneRows =
          await _db.from('users').select('email').eq('phone', phone).limit(1);
      if (byPhoneRows.isNotEmpty) {
        return byPhoneRows.first['email']?.toString();
      }

      final customerPhoneRows = await _db
          .from('customers')
          .select('email')
          .eq('phone', phone)
          .limit(1);
      if (customerPhoneRows.isNotEmpty) {
        return customerPhoneRows.first['email']?.toString();
      }
    }

    return null;
  }

  static Future<void> savePasswordResetRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_resetRoleStorageKey, role);
  }

  static Future<String?> getSavedPasswordResetRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_resetRoleStorageKey);
  }

  static Future<void> clearSavedPasswordResetRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_resetRoleStorageKey);
  }

  static Future<void> _syncGoogleProfile(GoogleSignInAccount googleUser) async {
    final activeUser = currentUser;
    if (activeUser == null) return;

    final profile = await getUserProfile(activeUser.uid);
    final updates = <String, dynamic>{};
    final photoUrl = googleUser.photoUrl?.trim() ?? '';
    final displayName = googleUser.displayName?.trim() ?? '';
    final email = activeUser.email?.trim().toLowerCase() ?? '';
    final currentUsername = profile?['username']?.toString().trim() ?? '';
    final emailPrefix =
        email.contains('@') ? email.split('@').first.trim() : email;

    if (photoUrl.isNotEmpty && profile?['profile_picture'] != photoUrl) {
      updates['profile_picture'] = photoUrl;
    }

    final shouldReplaceUsername = currentUsername.isEmpty ||
        currentUsername.toLowerCase() == email ||
        currentUsername.toLowerCase() == emailPrefix;
    if (shouldReplaceUsername && displayName.isNotEmpty) {
      updates['username'] = displayName;
    }

    if ((profile?['email']?.toString().trim().isEmpty ?? true) &&
        email.isNotEmpty) {
      updates['email'] = email;
    }

    if (updates.isNotEmpty) {
      await updateUserProfile(activeUser.uid, updates);
    }
  }

  static Future<User?> signIn(String identifier, String password) async {
    try {
      final resolvedEmail = await _resolveEmailForSignIn(identifier);
      if (resolvedEmail == null || resolvedEmail.isEmpty) {
        throw BackendException(
          'invalid_credentials',
          'Akun dengan email, username, atau nomor HP tersebut tidak ditemukan.',
        );
      }

      final response = await _db.auth.signInWithPassword(
        email: resolvedEmail.trim().toLowerCase(),
        password: password,
      );
      final user = response.user;
      if (user == null) return null;
      return User(
        uid: user.id,
        email: user.email,
        displayName: user.userMetadata?['display_name']?.toString() ??
            user.userMetadata?['username']?.toString(),
      );
    } on supabase.AuthException catch (e) {
      throw BackendException(e.statusCode ?? 'auth_error', e.message);
    } catch (_) {
      throw BackendException(
          'auth_error', 'Login gagal. Periksa koneksi internet.');
    }
  }

  static Future<void> signInWithGoogle() async {
    try {
      if (_googleWebClientId.isEmpty) {
        throw BackendException(
          'google_config',
          'GOOGLE_WEB_CLIENT_ID belum diisi pada dart-define.',
        );
      }

      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw BackendException(
          'google_cancelled',
          'Login Google dibatalkan.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw BackendException(
          'google_no_token',
          'ID token Google tidak tersedia.',
        );
      }

      await _db.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      await _syncGoogleProfile(googleUser);
    } on BackendException {
      rethrow;
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('canceled') || code.contains('cancelled')) {
        throw BackendException(
          'google_cancelled',
          'Login Google dibatalkan.',
        );
      }

      if (code.contains('network')) {
        throw BackendException(
          'network_error',
          'Koneksi internet bermasalah saat login Google.',
        );
      }

      throw BackendException(
        'google_config',
        e.message ??
            'Google Sign-In belum terkonfigurasi dengan benar pada aplikasi.',
      );
    } on supabase.AuthException catch (e) {
      throw BackendException(e.statusCode ?? 'auth_error', e.message);
    } catch (_) {
      throw BackendException(
        'auth_error',
        'Login Google gagal. Periksa koneksi internet dan konfigurasi OAuth.',
      );
    }
  }

  static Future<User?> register({
    required String email,
    required String password,
    required String username,
    String? phone,
    String? address,
    String role = 'customer',
  }) async {
    try {
      final activeUser = currentUser;
      Map<String, dynamic>? currentProfile;
      if (activeUser != null) {
        currentProfile = await getUserProfile(activeUser.uid);
      }

      if (role == 'customer' && currentProfile?['role'] == 'admin') {
        await _db.rpc('admin_create_customer_user', params: {
          'p_email': email,
          'p_password': password,
          'p_username': username,
          'p_phone': phone ?? '',
          'p_address': address ?? '',
        });
        return activeUser;
      }

      final response = await _db.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'username': username.trim(),
          'display_name': username.trim(),
          'phone': (phone ?? '').trim(),
          'role': role,
        },
      );

      final user = response.user;
      if (user == null) return null;

      return User(
        uid: user.id,
        email: user.email,
        displayName: username,
      );
    } on supabase.AuthException catch (e) {
      throw BackendException(e.statusCode ?? 'auth_error', e.message);
    } on supabase.PostgrestException catch (e) {
      throw BackendException(e.code ?? 'db_error', e.message);
    } catch (_) {
      throw BackendException(
          'register_error', 'Registrasi gagal. Periksa koneksi internet.');
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _db.auth.signOut();
  }

  static Future<void> verifyCurrentPassword(String password) async {
    final user = _db.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw BackendException('auth_error', 'Sesi login tidak valid.');
    }

    try {
      await _db.auth.signInWithPassword(email: email, password: password);
    } on supabase.AuthException catch (_) {
      throw BackendException(
          'invalid_credentials', 'Password admin yang dimasukkan tidak valid.');
    } catch (_) {
      throw BackendException(
          'auth_error', 'Gagal memverifikasi password admin.');
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final data = await _db.from('users').select().eq('id', uid).maybeSingle();
    if (data == null) return null;
    return _deserializeRow(Map<String, dynamic>.from(data));
  }

  static Future<void> updateUserProfile(
      String uid, Map<String, dynamic> data) async {
    final payload =
        _normalizeData({...data, 'updated_at': FieldValue.serverTimestamp()});
    await _db.from('users').update(payload).eq('id', uid);
    await _db
        .from('customers')
        .update(_normalizeData({
          if (data['username'] != null) 'name': data['username'],
          if (data['phone'] != null) 'phone': data['phone'],
          if (data['address'] != null) 'address': data['address'],
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .eq('user_id', uid);
  }

  static Future<void> updateProfilePicture(String uid, String pathOrUrl) async {
    final previous = await getUserProfile(uid);
    final previousPicture = previous?['profile_picture']?.toString();

    await updateUserProfile(uid, {'profile_picture': pathOrUrl});

    final nextValue = pathOrUrl.trim();
    if (previousPicture != null &&
        previousPicture.isNotEmpty &&
        previousPicture != nextValue &&
        !previousPicture.startsWith('http') &&
        !previousPicture.startsWith('https')) {
      final file = File(previousPicture);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<void> createAdminAccount({
    required String email,
    required String password,
    required String username,
    String? phone,
  }) async {
    try {
      await _db.rpc('admin_create_admin_user', params: {
        'p_email': email,
        'p_password': password,
        'p_username': username,
        'p_phone': phone ?? '',
      });
    } on supabase.PostgrestException catch (e) {
      throw BackendException(e.code ?? 'db_error', e.message);
    } catch (_) {
      throw BackendException(
        'admin_create_error',
        'Gagal membuat akun admin baru.',
      );
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> customersStream() {
    return _streamToSnapshot(
      _db.from('customers').stream(primaryKey: ['id']).order('name'),
    );
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getCustomerByUserId(
      String uid) {
    return _listToSnapshot(
      _db.from('customers').select().eq('user_id', uid).then(
            (value) => (value as List).cast<Map<String, dynamic>>(),
          ),
    );
  }

  static Future<void> updateCustomer(
      String docId, Map<String, dynamic> data) async {
    await _db
        .from('customers')
        .update(_normalizeData(
            {...data, 'updated_at': FieldValue.serverTimestamp()}))
        .eq('id', int.parse(docId));
  }

  static Future<DocumentReference> addCustomer(
      Map<String, dynamic> data) async {
    final inserted = await _db
        .from('customers')
        .insert(_normalizeData({
          ...data,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp()
        }))
        .select()
        .single();
    return DocumentReference(inserted['id'].toString());
  }

  static Future<void> deleteCustomer(String docId) async {
    final existing = await _db
        .from('customers')
        .select()
        .eq('id', int.parse(docId))
        .maybeSingle();
    if (existing != null && existing['user_id'] != null) {
      await _db.from('users').delete().eq('id', existing['user_id']);
    }
    await _db.from('customers').delete().eq('id', int.parse(docId));
  }

  static Future<DocumentReference> addBooking(Map<String, dynamic> data) async {
    final inserted = await _db
        .from('bookings')
        .insert(_normalizeData({
          'customer_id': data['customer_id'] ?? '',
          'customer_name': data['customer_name'] ?? '',
          'customer_phone': data['customer_phone'] ?? '',
          'device_type': data['device_type'] ?? '',
          'brand': data['brand'] ?? '',
          'model': data['model'] ?? '',
          'serial_number': data['serial_number'] ?? '',
          'issue_description': data['issue_description'] ?? '',
          'preferred_date': data['preferred_date'] ?? '',
          'preferred_time': data['preferred_time'],
          'status': data['status'] ?? 'pending',
          'notes': data['notes'] ?? '',
          'diagnosis_category': data['diagnosis_category'],
          'diagnosis_result': data['diagnosis_result'],
          'diagnosis_cf_percentage': data['diagnosis_cf_percentage'],
          'diagnosis_symptoms': data['diagnosis_symptoms'],
          'device_photo': data['device_photo'],
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .select()
        .single();
    return DocumentReference(inserted['id'].toString());
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> userBookingsStream(
      String uid) {
    return _streamToSnapshot(
      _db
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('customer_id', uid)
          .order('created_at', ascending: false),
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> allBookingsStream() {
    return _streamToSnapshot(
      _db
          .from('bookings')
          .stream(primaryKey: ['id']).order('created_at', ascending: false),
    );
  }

  static Future<void> updateBookingStatus(String id, String status,
      {String? notes}) async {
    await _db
        .from('bookings')
        .update(_normalizeData({
          'status': status,
          if (notes != null) 'notes': notes,
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .eq('id', int.parse(id));
  }

  static Future<void> updateBooking(
      String id, Map<String, dynamic> data) async {
    await _db
        .from('bookings')
        .update(_normalizeData(
            {...data, 'updated_at': FieldValue.serverTimestamp()}))
        .eq('id', int.parse(id));
  }

  static Future<void> deleteBooking(String id) async {
    await _db.from('bookings').delete().eq('id', int.parse(id));
  }

  static String generateServiceCode() {
    final now = DateTime.now();
    final seq = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'SRV${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$seq';
  }

  static Future<DocumentReference> addService(Map<String, dynamic> data) async {
    final status = (data['status'] ?? 'pending').toString();
    final createdFromBooking =
        (data['origin_booking_id'] ?? '').toString().isNotEmpty;
    final inserted = await _db
        .from('services')
        .insert(_normalizeData({
          'service_code': data['service_code'] ?? generateServiceCode(),
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
          'initial_detail': data['initial_detail'] ?? '',
          'service_detail': data['service_detail'] ?? '',
          'status_note': data['status_note'] ?? '',
          'estimated_cost': (data['estimated_cost'] ?? 0.0).toDouble(),
          'cost': (data['cost'] ?? 0.0).toDouble(),
          'technician': data['technician'] ?? '',
          'status': status,
          'payment_method': data['payment_method'],
          'payment_choice': data['payment_choice'],
          'payment_status': data['payment_status'] ?? 'pending',
          'finance_recorded': data['finance_recorded'] ?? false,
          'completed_at': data['completed_at'],
          'taken_at': data['taken_at'],
          'status_history': data['status_history'] ??
              [
                _serviceHistoryEntry(
                  status: status,
                  title: createdFromBooking
                      ? 'Servis dibuat dari booking'
                      : 'Servis dibuat',
                  description: createdFromBooking
                      ? 'Booking diterima admin dan diubah menjadi servis aktif.'
                      : 'Servis dibuat langsung oleh admin.',
                  actor: 'admin',
                ),
              ],
          'device_photo': data['device_photo'],
          'receipt_photo': data['receipt_photo'],
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .select()
        .single();
    return DocumentReference(inserted['id'].toString());
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> servicesStream() {
    return _streamToSnapshot(
      _db
          .from('services')
          .stream(primaryKey: ['id']).order('created_at', ascending: false),
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> userServicesStream(
      String customerId) {
    return _streamToSnapshot(
      _db
          .from('services')
          .stream(primaryKey: ['id'])
          .eq('customer_id', customerId)
          .order('created_at', ascending: false),
    );
  }

  static Future<void> updateService(
      String id, Map<String, dynamic> data) async {
    await _db
        .from('services')
        .update(_normalizeData(
            {...data, 'updated_at': FieldValue.serverTimestamp()}))
        .eq('id', int.parse(id));
  }

  static Future<void> appendServiceHistory({
    required String serviceId,
    required String status,
    required String title,
    String? description,
    String? actor,
    Map<String, dynamic>? meta,
  }) async {
    final snap = await _db
        .from('services')
        .select('status_history')
        .eq('id', int.parse(serviceId))
        .single();
    final history = ((snap['status_history'] as List?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    history.add(_normalizeData(_serviceHistoryEntry(
      status: status,
      title: title,
      description: description,
      actor: actor,
      meta: meta,
    )));
    await _db
        .from('services')
        .update(_normalizeData({
          'status_history': history,
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .eq('id', int.parse(serviceId));
  }

  static Future<void> notifyServiceCustomer({
    required String customerId,
    required String serviceId,
    required String title,
    required String message,
  }) async {
    if (customerId.isEmpty) return;
    await addNotification(
      userId: customerId,
      type: 'service',
      title: title,
      message: message,
      relatedId: serviceId,
    );
  }

  static Future<void> notifyAdmins({
    required String title,
    required String message,
    String? relatedId,
    String type = 'admin',
  }) async {
    try {
      await _db.rpc('notify_admins', params: {
        'p_title': title,
        'p_message': message,
        'p_related_id': relatedId,
        'p_type': type,
      });
      try {
        await _db.functions.invoke('send-push', body: {
          'topic': 'role_admin',
          'type': type,
          'title': title,
          'message': message,
          'relatedId': relatedId,
        });
      } catch (_) {
        // Ignore if push function is not deployed yet.
      }
      return;
    } catch (_) {
      // Fall back to direct inserts for environments without the RPC.
    }

    try {
      final admins = await _db.from('users').select('id').eq('role', 'admin');
      for (final admin in (admins as List)) {
        await addNotification(
          userId: admin['id'].toString(),
          type: type,
          title: title,
          message: message,
          relatedId: relatedId,
        );
      }
    } catch (_) {
      try {
        await _db.functions.invoke('send-push', body: {
          'topic': 'role_admin',
          'type': type,
          'title': title,
          'message': message,
          'relatedId': relatedId,
        });
      } catch (_) {
        // Keep the caller successful even if admin notifications are unavailable.
      }
    }
  }

  static Future<void> markServicePickedUp({
    required String serviceId,
    required Map<String, dynamic> serviceData,
    required String paymentMethod,
    double? amount,
  }) async {
    final totalAmount = amount ??
        (serviceData['cost'] as num?)?.toDouble() ??
        (serviceData['estimated_cost'] as num?)?.toDouble() ??
        0.0;

    final existingTx = await _db
        .from('transactions')
        .select()
        .eq('service_id', int.parse(serviceId))
        .maybeSingle();
    await updateService(serviceId, {
      'status': 'sudah_diambil',
      'payment_method': paymentMethod,
      'payment_choice': paymentMethod,
      'payment_status': 'paid',
      'finance_recorded': true,
      'taken_at': FieldValue.serverTimestamp(),
    });

    if (existingTx == null) {
      await addTransaction(
        serviceId: serviceId,
        amount: totalAmount,
        paymentStatus: 'paid',
        paymentMethod: paymentMethod,
      );
    } else {
      await _db
          .from('transactions')
          .update(_normalizeData({
            'amount': totalAmount,
            'payment_status': 'paid',
            'payment_method': paymentMethod,
            'transaction_date': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          }))
          .eq('id', existingTx['id']);
    }

    await appendServiceHistory(
      serviceId: serviceId,
      status: 'sudah_diambil',
      title: 'Perangkat sudah diambil',
      description:
          'Pembayaran dinyatakan lunas dan transaksi masuk ke keuangan.',
      actor: 'admin',
      meta: {'payment_method': paymentMethod, 'amount': totalAmount},
    );
  }

  static Future<void> deleteService(String id) async {
    await _db.from('services').delete().eq('id', int.parse(id));
  }

  static Future<void> advanceServiceStatus(String id, String current) {
    const order = ['pending', 'in_progress', 'completed', 'sudah_diambil'];
    final idx = order.indexOf(current);
    final next =
        (idx >= 0 && idx < order.length - 1) ? order[idx + 1] : current;
    return updateService(id, {'status': next});
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> sparePartsStream() {
    return _streamToSnapshot(
      _db.from('spare_parts').stream(primaryKey: ['id']).order('part_name'),
    );
  }

  static Future<DocumentReference> addSparePart(
      Map<String, dynamic> data) async {
    final inserted = await _db
        .from('spare_parts')
        .insert(_normalizeData({
          ...data,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp()
        }))
        .select()
        .single();
    return DocumentReference(inserted['id'].toString());
  }

  static Future<void> updateSparePart(
      String id, Map<String, dynamic> data) async {
    await _db
        .from('spare_parts')
        .update(_normalizeData(
            {...data, 'updated_at': FieldValue.serverTimestamp()}))
        .eq('id', int.parse(id));
  }

  static Future<void> updateSparePartStock(String id, int qty) async {
    await _db
        .from('spare_parts')
        .update(_normalizeData({
          'stock_quantity': qty,
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .eq('id', int.parse(id));
  }

  static Future<void> deleteSparePart(String id) async {
    await _db.from('spare_parts').delete().eq('id', int.parse(id));
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getLowStockParts() {
    return _listToSnapshot(
      _db.from('spare_parts').select().lt('stock_quantity', 5).then(
            (value) => (value as List).cast<Map<String, dynamic>>(),
          ),
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream(
      String uid) {
    return _streamToSnapshot(
      _db
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .order('created_at', ascending: false),
    );
  }

  static Future<void> addNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? relatedId,
  }) async {
    await _db.from('notifications').insert(_normalizeData({
          'user_id': userId,
          'type': type,
          'title': title,
          'message': message,
          'related_id': relatedId,
          'is_read': false,
          'created_at': FieldValue.serverTimestamp(),
        }));

    try {
      await _db.functions.invoke('send-push', body: {
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        'relatedId': relatedId,
      });
    } catch (_) {
      // Ignore if push function is not deployed yet.
    }
  }

  static Future<void> markNotificationRead(String id) async {
    await _db
        .from('notifications')
        .update({'is_read': true}).eq('id', int.parse(id));
  }

  static Future<void> markAllNotificationsRead(String uid) async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }

  static Future<DocumentReference> addTransaction({
    required String serviceId,
    required double amount,
    String paymentStatus = 'pending',
    String? paymentMethod,
  }) async {
    final inserted = await _db
        .from('transactions')
        .insert(_normalizeData({
          'service_id': int.tryParse(serviceId) ?? serviceId,
          'amount': amount,
          'payment_status': paymentStatus,
          'payment_method': paymentMethod,
          'transaction_date': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .select()
        .single();
    return DocumentReference(inserted['id'].toString());
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> transactionsStream() {
    return _streamToSnapshot(
      _db.from('transactions').stream(
          primaryKey: ['id']).order('transaction_date', ascending: false),
    );
  }

  static Future<void> updateTransactionStatus(String id, String status) async {
    await _db
        .from('transactions')
        .update(_normalizeData({
          'payment_status': status,
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .eq('id', int.parse(id));
  }

  static Future<Map<String, double>> getRevenueSummary() async {
    final rows = await _db
        .from('transactions')
        .select('amount, transaction_date')
        .eq('payment_status', 'paid');
    final result = <String, double>{};
    for (final item in (rows as List)) {
      final raw = item['transaction_date']?.toString();
      final date = raw != null ? DateTime.tryParse(raw) : null;
      if (date == null) continue;
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      result[key] =
          (result[key] ?? 0) + ((item['amount'] as num?)?.toDouble() ?? 0);
    }
    return result;
  }

  static Future<String?> getSetting(String key) async {
    final doc =
        await _db.from('settings').select('value').eq('key', key).maybeSingle();
    return doc?['value']?.toString();
  }

  static Future<Map<String, String>> getAllSettings() async {
    final rows = await _db.from('settings').select();
    return {
      for (final row in (rows as List))
        row['key'].toString(): (row['value'] ?? '').toString(),
    };
  }

  static Future<void> setSetting(String key, String value,
      {String type = 'text', String? description}) async {
    await _db.from('settings').upsert(_normalizeData({
          'key': key,
          'value': value,
          'type': type,
          'description': description ?? '',
          'updated_at': FieldValue.serverTimestamp(),
        }));
  }

  static Future<Map<String, dynamic>?> getStoreSettings() async {
    final doc = await _db
        .from('store_settings')
        .select()
        .eq('id', 'config')
        .maybeSingle();
    final parsed = doc == null
        ? <String, dynamic>{}
        : _deserializeRow(Map<String, dynamic>.from(doc));
    final extraSettings = await getAllSettings();

    List<String> openDays = const [];
    try {
      final raw = extraSettings['store_open_days'] ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        openDays = decoded.map((item) => item.toString()).toList();
      }
    } catch (_) {
      openDays = const [];
    }

    return {
      ...parsed,
      'address':
          parsed['store_address'] ?? extraSettings['store_address'] ?? '',
      'store_address':
          parsed['store_address'] ?? extraSettings['store_address'] ?? '',
      'email': extraSettings['store_email'] ?? '',
      'description':
          extraSettings['store_description'] ?? parsed['pickup_notes'] ?? '',
      'open_time': extraSettings['store_open_time'] ?? '',
      'close_time': extraSettings['store_close_time'] ?? '',
      'open_days': openDays,
    };
  }

  static Future<void> saveStoreSettings(Map<String, dynamic> data) async {
    final openDays =
        (data['open_days'] as List?)?.map((item) => item.toString()).toList() ??
            const <String>[];
    final openTime = (data['open_time'] ?? '').toString().trim();
    final closeTime = (data['close_time'] ?? '').toString().trim();
    final dayLabel = openDays.isEmpty ? 'Setiap Hari' : openDays.join(', ');
    final openHours = openTime.isEmpty && closeTime.isEmpty
        ? dayLabel
        : '$dayLabel, $openTime - $closeTime';

    await _db.from('store_settings').upsert(_normalizeData({
          'id': 'config',
          'store_name': data['store_name'] ?? '',
          'store_address': data['address'] ?? data['store_address'] ?? '',
          'phone': data['phone'] ?? '',
          'whatsapp_phone': data['whatsapp_phone'] ?? '',
          'bank_name': data['bank_name'] ?? '',
          'bank_account_name': data['bank_account_name'] ?? '',
          'bank_account_number': data['bank_account_number'] ?? '',
          'qris_image_base64': data['qris_image_base64'],
          'pickup_notes': data['description'] ?? data['pickup_notes'] ?? '',
          'open_hours': openHours,
          'updated_at': FieldValue.serverTimestamp(),
        }));

    await Future.wait([
      setSetting('store_address', (data['address'] ?? '').toString()),
      setSetting('store_email', (data['email'] ?? '').toString()),
      setSetting('store_description', (data['description'] ?? '').toString()),
      setSetting('store_open_time', openTime),
      setSetting('store_close_time', closeTime),
      setSetting('store_open_days', jsonEncode(openDays)),
    ]);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> counterCategoriesStream() {
    return _streamToSnapshot(
      _db
          .from('counter_categories')
          .stream(primaryKey: ['id'])
          .eq('is_active', true)
          .order('sort_order'),
    );
  }

  static Future<void> ensureDefaultCounterCategories() async {
    final existing = await _db.from('counter_categories').select('id').limit(1);
    if ((existing as List).isNotEmpty) return;
    final defaults = [
      {
        'name': 'Pulsa',
        'icon': 'phone_android',
        'color': '#FF6B35',
        'sort_order': 1
      },
      {
        'name': 'Paket Data',
        'icon': 'wifi',
        'color': '#3B82F6',
        'sort_order': 2
      },
      {
        'name': 'Token Listrik',
        'icon': 'bolt',
        'color': '#F59E0B',
        'sort_order': 3
      },
      {
        'name': 'Voucher Game',
        'icon': 'sports_esports',
        'color': '#8B5CF6',
        'sort_order': 4
      },
      {
        'name': 'Tagihan',
        'icon': 'receipt_long',
        'color': '#22C55E',
        'sort_order': 5
      },
    ];
    for (final item in defaults) {
      await addCounterCategory(item);
    }
  }

  static Future<void> addCounterCategory(Map<String, dynamic> data) async {
    await _db.from('counter_categories').insert(_normalizeData({
          'name': data['name'] ?? '',
          'icon': data['icon'] ?? 'tag',
          'color': data['color'] ?? '#667eea',
          'sort_order': data['sort_order'] ?? 0,
          'is_active': true,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }));
  }

  static Future<void> updateCounterCategory(
      String id, Map<String, dynamic> data) async {
    await _db
        .from('counter_categories')
        .update(_normalizeData(
            {...data, 'updated_at': FieldValue.serverTimestamp()}))
        .eq('id', int.parse(id));
  }

  static Future<DocumentReference> addCounterTransaction(
      Map<String, dynamic> data) async {
    final modal = (data['modal_price'] ?? 0.0).toDouble();
    final selling = (data['selling_price'] ?? 0.0).toDouble();
    final inserted = await _db
        .from('counter_transactions')
        .insert(_normalizeData({
          'transaction_date':
              data['transaction_date'] ?? FieldValue.serverTimestamp(),
          'category_id': data['category_id'] != null
              ? int.tryParse(data['category_id'].toString())
              : null,
          'category_name': data['category_name'] ?? '',
          'product_name': data['product_name'] ?? '',
          'customer_info': data['customer_info'] ?? '',
          'modal_price': modal,
          'selling_price': selling,
          'profit': selling - modal,
          'payment_method': data['payment_method'] ?? 'cash',
          'receipt_image': data['receipt_image'],
          'ocr_raw_text': data['ocr_raw_text'],
          'notes': data['notes'] ?? '',
          'created_by': data['created_by'],
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .select()
        .single();
    return DocumentReference(inserted['id'].toString());
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> counterTransactionsStream(
      {DateTime? date}) {
    Stream<List<Map<String, dynamic>>> stream = _db
        .from('counter_transactions')
        .stream(primaryKey: ['id']).order('transaction_date', ascending: false);
    if (date != null) {
      stream = _filterRowsByDay(stream, 'transaction_date', date);
    }
    return _streamToSnapshot(stream);
  }

  static Future<void> updateCounterTransaction(
      String id, Map<String, dynamic> data) async {
    final normalized = Map<String, dynamic>.from(data);
    if (normalized.containsKey('selling_price') ||
        normalized.containsKey('modal_price')) {
      final modal = (normalized['modal_price'] ?? 0.0).toDouble();
      final selling = (normalized['selling_price'] ?? 0.0).toDouble();
      normalized['profit'] = selling - modal;
    }
    await _db
        .from('counter_transactions')
        .update(
          _normalizeData(
              {...normalized, 'updated_at': FieldValue.serverTimestamp()}),
        )
        .eq('id', int.parse(id));
  }

  static Future<void> deleteCounterTransaction(String id) async {
    await _db.from('counter_transactions').delete().eq('id', int.parse(id));
  }

  static Future<Map<String, dynamic>> getCounterDailySummary(
      DateTime date) async {
    final snap = await counterTransactionsStream(date: date).first;
    double revenue = 0;
    double profit = 0;
    for (final d in snap.docs) {
      revenue += (d['selling_price'] as num? ?? 0).toDouble();
      profit += (d['profit'] as num? ?? 0).toDouble();
    }
    return {'count': snap.docs.length, 'revenue': revenue, 'profit': profit};
  }

  static Future<DocumentReference> addCounterExpense(
      Map<String, dynamic> data) async {
    final inserted = await _db
        .from('counter_expenses')
        .insert(_normalizeData({
          'expense_date': data['expense_date'] ?? FieldValue.serverTimestamp(),
          'description': data['description'] ?? '',
          'amount': (data['amount'] ?? 0.0).toDouble(),
          'category': data['category'] ?? 'Operasional',
          'receipt_image': data['receipt_image'],
          'created_by': data['created_by'],
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .select()
        .single();
    return DocumentReference(inserted['id'].toString());
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> counterExpensesStream(
      {DateTime? date}) {
    Stream<List<Map<String, dynamic>>> stream = _db
        .from('counter_expenses')
        .stream(primaryKey: ['id']).order('expense_date', ascending: false);
    if (date != null) {
      stream = _filterRowsByDay(stream, 'expense_date', date);
    }
    return _streamToSnapshot(stream);
  }

  static Future<void> deleteCounterExpense(String id) async {
    await _db.from('counter_expenses').delete().eq('id', int.parse(id));
  }

  static String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static Future<void> ensurePpobMasterData() async {
    await PpobCatalogService.ensureLocalBackups();

    final existingApps = await _db
        .from('ppob_apps')
        .select('id_aplikasi')
        .eq('is_active', true)
        .limit(1);
    final existingCategories = await _db
        .from('ppob_categories')
        .select('id_kategori')
        .eq('is_active', true)
        .limit(1);
    final existingServices = await _db
        .from('ppob_services')
        .select('id_layanan')
        .eq('is_active', true)
        .limit(1);

    if ((existingApps as List).isNotEmpty &&
        (existingCategories as List).isNotEmpty &&
        (existingServices as List).isNotEmpty) {
      await _syncPpobLocalBackups();
      return;
    }

    final apps = await PpobCatalogService.loadDefaultApps();
    final categories = await PpobCatalogService.loadDefaultCategories();

    for (final app in apps) {
      await _db.from('ppob_apps').upsert(_normalizeData({
            'id_aplikasi': app['id_aplikasi'],
            'nama_aplikasi': app['nama_aplikasi'] ?? '',
            'jenis_layanan': app['jenis_layanan'] ?? '',
            'is_active': true,
            'updated_at': FieldValue.serverTimestamp(),
          }));
    }

    for (var index = 0; index < categories.length; index++) {
      final category = categories[index];
      await _db.from('ppob_categories').upsert(_normalizeData({
            'id_kategori': category['id_kategori'],
            'nama_kategori': category['nama_kategori'] ?? '',
            'tipe_transaksi': category['tipe_transaksi'] ?? 'prabayar',
            'sort_order': index + 1,
            'is_active': true,
            'updated_at': FieldValue.serverTimestamp(),
          }));

      final services = (category['layanan'] as List?) ?? const [];
      for (final service in services) {
        final item = Map<String, dynamic>.from(service as Map);
        await _db.from('ppob_services').upsert(_normalizeData({
              'id_layanan': item['id_layanan'],
              'category_id': category['id_kategori'],
              'nama_layanan': item['nama'] ?? '',
              'tipe_override': item['tipe_override'],
              'is_active': true,
              'updated_at': FieldValue.serverTimestamp(),
            }));
      }
    }

    await _syncPpobLocalBackups();
  }

  static Future<void> _syncPpobLocalBackups() async {
    final appRows = await _db
        .from('ppob_apps')
        .select('id_aplikasi, nama_aplikasi, jenis_layanan, is_active')
        .eq('is_active', true)
        .order('nama_aplikasi');
    final categoryRows = await _db
        .from('ppob_categories')
        .select(
            'id_kategori, nama_kategori, tipe_transaksi, sort_order, is_active')
        .eq('is_active', true)
        .order('sort_order');
    final serviceRows = await _db
        .from('ppob_services')
        .select(
            'id_layanan, category_id, nama_layanan, tipe_override, is_active')
        .eq('is_active', true)
        .order('nama_layanan');

    final apps = (appRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .map(
          (row) => {
            'id_aplikasi': row['id_aplikasi'],
            'nama_aplikasi': row['nama_aplikasi'] ?? '',
            'jenis_layanan': row['jenis_layanan'] ?? '',
          },
        )
        .toList();

    final services = (serviceRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    final categories = (categoryRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .map((row) {
      final categoryId = row['id_kategori']?.toString() ?? '';
      final categoryServices = services
          .where((item) => item['category_id']?.toString() == categoryId)
          .map((item) {
        final payload = <String, dynamic>{
          'id_layanan': item['id_layanan'],
          'nama': item['nama_layanan'] ?? '',
        };
        final override = (item['tipe_override'] ?? '').toString();
        if (override.isNotEmpty) {
          payload['tipe_override'] = override;
        }
        return payload;
      }).toList();

      return {
        'id_kategori': row['id_kategori'],
        'nama_kategori': row['nama_kategori'] ?? '',
        'tipe_transaksi': row['tipe_transaksi'] ?? 'prabayar',
        'layanan': categoryServices,
      };
    }).toList();

    await PpobCatalogService.saveCatalogBackups(
      apps: apps,
      categories: categories,
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> ppobAppsStream() {
    return _streamToSnapshot(
      _db
          .from('ppob_apps')
          .stream(primaryKey: ['id_aplikasi'])
          .eq('is_active', true)
          .order('nama_aplikasi'),
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> ppobCategoriesStream() {
    return _streamToSnapshot(
      _db
          .from('ppob_categories')
          .stream(primaryKey: ['id_kategori'])
          .eq('is_active', true)
          .order('sort_order'),
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> ppobServicesStream({
    String? categoryId,
  }) {
    Stream<List<Map<String, dynamic>>> stream = _db
        .from('ppob_services')
        .stream(primaryKey: ['id_layanan'])
        .eq('is_active', true)
        .order('nama_layanan');
    if (categoryId != null && categoryId.isNotEmpty) {
      stream = _filterRowsByField(stream, 'category_id', categoryId);
    }
    return _streamToSnapshot(stream);
  }

  static Future<void> addPpobApp(Map<String, dynamic> data) async {
    final id = (data['id_aplikasi'] ?? '').toString().trim();
    final name = (data['nama_aplikasi'] ?? '').toString().trim();
    if (id.isEmpty || name.isEmpty) {
      throw BackendException(
          'validation', 'PPOB app ID and name are required.');
    }

    final existing =
        await _db.from('ppob_apps').select('id_aplikasi, nama_aplikasi');
    for (final row in (existing as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      if (map['id_aplikasi'] == id ||
          map['nama_aplikasi'].toString().toLowerCase() == name.toLowerCase()) {
        throw BackendException('duplicate', 'PPOB app already exists.');
      }
    }

    await _db.from('ppob_apps').insert(_normalizeData({
          'id_aplikasi': id,
          'nama_aplikasi': name,
          'jenis_layanan': data['jenis_layanan'] ?? '',
          'is_active': true,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }));

    await _syncPpobLocalBackups();
  }

  static Future<void> updatePpobApp(
      String id, Map<String, dynamic> data) async {
    final existing =
        await _db.from('ppob_apps').select('id_aplikasi, nama_aplikasi');
    final nextName = (data['nama_aplikasi'] ?? '').toString().trim();
    for (final row in (existing as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      if (map['id_aplikasi'] == id) continue;
      if (nextName.isNotEmpty &&
          map['nama_aplikasi'].toString().toLowerCase() ==
              nextName.toLowerCase()) {
        throw BackendException('duplicate', 'PPOB app already exists.');
      }
    }

    await _db
        .from('ppob_apps')
        .update(_normalizeData(
            {...data, 'updated_at': FieldValue.serverTimestamp()}))
        .eq('id_aplikasi', id);

    await _syncPpobLocalBackups();
  }

  static Future<void> addPpobCategory(Map<String, dynamic> data) async {
    final id = (data['id_kategori'] ?? '').toString().trim();
    final name = (data['nama_kategori'] ?? '').toString().trim();
    if (id.isEmpty || name.isEmpty) {
      throw BackendException(
          'validation', 'Category ID and name are required.');
    }

    final existing =
        await _db.from('ppob_categories').select('id_kategori, nama_kategori');
    for (final row in (existing as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      if (map['id_kategori'] == id ||
          map['nama_kategori'].toString().toLowerCase() == name.toLowerCase()) {
        throw BackendException('duplicate', 'PPOB category already exists.');
      }
    }

    await _db.from('ppob_categories').insert(_normalizeData({
          'id_kategori': id,
          'nama_kategori': name,
          'tipe_transaksi': data['tipe_transaksi'] ?? 'prabayar',
          'sort_order': data['sort_order'] ?? 0,
          'is_active': true,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }));

    await _syncPpobLocalBackups();
  }

  static Future<void> updatePpobCategory(
    String id,
    Map<String, dynamic> data,
  ) async {
    final existing =
        await _db.from('ppob_categories').select('id_kategori, nama_kategori');
    final nextName = (data['nama_kategori'] ?? '').toString().trim();
    for (final row in (existing as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      if (map['id_kategori'] == id) continue;
      if (nextName.isNotEmpty &&
          map['nama_kategori'].toString().toLowerCase() ==
              nextName.toLowerCase()) {
        throw BackendException('duplicate', 'PPOB category already exists.');
      }
    }

    await _db
        .from('ppob_categories')
        .update(_normalizeData(
            {...data, 'updated_at': FieldValue.serverTimestamp()}))
        .eq('id_kategori', id);

    await _syncPpobLocalBackups();
  }

  static Future<void> addPpobService(Map<String, dynamic> data) async {
    final id = (data['id_layanan'] ?? '').toString().trim();
    final name = (data['nama_layanan'] ?? '').toString().trim();
    final categoryId = (data['category_id'] ?? '').toString().trim();
    if (id.isEmpty || name.isEmpty || categoryId.isEmpty) {
      throw BackendException(
          'validation', 'Service ID, name, and category are required.');
    }

    final existing = await _db
        .from('ppob_services')
        .select('id_layanan, nama_layanan, category_id');
    for (final row in (existing as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      if (map['id_layanan'] == id) {
        throw BackendException('duplicate', 'PPOB service already exists.');
      }
      if (map['category_id'] == categoryId &&
          map['nama_layanan'].toString().toLowerCase() == name.toLowerCase()) {
        throw BackendException('duplicate', 'PPOB service already exists.');
      }
    }

    await _db.from('ppob_services').insert(_normalizeData({
          'id_layanan': id,
          'category_id': categoryId,
          'nama_layanan': name,
          'tipe_override': data['tipe_override'],
          'is_active': true,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }));

    await _syncPpobLocalBackups();
  }

  static Future<void> updatePpobService(
    String id,
    Map<String, dynamic> data,
  ) async {
    final existing = await _db
        .from('ppob_services')
        .select('id_layanan, nama_layanan, category_id');
    final nextName = (data['nama_layanan'] ?? '').toString().trim();
    final nextCategoryId = (data['category_id'] ?? '').toString().trim();
    for (final row in (existing as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      if (map['id_layanan'] == id) continue;
      if (nextName.isNotEmpty &&
          map['category_id'].toString() == nextCategoryId &&
          map['nama_layanan'].toString().toLowerCase() ==
              nextName.toLowerCase()) {
        throw BackendException('duplicate', 'PPOB service already exists.');
      }
    }

    await _db
        .from('ppob_services')
        .update(_normalizeData(
            {...data, 'updated_at': FieldValue.serverTimestamp()}))
        .eq('id_layanan', id);

    await _syncPpobLocalBackups();
  }

  static String _buildPpobTransactionCode(String appId) {
    final compact = appId
        .replaceAll('app_', '')
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'TRX-$compact-$stamp';
  }

  static Future<DocumentReference> addPpobTransaction(
    Map<String, dynamic> data,
  ) async {
    final modal = (data['modal_price'] as num? ?? 0).toDouble();
    final selling = (data['selling_price'] as num? ?? 0).toDouble();
    final transactionDate = data['transaction_date'] is Timestamp
        ? (data['transaction_date'] as Timestamp).toDate()
        : data['transaction_date'] is DateTime
            ? data['transaction_date'] as DateTime
            : DateTime.now();
    final inserted = await _db
        .from('ppob_transactions')
        .insert(_normalizeData({
          'transaction_code': data['transaction_code'] ??
              _buildPpobTransactionCode(
                  (data['provider_app_id'] ?? '').toString()),
          'provider_app_id': data['provider_app_id'] ?? '',
          'provider_app_name': data['provider_app_name'] ?? '',
          'category_id': data['category_id'] ?? '',
          'category_name': data['category_name'] ?? '',
          'service_id': data['service_id'] ?? '',
          'service_name': data['service_name'] ?? '',
          'transaction_type': data['transaction_type'] ?? 'prabayar',
          'customer_info': data['customer_info'] ?? '',
          'target_number': data['target_number'] ?? '',
          'token_customer_id': data['token_customer_id'] ?? '',
          'modal_price': modal,
          'selling_price': selling,
          'profit': selling - modal,
          'payment_method': data['payment_method'] ?? 'cash',
          'notes': data['notes'] ?? '',
          'receipt_payload': data['receipt_payload'] ?? {},
          'transaction_date': Timestamp.fromDate(transactionDate),
          'created_by': data['created_by'],
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .select()
        .single();

    await getOrCreatePpobDailyBalance(
      (data['provider_app_id'] ?? '').toString(),
      transactionDate,
      createdBy: data['created_by']?.toString(),
    );

    await _applyPpobBalanceDelta(
      appId: (data['provider_app_id'] ?? '').toString(),
      date: transactionDate,
      delta: -modal,
      createdBy: data['created_by']?.toString(),
    );

    return DocumentReference(inserted['id'].toString());
  }

  static Future<void> _applyPpobBalanceDelta({
    required String appId,
    required DateTime date,
    required double delta,
    String? createdBy,
  }) async {
    if (appId.isEmpty || delta == 0) return;
    final balance = await getOrCreatePpobDailyBalance(
      appId,
      date,
      createdBy: createdBy,
    );
    final opening = _asDouble(balance['opening_balance']);
    final closing = _asDouble(balance['closing_balance']);
    await savePpobDailyBalance(
      appId: appId,
      date: date,
      openingBalance: opening,
      closingBalance: closing + delta,
      notes: (balance['notes'] ?? '').toString(),
      createdBy: createdBy,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> ppobTransactionsStream({
    String? appId,
    DateTime? date,
  }) {
    Stream<List<Map<String, dynamic>>> stream = _db
        .from('ppob_transactions')
        .stream(primaryKey: ['id']).order('transaction_date', ascending: false);
    if (appId != null && appId.isNotEmpty) {
      stream = _filterRowsByField(stream, 'provider_app_id', appId);
    }
    if (date != null) {
      stream = _filterRowsByDay(stream, 'transaction_date', date);
    }
    return _streamToSnapshot(stream);
  }

  static Future<void> deletePpobTransaction(String id) async {
    await _db.from('ppob_transactions').delete().eq('id', int.parse(id));
  }

  static Future<void> deletePpobTransactionSecure(
    String id, {
    required String adminPassword,
  }) async {
    await verifyCurrentPassword(adminPassword);

    final existing = await _db
        .from('ppob_transactions')
        .select()
        .eq('id', int.parse(id))
        .maybeSingle();
    if (existing == null) {
      throw BackendException('not_found', 'Transaksi PPOB tidak ditemukan.');
    }

    final row = _deserializeRow(Map<String, dynamic>.from(existing));
    final appId = (row['provider_app_id'] ?? '').toString();
    final rawDate = row['transaction_date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    final modal = _asDouble(row['modal_price']);
    final createdBy = row['created_by']?.toString();

    await _db.from('ppob_transactions').delete().eq('id', int.parse(id));
    await _applyPpobBalanceDelta(
      appId: appId,
      date: date,
      delta: modal,
      createdBy: createdBy,
    );
  }

  static Future<List<Map<String, dynamic>>> getPpobTransactionsReport({
    required String appId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final rows = await _db
        .from('ppob_transactions')
        .select()
        .eq('provider_app_id', appId)
        .order('transaction_date', ascending: false);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day)
        .add(const Duration(days: 1));
    return (rows as List)
        .map((item) => _deserializeRow(Map<String, dynamic>.from(item as Map)))
        .where((row) {
      final raw = row['transaction_date'];
      final date = raw is Timestamp
          ? raw.toDate()
          : DateTime.tryParse(raw?.toString() ?? '');
      if (date == null) return false;
      final local = date.toLocal();
      return !local.isBefore(start) && local.isBefore(end);
    }).toList();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> ppobDailyBalanceStream({
    required String appId,
    required DateTime date,
  }) {
    Stream<List<Map<String, dynamic>>> stream = _db
        .from('ppob_daily_balances')
        .stream(primaryKey: ['id']).order('balance_date', ascending: false);
    stream = _filterRowsByField(stream, 'provider_app_id', appId);
    stream = _filterRowsByField(stream, 'balance_date', _dateKey(date));
    return _streamToSnapshot(stream);
  }

  static Future<Map<String, dynamic>> getOrCreatePpobDailyBalance(
    String appId,
    DateTime date, {
    String? createdBy,
  }) async {
    final key = _dateKey(date);
    final existing = await _db
        .from('ppob_daily_balances')
        .select()
        .eq('provider_app_id', appId)
        .eq('balance_date', key)
        .maybeSingle();
    if (existing != null) {
      return _deserializeRow(Map<String, dynamic>.from(existing));
    }

    final previousRows = await _db
        .from('ppob_daily_balances')
        .select()
        .eq('provider_app_id', appId)
        .lt('balance_date', key)
        .order('balance_date', ascending: false)
        .limit(1);
    double openingBalance = 0;
    if ((previousRows as List).isNotEmpty) {
      final previous = Map<String, dynamic>.from(previousRows.first as Map);
      openingBalance = ((previous['closing_balance'] as num?)?.toDouble() ?? 0);
    }

    final inserted = await _db
        .from('ppob_daily_balances')
        .insert(_normalizeData({
          'provider_app_id': appId,
          'balance_date': key,
          'opening_balance': openingBalance,
          'closing_balance': openingBalance,
          'notes': '',
          'created_by': createdBy,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }))
        .select()
        .single();
    return _deserializeRow(Map<String, dynamic>.from(inserted));
  }

  static Future<void> savePpobDailyBalance({
    required String appId,
    required DateTime date,
    required double openingBalance,
    required double closingBalance,
    String notes = '',
    String? createdBy,
  }) async {
    final key = _dateKey(date);
    final existing = await _db
        .from('ppob_daily_balances')
        .select()
        .eq('provider_app_id', appId)
        .eq('balance_date', key)
        .maybeSingle();
    final previousClosing = existing == null
        ? null
        : ((existing['closing_balance'] as num?)?.toDouble() ?? 0);
    final payload = _normalizeData({
      'provider_app_id': appId,
      'balance_date': key,
      'opening_balance': openingBalance,
      'closing_balance': closingBalance,
      'notes': notes,
      'created_by': createdBy,
      'updated_at': FieldValue.serverTimestamp(),
    });
    if (existing == null) {
      await _db.from('ppob_daily_balances').insert({
        ...payload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } else {
      await _db
          .from('ppob_daily_balances')
          .update(payload)
          .eq('id', existing['id']);
    }

    final nextRows = await _db
        .from('ppob_daily_balances')
        .select()
        .eq('provider_app_id', appId)
        .gt('balance_date', key)
        .order('balance_date')
        .limit(1);
    if ((nextRows as List).isNotEmpty) {
      final next = Map<String, dynamic>.from(nextRows.first as Map);
      final nextOpening = ((next['opening_balance'] as num?)?.toDouble() ?? 0);
      if (previousClosing == null ||
          nextOpening == 0 ||
          (nextOpening - previousClosing).abs() < 0.0001) {
        await _db
            .from('ppob_daily_balances')
            .update(_normalizeData({
              'opening_balance': closingBalance,
              'updated_at': FieldValue.serverTimestamp(),
            }))
            .eq('id', next['id']);
      }
    }
  }

  static Future<Map<String, dynamic>> getPpobReceiptSettings() async {
    final existing = await _db
        .from('ppob_receipt_settings')
        .select()
        .eq('id', 'default')
        .maybeSingle();
    final store = await getStoreSettings() ?? <String, dynamic>{};
    final parsed = existing == null
        ? <String, dynamic>{}
        : _deserializeRow(Map<String, dynamic>.from(existing));
    return {
      'header_image_base64': parsed['header_image_base64'] ?? '',
      'header_text':
          parsed['header_text'] ?? store['store_name'] ?? 'DigiTech Service',
      'address': parsed['address'] ?? store['store_address'] ?? '',
      'footer_text': parsed['footer_text'] ?? '',
    };
  }

  static Future<void> savePpobReceiptSettings(Map<String, dynamic> data) async {
    await _db.from('ppob_receipt_settings').upsert(_normalizeData({
          'id': 'default',
          'header_image_base64': data['header_image_base64'] ?? '',
          'header_text': data['header_text'] ?? '',
          'address': data['address'] ?? '',
          'footer_text': data['footer_text'] ?? '',
          'updated_at': FieldValue.serverTimestamp(),
        }));
  }

  static Future<Map<String, dynamic>> getPpobPrinterSettings() async {
    final existing = await _db
        .from('ppob_printer_settings')
        .select()
        .eq('id', 'default')
        .maybeSingle();
    final parsed = existing == null
        ? <String, dynamic>{}
        : _deserializeRow(Map<String, dynamic>.from(existing));
    return {
      'printer_name': parsed['printer_name'] ?? '',
      'printer_address': parsed['printer_address'] ?? '',
      'paper_size': parsed['paper_size'] ?? '58',
      'auto_print': parsed['auto_print'] ?? false,
    };
  }

  static Future<void> savePpobPrinterSettings(Map<String, dynamic> data) async {
    await _db.from('ppob_printer_settings').upsert(_normalizeData({
          'id': 'default',
          'printer_name': data['printer_name'] ?? '',
          'printer_address': data['printer_address'] ?? '',
          'paper_size': data['paper_size'] ?? '58',
          'auto_print': data['auto_print'] ?? false,
          'updated_at': FieldValue.serverTimestamp(),
        }));
  }

  static Future<DocumentReference> saveDiagnosisHistory({
    required int categoryId,
    required String categoryName,
    String? deviceInfo,
    required List<int> selectedSymptomIds,
    required List<Map<String, dynamic>> results,
    required String topDiagnosis,
    required double cfPercentage,
    String? userId,
  }) async {
    final inserted = await _db
        .from('cf_diagnosis_history')
        .insert(_normalizeData({
          'category_id': categoryId,
          'category_name': categoryName,
          'device_info': deviceInfo ?? '',
          'symptoms': selectedSymptomIds,
          'results': results,
          'top_diagnosis': topDiagnosis,
          'cf_percentage': cfPercentage,
          'user_id': userId,
          'created_at': FieldValue.serverTimestamp(),
        }))
        .select()
        .single();
    return DocumentReference(inserted['id'].toString());
  }

  static Future<Map<String, dynamic>?> getDiagnosisConfig() async {
    final data = await _db
        .from('diagnosis_configs')
        .select()
        .eq('id', 'default')
        .maybeSingle();
    if (data == null) return null;
    return _deserializeRow(Map<String, dynamic>.from(data));
  }

  static Future<void> upsertDiagnosisConfig(Map<String, dynamic> data) async {
    await _db.from('diagnosis_configs').upsert(_normalizeData({
          'id': 'default',
          ...data,
          'updated_at': FieldValue.serverTimestamp(),
        }));
  }

  static Future<void> uploadDiagnosisFile({
    required String path,
    required String content,
  }) async {
    await _db.storage.from(_diagnosisBucket).uploadBinary(
          path,
          Uint8List.fromList(utf8.encode(content)),
          fileOptions: const supabase.FileOptions(
            upsert: true,
            contentType: 'application/json',
          ),
        );
  }

  static Future<String?> downloadDiagnosisFile(String path) async {
    try {
      final bytes = await _db.storage.from(_diagnosisBucket).download(path);
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> diagnosisHistoryStream(
      {String? userId}) {
    Stream<List<Map<String, dynamic>>> stream = _db
        .from('cf_diagnosis_history')
        .stream(primaryKey: ['id']).order('created_at', ascending: false);
    if (userId != null) stream = _filterRowsByField(stream, 'user_id', userId);
    return _streamToSnapshot(stream);
  }

  static Future<void> logActivity({
    required String userId,
    required String action,
    String? targetCollection,
    String? targetId,
    Map<String, dynamic>? meta,
  }) async {
    await _db.from('activity_logs').insert(_normalizeData({
          'user_id': userId,
          'action': action,
          'target_collection': targetCollection,
          'target_id': targetId,
          'meta': meta ?? {},
          'created_at': FieldValue.serverTimestamp(),
        }));
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> activityLogsStream(
      {String? userId}) {
    Stream<List<Map<String, dynamic>>> stream = _db
        .from('activity_logs')
        .stream(primaryKey: ['id']).order('created_at', ascending: false);
    if (userId != null) stream = _filterRowsByField(stream, 'user_id', userId);
    return _streamToSnapshot(stream);
  }

  static Future<Map<String, int>> getCustomerDashboardStats(String uid) async {
    final bookings =
        await _db.from('bookings').select('status').eq('customer_id', uid);
    final services =
        await _db.from('services').select('status').eq('customer_id', uid);
    final bookingRows = (bookings as List).cast<Map<String, dynamic>>();
    final serviceRows = (services as List).cast<Map<String, dynamic>>();
    final total = bookingRows.length;
    final pending = bookingRows
            .where((d) => ['pending', 'approved'].contains(d['status']))
            .length +
        serviceRows
            .where((d) => ['pending', 'in_progress'].contains(d['status']))
            .length;
    final completed = serviceRows
        .where((d) => ['completed', 'sudah_diambil'].contains(d['status']))
        .length;
    return {
      'totalBookings': total,
      'pendingCount': pending,
      'completedCount': completed
    };
  }

  static Future<Map<String, dynamic>> getAdminDashboardStats() async {
    final pendingBookings =
        await _db.from('bookings').select('id').eq('status', 'pending');
    final activeServices =
        await _db.from('services').select('id').eq('status', 'in_progress');
    final completedServices =
        await _db.from('services').select('id').eq('status', 'completed');
    final paidTx = await _db
        .from('transactions')
        .select('amount')
        .eq('payment_status', 'paid');
    double totalRevenue = 0;
    for (final row in (paidTx as List)) {
      totalRevenue += (row['amount'] as num? ?? 0).toDouble();
    }
    return {
      'pendingBookings': (pendingBookings as List).length,
      'activeServices': (activeServices as List).length,
      'completedServices': (completedServices as List).length,
      'totalRevenue': totalRevenue,
    };
  }

  static Future<Map<String, dynamic>> getAdminDashboardData() async {
    final allServices = (await _db.from('services').select()) as List;
    final customers = (await _db.from('customers').select('id')) as List;
    final paidTransactions = (await _db
        .from('transactions')
        .select('amount')
        .eq('payment_status', 'paid')) as List;
    final pendingBookings = (await _db
        .from('bookings')
        .select('id')
        .eq('status', 'pending')) as List;
    final recentServices = (await _db
        .from('services')
        .select('service_code,customer_name,problem,status')
        .order('created_at', ascending: false)
        .limit(5)) as List;
    final lowStockParts = (await _db
        .from('spare_parts')
        .select('part_name,stock_quantity')
        .eq('stock_quantity', 0)) as List;

    double paidRevenue = 0;
    for (final tx in paidTransactions) {
      paidRevenue += (tx['amount'] as num? ?? 0).toDouble();
    }

    return {
      'totalServices': allServices.length,
      'completedServices':
          allServices.where((d) => d['status'] == 'completed').length,
      'inProgressServices':
          allServices.where((d) => d['status'] == 'in_progress').length,
      'pendingServices':
          allServices.where((d) => d['status'] == 'pending').length,
      'totalCustomers': customers.length,
      'paidRevenue': paidRevenue,
      'pendingBookings': pendingBookings.length,
      'recentServices': recentServices
          .map((e) => _deserializeRow(Map<String, dynamic>.from(e)))
          .toList(),
      'lowStockParts': lowStockParts
          .map((e) => _deserializeRow(Map<String, dynamic>.from(e)))
          .toList(),
    };
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    await _db.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: 'dgsc://reset-password',
    );
  }

  static Future<void> updateCurrentUserPassword(String password) async {
    await _db.auth.updateUser(
      supabase.UserAttributes(password: password),
    );
  }
}

typedef SupabaseDbService = BackendService;

@Deprecated('Use BackendService instead.')
typedef FirebaseDbService = BackendService;
