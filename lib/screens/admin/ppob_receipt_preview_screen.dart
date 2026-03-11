import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/ppob_print_service.dart';

class PpobReceiptPreviewScreen extends StatefulWidget {
  const PpobReceiptPreviewScreen({
    super.key,
    required this.transaction,
    required this.receiptSettings,
    required this.storeSettings,
    required this.printerSettings,
  });

  final Map<String, dynamic> transaction;
  final Map<String, dynamic> receiptSettings;
  final Map<String, dynamic> storeSettings;
  final Map<String, dynamic> printerSettings;

  @override
  State<PpobReceiptPreviewScreen> createState() =>
      _PpobReceiptPreviewScreenState();
}

class _PpobReceiptPreviewScreenState extends State<PpobReceiptPreviewScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _busy = false;

  String get _providerApp =>
      (widget.transaction['provider_app_name'] ?? 'PPOB').toString();

  String get _headerText {
    final text =
        (widget.receiptSettings['header_text'] ?? '').toString().trim();
    if (text.isNotEmpty) return text;
    return (widget.storeSettings['store_name'] ?? 'DigiTech Service')
        .toString();
  }

  String get _address => (widget.receiptSettings['address'] ??
          widget.storeSettings['store_address'] ??
          '')
      .toString()
      .trim();

  String get _footer =>
      (widget.receiptSettings['footer_text'] ?? '').toString().trim();

  String get _serviceName =>
      (widget.transaction['service_name'] ?? 'Transaksi PPOB').toString();

  String get _transactionCode =>
      (widget.transaction['transaction_code'] ?? '-').toString();

  String get _targetNumber =>
      (widget.transaction['target_number'] ?? '').toString().trim();

  String get _customerName =>
      (widget.transaction['customer_info'] ?? '').toString().trim();

  String get _createdBy => (widget.transaction['created_by_name'] ??
          widget.transaction['staff_name'] ??
          'Admin')
      .toString()
      .trim();

  String get _paymentMethod =>
      (widget.transaction['payment_method'] ?? '-').toString().toUpperCase();

  String get _tokenId =>
      (widget.transaction['token_customer_id'] ?? '').toString().trim();

  String get _targetLabel =>
      PpobPrintService.receiptTargetLabel(widget.transaction);

  String get _customerLabel =>
      PpobPrintService.receiptCustomerLabel(widget.transaction);

  DateTime get _createdAt {
    final raw = widget.transaction['transaction_date'];
    return DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _formatMoney(dynamic value) =>
      PpobPrintService.formatMoneyLabel(value);

  String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  List<_ReceiptField> _receiptFields() {
    final modal = _asDouble(widget.transaction['modal_price']);
    final selling = _asDouble(widget.transaction['selling_price']);
    final fee = _asDouble(widget.transaction['profit']);
    return [
      _ReceiptField('Waktu', _formatDate(_createdAt)),
      _ReceiptField('USN', _createdBy.isEmpty ? 'Admin' : _createdBy),
      _ReceiptField('No Trx', _transactionCode),
      if (_targetNumber.isNotEmpty) _ReceiptField(_targetLabel, _targetNumber),
      if (_customerName.isNotEmpty)
        _ReceiptField(_customerLabel, _customerName),
      if (_tokenId.isNotEmpty) _ReceiptField('Token', _tokenId),
      _ReceiptField('Jumlah', _formatMoney(modal)),
      _ReceiptField('Admin', _formatMoney(fee < 0 ? 0 : fee)),
      _ReceiptField('Total', _formatMoney(selling), isEmphasis: true),
      _ReceiptField('Metode', _paymentMethod),
    ];
  }

  Future<Uint8List> _captureReceiptAsJpg() async {
    final boundary = _receiptKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Preview struk belum siap.');
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Gagal membuat gambar struk.');
    }

    final pngBytes = byteData.buffer.asUint8List();
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      throw Exception('Gagal mengonversi gambar struk.');
    }

    return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
  }

  Future<String> _writeTempReceipt(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      p.join(
        tempDir.path,
        'ppob_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _shareReceipt() async {
    await _runBusy(() async {
      final bytes = await _captureReceiptAsJpg();
      final path = await _writeTempReceipt(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'image/jpeg')],
          text: _serviceName,
        ),
      );
    });
  }

  Future<void> _saveReceiptToGallery() async {
    await _runBusy(() async {
      if (Platform.isAndroid) {
        await [Permission.photos, Permission.storage].request();
      }
      final bytes = await _captureReceiptAsJpg();
      final directory = Directory(
        '/storage/emulated/0/Android/media/com.dgsc.mobile/image',
      );
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File(
        p.join(
          directory.path,
          'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
                'Struk disimpan ke galeri.', 'Receipt saved to gallery.'),
          ),
        ),
      );
    });
  }

  Future<void> _printReceipt() async {
    await _runBusy(() async {
      final address =
          (widget.printerSettings['printer_address'] ?? '').toString();
      final paper = (widget.printerSettings['paper_size'] ?? '58').toString();
      if (address.isEmpty) {
        await _showPrinterSettingsPrompt();
        return;
      }

      final connected = await PpobPrintService.isConnected();
      if (!connected) {
        final success =
            await PpobPrintService.connect(address, paperSize: paper);
        if (!success) {
          await _showPrinterSettingsPrompt();
          return;
        }
      }

      await PpobPrintService.printTransactionReceipt(
        transaction: widget.transaction,
        receiptSettings: widget.receiptSettings,
        storeSettings: widget.storeSettings,
        paperSize: paper,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
              'Struk berhasil dicetak.', 'Receipt printed successfully.')),
        ),
      );
    });
  }

  Future<void> _showPrinterSettingsPrompt() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            context.tr('Printer belum terhubung', 'Printer not connected')),
        content: Text(
          context.tr(
            'Silakan atur koneksi Bluetooth printer terlebih dahulu.',
            'Please configure the Bluetooth printer connection first.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Tutup', 'Close')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/admin/ppob-receipt-settings');
            },
            icon: const Icon(Icons.settings_bluetooth),
            label: Text(context.tr('Buka Pengaturan', 'Open Settings')),
          ),
        ],
      ),
    );
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _receiptFields();
    final modal = _asDouble(widget.transaction['modal_price']);
    final selling = _asDouble(widget.transaction['selling_price']);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Bagikan Struk', 'Share Receipt')),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  RepaintBoundary(
                    key: _receiptKey,
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _providerApp,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _headerText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (_address.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _address,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Text(
                            'Struk $_serviceName',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...fields.map(
                            (field) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 76,
                                    child: Text(
                                      field.label,
                                      style: TextStyle(
                                        fontSize:
                                            field.isEmphasis ? 14.5 : 13.5,
                                        fontWeight: field.isEmphasis
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(':',
                                        style: TextStyle(fontSize: 14)),
                                  ),
                                  Expanded(
                                    child: Text(
                                      field.value,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize:
                                            field.isEmphasis ? 14.5 : 13.5,
                                        fontWeight: field.isEmphasis
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 16),
                          if (_footer.isNotEmpty)
                            Text(
                              _footer,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            )
                          else
                            Text(
                              context.tr(
                                'Simpan struk ini sebagai bukti pembayaran yang sah',
                                'Keep this receipt as valid proof of payment',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _summaryRow(
                    context.tr('Jumlah Tagihan', 'Bill Amount'),
                    _formatMoney(modal),
                  ),
                  _summaryRow(
                    context.tr('Biaya di Struk', 'Receipt Total'),
                    _formatMoney(selling),
                    isAccent: true,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.share_outlined,
                      label: context.tr('Bagikan', 'Share'),
                      onTap: _shareReceipt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.download_outlined,
                      label: context.tr('Simpan', 'Save'),
                      onTap: _saveReceiptToGallery,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.print_outlined,
                      label: context.tr('Cetak', 'Print'),
                      onTap: _printReceipt,
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isAccent = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text(
            value,
            style: TextStyle(
              fontSize: isAccent ? 18 : 16,
              fontWeight: FontWeight.w700,
              color: isAccent ? AppTheme.primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final child = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: filled ? Colors.white : AppTheme.primaryColor),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: filled ? Colors.white : AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return SizedBox(
      height: 74,
      child: filled
          ? FilledButton(onPressed: _busy ? null : onTap, child: child)
          : OutlinedButton(onPressed: _busy ? null : onTap, child: child),
    );
  }
}

class _ReceiptField {
  const _ReceiptField(this.label, this.value, {this.isEmphasis = false});

  final String label;
  final String value;
  final bool isEmphasis;
}
