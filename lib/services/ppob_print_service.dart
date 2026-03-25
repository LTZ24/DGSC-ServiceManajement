import 'dart:convert';
import 'dart:io';

import 'package:blue_thermal_helper/blue_thermal_helper.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' show PosAlign;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PpobPrintService {
  static final BlueThermalHelper _printer = BlueThermalHelper.instance;

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  static const Set<String> _phoneTargetCategoryIds = {
    'pulsa_data',
    'ewallet_emoney',
  };

  static const Set<String> _idTargetCategoryIds = {
    'game_hiburan',
    'tagihan_utilitas',
    'telekomunikasi_pasca',
    'multifinance',
    'asuransi_bpjs',
    'pajak_negara',
    'pendidikan_donasi',
    'tiket_travel',
  };

  static Future<void> preparePrinter({String paperSize = '58'}) async {
    _printer.setPaper(_paperFromSize(paperSize));
  }

  static Future<List<BluetoothPrinter>> scanDevices() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const <BluetoothPrinter>[];
    }
    await _requestPermissions();
    final isOn = await _printer.isBluetoothOn();
    if (!isOn) {
      await _printer.requestEnableBluetooth();
    }
    return _printer.scan(timeout: 8);
  }

  static Future<bool> connect(
    String address, {
    String paperSize = '58',
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    await _requestPermissions();
    await preparePrinter(paperSize: paperSize);
    return _printer.connect(address);
  }

  static Future<void> disconnect() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _printer.disconnect();
  }

  static Future<bool> isConnected() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    return _printer.isConnected();
  }

  static Future<String> previewTransactionReceipt({
    required Map<String, dynamic> transaction,
    required Map<String, dynamic> receiptSettings,
    required Map<String, dynamic> storeSettings,
    String paperSize = '58',
  }) async {
    await preparePrinter(paperSize: paperSize);
    return _printer.previewReceipt(
      (r) => _buildReceipt(
        r,
        transaction: transaction,
        receiptSettings: receiptSettings,
        storeSettings: storeSettings,
      ),
      paperOverride: _paperFromSize(paperSize),
    );
  }

  static Future<void> printTransactionReceipt({
    required Map<String, dynamic> transaction,
    required Map<String, dynamic> receiptSettings,
    required Map<String, dynamic> storeSettings,
    String paperSize = '58',
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw Exception(
          'Bluetooth printing is only supported on Android devices.');
    }
    await preparePrinter(paperSize: paperSize);
    final connected = await isConnected();
    if (!connected) {
      throw Exception('Printer is not connected yet.');
    }
    await _printer.printReceipt(
      (r) => _buildReceipt(
        r,
        transaction: transaction,
        receiptSettings: receiptSettings,
        storeSettings: storeSettings,
      ),
      paperOverride: _paperFromSize(paperSize),
    );
  }

  static Future<void> printTestReceipt({
    required Map<String, dynamic> receiptSettings,
    required Map<String, dynamic> storeSettings,
    String paperSize = '58',
  }) async {
    await printTransactionReceipt(
      transaction: {
        'provider_app_name': 'PPOB Demo',
        'transaction_code': 'TEST-${DateTime.now().millisecondsSinceEpoch}',
        'transaction_type': 'test',
        'category_name': 'Printer Test',
        'service_name': 'Bluetooth Connection',
        'customer_info': 'Demo User',
        'transaction_date': DateTime.now().toIso8601String(),
        'modal_price': 0,
        'selling_price': 0,
        'profit': 0,
        'payment_method': 'cash',
        'notes': 'Test print completed',
      },
      receiptSettings: receiptSettings,
      storeSettings: storeSettings,
      paperSize: paperSize,
    );
  }

  static Future<void> _requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  static ThermalPaper _paperFromSize(String paperSize) {
    return paperSize == '80' ? ThermalPaper.mm80 : ThermalPaper.mm58;
  }

  static Future<void> _buildReceipt(
    ThermalReceipt r, {
    required Map<String, dynamic> transaction,
    required Map<String, dynamic> receiptSettings,
    required Map<String, dynamic> storeSettings,
  }) async {
    final headerImage =
        (receiptSettings['header_image_base64'] ?? '').toString();
    if (headerImage.isNotEmpty) {
      try {
        await r.logo(Uint8List.fromList(base64Decode(headerImage)));
      } catch (_) {
        // Ignore invalid image data and continue with text receipt.
      }
    }

    final headerText = (receiptSettings['header_text'] ?? '').toString().trim();
    final storeName =
        (storeSettings['store_name'] ?? 'DigiTech Service').toString();
    final address =
        (receiptSettings['address'] ?? storeSettings['store_address'] ?? '')
            .toString()
            .trim();
    final footer = (receiptSettings['footer_text'] ?? '').toString().trim();
    final createdAt = DateTime.tryParse(
          (transaction['transaction_date'] ?? '').toString(),
        ) ??
        DateTime.now();
    final providerApp =
        (transaction['provider_app_name'] ?? 'PPOB').toString().trim();
    final serviceName =
        (transaction['service_name'] ?? 'Transaksi PPOB').toString().trim();
    final createdBy =
        (transaction['created_by_name'] ?? transaction['staff_name'] ?? 'Admin')
            .toString()
            .trim();
    final targetNumber = (transaction['target_number'] ?? '').toString().trim();
    final customerInfo = (transaction['customer_info'] ?? '').toString().trim();
    final tokenId = (transaction['token_customer_id'] ?? '').toString().trim();
    final modalPrice = (transaction['modal_price'] as num?)?.toDouble() ??
        double.tryParse(transaction['modal_price']?.toString() ?? '0') ??
        0;
    final sellingPrice = (transaction['selling_price'] as num?)?.toDouble() ??
        double.tryParse(transaction['selling_price']?.toString() ?? '0') ??
        0;
    final adminFee = (transaction['profit'] as num?)?.toDouble() ??
        double.tryParse(transaction['profit']?.toString() ?? '') ??
        (sellingPrice - modalPrice);
    final normalizedAdminFee = adminFee < 0 ? 0 : adminFee;
    final payload = _receiptPayload(transaction);
    final extraFields = ((payload['extra_fields'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final lineItems = ((payload['line_items'] as List?) ??
            (transaction['line_items'] as List?) ??
            const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final targetLabel = receiptTargetLabel(transaction);
    final customerLabel = receiptCustomerLabel(transaction);
    final title = serviceName.toLowerCase().startsWith('struk ')
        ? serviceName
        : 'Struk $serviceName';

    r.text(providerApp, center: true, bold: true);
    r.text(
      headerText.isEmpty ? storeName : headerText,
      bold: true,
      center: true,
      size: FontSize.header,
    );
    if (address.isNotEmpty) {
      r.text(address, center: true, size: FontSize.small);
    }
    r.feed(1);
    r.text(title, bold: true, center: true, size: FontSize.medium);
    r.hr();
    _receiptRow(r, 'Waktu', _formatDate(createdAt));
    _receiptRow(r, 'USN', createdBy.isEmpty ? 'Admin' : createdBy);
    _receiptRow(
        r, 'No Trx', (transaction['transaction_code'] ?? '-').toString());
    if (targetNumber.isNotEmpty) {
      _receiptRow(r, targetLabel, targetNumber);
    }
    if (customerInfo.isNotEmpty) {
      _receiptRow(r, customerLabel, customerInfo);
    }
    if (tokenId.isNotEmpty) {
      _receiptRow(r, 'Token', tokenId);
    }
    for (final field in extraFields) {
      final label = (field['label'] ?? '').toString().trim();
      final value = (field['value'] ?? '').toString().trim();
      if (label.isEmpty || value.isEmpty) continue;
      _receiptRow(r, label, value);
    }
    if (lineItems.isNotEmpty) {
      r.hr();
      r.text('Detail Item', bold: true);
      for (final item in lineItems) {
        final name = (item['part_name'] ?? item['name'] ?? '-').toString();
        final code = (item['part_code'] ?? '').toString().trim();
        final qty = int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
        final total = _asItemTotal(item);
        final label = code.isEmpty ? name : '$name ($code)';
        _receiptRow(r, '$label x$qty', _formatMoney(total));
      }
    }
    r.hr();
    _receiptRow(r, 'Jumlah', _formatMoney(modalPrice));
    _receiptRow(r, 'Admin', _formatMoney(normalizedAdminFee));
    r.hr();
    _receiptRow(r, 'Total', _formatMoney(sellingPrice), bold: true);
    _receiptRow(
      r,
      'Metode',
      (transaction['payment_method'] ?? '-').toString().toUpperCase(),
    );
    final notes = (transaction['notes'] ?? '').toString();
    if (notes.isNotEmpty) {
      r.hr();
      r.text('Catatan: $notes', size: FontSize.small);
    }
    if (footer.isNotEmpty) {
      r.hr();
      r.text(footer, center: true, size: FontSize.small);
    }
    r.feed(1);
    r.cut();
  }

  static String receiptTargetLabel(Map<String, dynamic> transaction) {
    final payload = _receiptPayload(transaction);
    final explicit = (payload['target_label'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;

    final categoryId = (transaction['category_id'] ?? '').toString().trim();
    final categoryName =
        (transaction['category_name'] ?? '').toString().toLowerCase().trim();
    final serviceId = (transaction['service_id'] ?? '').toString().trim();
    final serviceName =
        (transaction['service_name'] ?? '').toString().toLowerCase().trim();
    final transactionType =
        (transaction['transaction_type'] ?? '').toString().toLowerCase().trim();

    if (categoryId == 'ecommerce_va' ||
        serviceId.startsWith('va_') ||
        categoryName.contains('virtual account') ||
        serviceName.contains('virtual account')) {
      return 'No VA';
    }

    if (serviceId == 'ba_transfer' ||
        serviceId == 'ba_tarik_bank' ||
        serviceId == 'ba_setor_tunai' ||
        serviceName.contains('transfer') ||
        serviceName.contains('rekening') ||
        serviceName.contains('bank')) {
      return 'No Rek';
    }

    if (_phoneTargetCategoryIds.contains(categoryId) ||
        serviceName.contains('e-wallet') ||
        serviceName.contains('ewallet') ||
        serviceName.contains('dana') ||
        serviceName.contains('ovo') ||
        serviceName.contains('gopay') ||
        serviceName.contains('shopeepay') ||
        serviceName.contains('linkaja') ||
        serviceName.contains('pulsa') ||
        serviceName.contains('kuota') ||
        serviceName.contains('data') ||
        serviceName.contains('nelpon') ||
        serviceName.contains('seluler')) {
      return 'Tujuan';
    }

    if (_idTargetCategoryIds.contains(categoryId) ||
        transactionType == 'pascabayar' ||
        transactionType == 'pemesanan' ||
        serviceName.contains('voucher') ||
        serviceName.contains('tagihan') ||
        serviceName.contains('listrik') ||
        serviceName.contains('pajak') ||
        serviceName.contains('tiket') ||
        serviceName.contains('finance') ||
        serviceName.contains('bpjs')) {
      return 'ID';
    }

    return 'Tujuan';
  }

  static String receiptCustomerLabel(Map<String, dynamic> transaction) {
    final payload = _receiptPayload(transaction);
    final explicit = (payload['customer_label'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;
    return 'Nama';
  }

  static Map<String, dynamic> _receiptPayload(
      Map<String, dynamic> transaction) {
    final raw = transaction['receipt_payload'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return const <String, dynamic>{};
  }

  static double _asItemTotal(Map<String, dynamic> item) {
    final explicit = (item['total_selling'] as num?)?.toDouble() ??
        double.tryParse(item['total_selling']?.toString() ?? '') ??
        0;
    if (explicit > 0) return explicit;

    final qty = int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
    final price = (item['selling_price'] as num?)?.toDouble() ??
        double.tryParse(item['selling_price']?.toString() ?? '0') ??
        0;
    return qty * price;
  }

  static void _receiptRow(
    ThermalReceipt r,
    String label,
    String value, {
    bool bold = false,
  }) {
    final labelWidth = label.length > 6 ? 4 : 3;
    r.rowColumns([
      r.col(label, labelWidth, bold: bold),
      r.col(value, 12 - labelWidth, bold: bold, align: PosAlign.right),
    ]);
  }

  static String _formatDate(DateTime value) {
    return '${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year} ${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
  }

  static String _formatMoney(dynamic value) {
    final amount = (value as num?)?.toDouble() ??
        double.tryParse(value?.toString() ?? '0') ??
        0;
    final text = amount.toStringAsFixed(0);
    final chars = text.split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(chars[i]);
    }
    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  static String formatMoneyLabel(dynamic value) => _formatMoney(value);
}
