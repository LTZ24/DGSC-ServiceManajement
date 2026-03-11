import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import 'ppob_receipt_preview_screen.dart';
import '../../services/backend_service.dart';
import '../../services/backend_types.dart';
import '../../services/ppob_catalog_service.dart';
import '../../services/ppob_print_service.dart';
import '../../widgets/app_drawer.dart';

class AdminCounterScreen extends StatefulWidget {
  const AdminCounterScreen({super.key});

  @override
  State<AdminCounterScreen> createState() => _AdminCounterScreenState();
}

class _AdminCounterScreenState extends State<AdminCounterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _targetCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _tokenIdCtrl = TextEditingController();
  final _modalCtrl = TextEditingController();
  final _sellingCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController();
  final _closingBalanceCtrl = TextEditingController();
  final _balanceNotesCtrl = TextEditingController();

  bool _loading = true;
  bool _savingTransaction = false;
  bool _savingBalance = false;
  String? _loadError;

  List<Map<String, dynamic>> _apps = const [];
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _services = const [];

  Map<String, dynamic>? _selectedApp;
  Map<String, dynamic>? _selectedCategory;
  Map<String, dynamic>? _selectedService;
  Map<String, dynamic>? _dailyBalance;
  Map<String, dynamic> _printerSettings = const {};
  Map<String, dynamic> _receiptSettings = const {};
  Map<String, dynamic> _storeSettings = const {};

  DateTime _selectedDate = DateTime.now();
  DateTime _transactionDate = DateTime.now();
  String _paymentMethod = 'cash';
  String? _manualTransactionType;

  String? _reportAppId;
  String? _reportCategoryId;
  DateTime _reportStartDate = DateTime.now();
  DateTime _reportEndDate = DateTime.now();
  Future<List<Map<String, dynamic>>>? _reportFuture;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _customerCtrl.dispose();
    _tokenIdCtrl.dispose();
    _modalCtrl.dispose();
    _sellingCtrl.dispose();
    _notesCtrl.dispose();
    _openingBalanceCtrl.dispose();
    _closingBalanceCtrl.dispose();
    _balanceNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _primeLocalCatalog() async {
    try {
      final localApps = await PpobCatalogService.loadDefaultApps();
      final localCategories = await PpobCatalogService.loadDefaultCategories();
      final localServices = _flattenLocalServices(localCategories);
      final selectedApp = localApps.isEmpty ? null : _selectedApp ?? localApps.first;
      final selectedCategory = localCategories.isEmpty
          ? null
          : _resolveCategory(localCategories, _selectedCategory?['id_kategori']) ??
              localCategories.first;
      final selectedService = selectedCategory == null
          ? null
          : _resolveService(
                localServices,
                _selectedService?['id_layanan'],
                selectedCategory['id_kategori']?.toString(),
              ) ??
              _servicesForCategory(
                localServices,
                selectedCategory['id_kategori']?.toString(),
              ).firstOrNull;

      if (!mounted) return;
      setState(() {
        if (_apps.isEmpty) {
          _apps = localApps;
        }
        _categories = localCategories;
        _services = localServices;
        _selectedApp = _selectedApp ?? selectedApp;
        _selectedCategory = selectedCategory;
        _selectedService = selectedService;
        _reportAppId = _reportAppId ?? selectedApp?['id_aplikasi']?.toString();
      });
    } catch (_) {
      // Ignore local fallback issues and continue with remote loading.
    }
  }

  List<Map<String, dynamic>> _flattenLocalServices(
    List<Map<String, dynamic>> categories,
  ) {
    return categories
        .expand((category) {
          final categoryId = category['id_kategori']?.toString();
          final services = (category['layanan'] as List?) ?? const [];
          return services.map((service) {
            final item = Map<String, dynamic>.from(service as Map);
            return {
              'id_layanan': item['id_layanan'],
              'category_id': categoryId,
              'nama_layanan': item['nama'] ?? '',
              'tipe_override': item['tipe_override'],
            };
          });
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }

  String _targetInputLabel() {
    switch (PpobPrintService.receiptTargetLabel({
      'category_id': _selectedCategory?['id_kategori'],
      'category_name': _selectedCategory?['nama_kategori'],
      'service_id': _selectedService?['id_layanan'],
      'service_name': _selectedService?['nama_layanan'],
      'transaction_type': _currentTransactionType(),
    })) {
      case 'No Rek':
        return context.tr('No. rekening', 'Account number');
      case 'No VA':
        return context.tr('No. virtual account', 'VA number');
      case 'ID':
        return context.tr('ID pelanggan / billing', 'Customer / billing ID');
      default:
        return context.tr('No. telepon', 'Phone number');
    }
  }

  Widget _dropdownText(String text, {bool emphasized = false}) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: emphasized ? FontWeight.w600 : null,
      ),
    );
  }

  Future<void> _prepare() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    await _primeLocalCatalog();
    try {
      await BackendService.ensurePpobMasterData();

      final appSnap = await BackendService.ppobAppsStream().first;
      final printerSettings = await BackendService.getPpobPrinterSettings();
      final receiptSettings = await BackendService.getPpobReceiptSettings();
      final storeSettings = await BackendService.getStoreSettings() ?? {};

      final apps = appSnap.docs.map((doc) => doc.data()).toList();
      final selectedApp = apps.isEmpty ? null : _selectedApp ?? apps.first;

      if (!mounted) return;
      setState(() {
        _apps = apps;
        _selectedApp = selectedApp;
        _printerSettings = printerSettings;
        _receiptSettings = receiptSettings;
        _storeSettings = storeSettings;
        _reportAppId = _reportAppId ?? selectedApp?['id_aplikasi']?.toString();
        _loading = false;
      });

      _loadCatalogOptions();
      await _loadDailyBalance();
      _reloadReport();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _loadCatalogOptions() async {
    try {
      final categorySnap = await BackendService.ppobCategoriesStream().first;
      final serviceSnap = await BackendService.ppobServicesStream().first;

      final categories = categorySnap.docs.map((doc) => doc.data()).toList();
      final services = serviceSnap.docs.map((doc) => doc.data()).toList();
      final selectedCategory = categories.isEmpty
          ? null
          : _resolveCategory(categories, _selectedCategory?['id_kategori']) ??
              categories.first;
      final selectedService = selectedCategory == null
          ? null
          : _resolveService(
                services,
                _selectedService?['id_layanan'],
                selectedCategory['id_kategori']?.toString(),
              ) ??
              _servicesForCategory(
                services,
                selectedCategory['id_kategori']?.toString(),
              ).firstOrNull;

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _services = services;
        _selectedCategory = selectedCategory;
        _selectedService = selectedService;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  Map<String, dynamic>? _resolveCategory(
    List<Map<String, dynamic>> categories,
    String? id,
  ) {
    for (final item in categories) {
      if (item['id_kategori']?.toString() == id) return item;
    }
    return null;
  }

  Map<String, dynamic>? _resolveService(
    List<Map<String, dynamic>> services,
    String? id,
    String? categoryId,
  ) {
    for (final item in services) {
      if (id != null && item['id_layanan']?.toString() == id) return item;
    }
    final filtered = _servicesForCategory(services, categoryId);
    return filtered.isEmpty ? null : filtered.first;
  }

  List<Map<String, dynamic>> _servicesForCategory(
    List<Map<String, dynamic>> services,
    String? categoryId,
  ) {
    return services
        .where((item) => item['category_id']?.toString() == categoryId)
        .toList();
  }

  List<Map<String, dynamic>> _filteredServices() {
    return _servicesForCategory(
      _services,
      _selectedCategory?['id_kategori']?.toString(),
    );
  }

  double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _currentTransactionType() {
    final serviceOverride =
        (_selectedService?['tipe_override'] ?? '').toString();
    if (serviceOverride.isNotEmpty) return serviceOverride;
    final categoryType =
        (_selectedCategory?['tipe_transaksi'] ?? '').toString();
    if (categoryType.isNotEmpty) return categoryType;
    return _manualTransactionType ?? 'prabayar';
  }

  bool get _requiresTokenCustomerId =>
      _selectedService?['id_layanan']?.toString() == 'ut_pln_token';

  Future<void> _loadDailyBalance() async {
    final appId = _selectedApp?['id_aplikasi']?.toString() ?? '';
    if (appId.isEmpty) return;
    final balance = await BackendService.getOrCreatePpobDailyBalance(
      appId,
      _selectedDate,
      createdBy: BackendService.currentUser?.uid,
    );
    if (!mounted) return;
    setState(() {
      _dailyBalance = balance;
      _openingBalanceCtrl.text =
          _doubleValue(balance['opening_balance']).toStringAsFixed(0);
      _closingBalanceCtrl.text =
          _doubleValue(balance['closing_balance']).toStringAsFixed(0);
      _balanceNotesCtrl.text = (balance['notes'] ?? '').toString();
    });
  }

  Future<void> _pickTransactionDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transactionDate),
    );
    if (!mounted) return;
    setState(() {
      _transactionDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _transactionDate.hour,
        time?.minute ?? _transactionDate.minute,
      );
    });
  }

  Future<void> _pickSelectedDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(() => _selectedDate = date);
    await _loadDailyBalance();
  }

  Future<void> _pickReportDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: _reportStartDate,
        end: _reportEndDate,
      ),
    );
    if (range == null || !mounted) return;
    final days = range.end.difference(range.start).inDays;
    if (days > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Rentang laporan maksimal 30 hari.',
              'Report range is limited to 30 days.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _reportStartDate = range.start;
      _reportEndDate = range.end;
    });
    _reloadReport();
  }

  Future<void> _saveDailyBalance() async {
    if (_selectedApp == null) return;
    setState(() => _savingBalance = true);
    try {
      await BackendService.savePpobDailyBalance(
        appId: _selectedApp!['id_aplikasi'].toString(),
        date: _selectedDate,
        openingBalance: _doubleValue(_openingBalanceCtrl.text),
        closingBalance: _doubleValue(_closingBalanceCtrl.text),
        notes: _balanceNotesCtrl.text.trim(),
        createdBy: BackendService.currentUser?.uid,
      );
      await _loadDailyBalance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Saldo harian disimpan.', 'Daily balance saved.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _savingBalance = false);
    }
  }

  String _buildTransactionCode() {
    final appId = (_selectedApp?['id_aplikasi'] ?? 'ppob').toString();
    final compact = appId
        .replaceAll('app_', '')
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'TRX-$compact-$stamp';
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate() || _selectedApp == null) return;
    setState(() => _savingTransaction = true);
    try {
      final transactionCode = _buildTransactionCode();
      final transaction = {
        'transaction_code': transactionCode,
        'provider_app_id': _selectedApp!['id_aplikasi'],
        'provider_app_name': _selectedApp!['nama_aplikasi'],
        'category_id': _selectedCategory?['id_kategori'] ?? '',
        'category_name': _selectedCategory?['nama_kategori'] ?? '',
        'service_id': _selectedService?['id_layanan'] ?? '',
        'service_name': _selectedService?['nama_layanan'] ?? '',
        'transaction_type': _currentTransactionType(),
        'customer_info': _customerCtrl.text.trim(),
        'target_number': _targetCtrl.text.trim(),
        'token_customer_id': _tokenIdCtrl.text.trim(),
        'modal_price': _doubleValue(_modalCtrl.text),
        'selling_price': _doubleValue(_sellingCtrl.text),
        'payment_method': _paymentMethod,
        'notes': _notesCtrl.text.trim(),
        'transaction_date': _transactionDate,
        'created_by': BackendService.currentUser?.uid,
        'created_by_name': BackendService.currentUser?.displayName ??
            BackendService.currentUser?.email ??
            'Admin',
        'receipt_payload': {
          'target_number': _targetCtrl.text.trim(),
          'customer_info': _customerCtrl.text.trim(),
          'target_label': PpobPrintService.receiptTargetLabel({
            'category_id': _selectedCategory?['id_kategori'],
            'category_name': _selectedCategory?['nama_kategori'],
            'service_id': _selectedService?['id_layanan'],
            'service_name': _selectedService?['nama_layanan'],
            'transaction_type': _currentTransactionType(),
          }),
          'customer_label': 'Nama',
        },
      };
      await BackendService.addPpobTransaction(transaction);
      final receiptTransaction = {
        ...transaction,
        'profit':
            _doubleValue(_sellingCtrl.text) - _doubleValue(_modalCtrl.text),
      };
      if (!mounted) return;
      _resetForm();
      await _showReceiptPreview(receiptTransaction);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Transaksi PPOB berhasil disimpan.',
              'PPOB transaction saved.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _savingTransaction = false);
    }
  }

  void _resetForm() {
    _targetCtrl.clear();
    _customerCtrl.clear();
    _tokenIdCtrl.clear();
    _modalCtrl.clear();
    _sellingCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _paymentMethod = 'cash';
      _transactionDate = DateTime.now();
    });
  }

  Future<void> _showReceiptPreview(Map<String, dynamic> transaction) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PpobReceiptPreviewScreen(
          transaction: transaction,
          receiptSettings: _receiptSettings,
          storeSettings: _storeSettings,
          printerSettings: _printerSettings,
        ),
      ),
    );
  }

  String _transactionTypeLabel(String type) {
    switch (type) {
      case 'prabayar':
        return context.tr('Prabayar', 'Prepaid');
      case 'pascabayar':
        return context.tr('Pascabayar', 'Postpaid');
      case 'pembayaran_kode':
        return context.tr('Pembayaran kode', 'Code payment');
      case 'pemesanan':
        return context.tr('Pemesanan', 'Booking order');
      case 'transaksi_agen':
        return context.tr('Transaksi agen', 'Agent transaction');
      default:
        return type;
    }
  }

  Future<void> _showTransactionDetails(Map<String, dynamic> transaction) async {
    final rawDate = transaction['transaction_date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    final modal = _doubleValue(transaction['modal_price']);
    final selling = _doubleValue(transaction['selling_price']);
    final profit = _doubleValue(transaction['profit']);
    final targetLabel = PpobPrintService.receiptTargetLabel(transaction);
    final customerLabel = PpobPrintService.receiptCustomerLabel(transaction);
    final fields = <MapEntry<String, String>>[
      MapEntry(context.tr('Kategori', 'Category'),
          (transaction['category_name'] ?? '-').toString()),
      MapEntry(context.tr('Nama Produk', 'Product name'),
          (transaction['service_name'] ?? '-').toString()),
      MapEntry(context.tr('Jumlah Nominal', 'Amount'),
          _currencyFormat.format(modal)),
      MapEntry(context.tr('Biaya Admin', 'Admin fee'),
          _currencyFormat.format(profit < 0 ? 0 : profit)),
      MapEntry(context.tr('Total Harga', 'Total price'),
          _currencyFormat.format(selling)),
      if ((transaction['target_number'] ?? '').toString().isNotEmpty)
        MapEntry(targetLabel,
            transaction['target_number'].toString()),
      if ((transaction['customer_info'] ?? '').toString().isNotEmpty)
        MapEntry(customerLabel,
            transaction['customer_info'].toString()),
      if ((transaction['token_customer_id'] ?? '').toString().isNotEmpty)
        MapEntry(context.tr('ID Token', 'Token ID'),
            transaction['token_customer_id'].toString()),
      MapEntry(context.tr('Metode Pembayaran', 'Payment method'),
          (transaction['payment_method'] ?? '-').toString().toUpperCase()),
      MapEntry(context.tr('No. Pesanan', 'Order number'),
          (transaction['transaction_code'] ?? '-').toString()),
      MapEntry(context.tr('Waktu dibuat', 'Created at'), _formatDateTime(date)),
      MapEntry(context.tr('Username Staf', 'Staff username'),
          (transaction['created_by_name'] ?? 'Admin').toString()),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction['service_name']?.toString() ?? '-',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${transaction['target_number'] ?? '-'} • ${_currencyFormat.format(selling)}',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: fields
                          .map(
                            (field) => ListTile(
                              dense: true,
                              title: Text(field.key),
                              trailing: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  field.value,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showReceiptPreview(transaction);
                      },
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(context.tr('Lihat Struk', 'View Receipt')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _deleteTransactionWithPassword(transaction),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.tr('Hapus', 'Delete')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTransactionWithPassword(
    Map<String, dynamic> transaction,
  ) async {
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Konfirmasi Hapus', 'Confirm Deletion')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.tr('Password admin', 'Admin password'),
            ),
            validator: (value) => value == null || value.isEmpty
                ? context.tr('Wajib diisi', 'Required')
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, true);
            },
            child: Text(context.tr('Hapus', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await BackendService.deletePpobTransactionSecure(
        transaction['id'].toString(),
        adminPassword: passwordCtrl.text,
      );
      await _loadDailyBalance();
      _reloadReport();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Transaksi berhasil dihapus.',
                'Transaction deleted successfully.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      passwordCtrl.dispose();
    }
  }

  void _reloadReport() {
    final appId = _reportAppId;
    if (appId == null || appId.isEmpty) return;
    setState(() {
      _reportFuture = BackendService.getPpobTransactionsReport(
        appId: appId,
        startDate: _reportStartDate,
        endDate: _reportEndDate,
      );
    });
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(value);
  }

  String _formatDay(DateTime value) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('PPOB', 'PPOB')),
          actions: [
            IconButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/admin/ppob-settings');
                await _prepare();
              },
              icon: const Icon(Icons.settings_outlined),
              tooltip: context.tr('Pengaturan PPOB', 'PPOB Settings'),
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.72),
            tabs: [
              Tab(text: context.tr('Transaksi', 'Transactions')),
              Tab(text: context.tr('Laporan', 'Reports')),
            ],
          ),
        ),
        drawer: const AppDrawer(isAdmin: true),
        body: Column(
          children: [
            _buildAppSelector(),
            Expanded(
              child: _loadError != null
                  ? _buildLoadError()
                  : TabBarView(
                      children: [
                        _buildTransactionsTab(),
                        _buildReportsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56),
            const SizedBox(height: 12),
            Text(
              context.tr('Data PPOB gagal dimuat', 'Failed to load PPOB data'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? '-',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _prepare,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('Coba Lagi', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Pilih aplikasi PPOB', 'Choose PPOB app'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (_loading && _apps.isEmpty)
            const LinearProgressIndicator()
          else if (_apps.isEmpty)
            Text(
              context.tr(
                'Belum ada aplikasi PPOB aktif.',
                'No active PPOB apps yet.',
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _apps.map((app) {
                  final selected = app['id_aplikasi']?.toString() ==
                      _selectedApp?['id_aplikasi'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: selected,
                      label: Text(app['nama_aplikasi']?.toString() ?? '-'),
                      avatar: Icon(
                        Icons.apps_rounded,
                        size: 18,
                        color: selected ? Colors.white : AppTheme.primaryColor,
                      ),
                      onSelected: (_) async {
                        setState(() {
                          _selectedApp = app;
                          _reportAppId = app['id_aplikasi']?.toString();
                        });
                        await _loadDailyBalance();
                        _reloadReport();
                      },
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_selectedApp == null) {
      return Center(
        child: Text(
          context.tr('Pilih aplikasi PPOB terlebih dahulu.',
              'Choose a PPOB app first.'),
        ),
      );
    }
    final appId = _selectedApp?['id_aplikasi']?.toString();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appId == null || appId.isEmpty
          ? const Stream.empty()
          : BackendService.ppobTransactionsStream(
              appId: appId,
              date: _selectedDate,
            ),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final transactions = docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
        final totalModal = transactions.fold<double>(
          0,
          (sum, item) => sum + _doubleValue(item['modal_price']),
        );
        final totalRevenue = transactions.fold<double>(
          0,
          (sum, item) => sum + _doubleValue(item['selling_price']),
        );
        final totalProfit = transactions.fold<double>(
          0,
          (sum, item) => sum + _doubleValue(item['profit']),
        );

        return RefreshIndicator(
          onRefresh: _prepare,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDailyBalanceCard(
                transactionCount: transactions.length,
                totalModal: totalModal,
                totalRevenue: totalRevenue,
                totalProfit: totalProfit,
              ),
              const SizedBox(height: 16),
              _buildTransactionFormCard(),
              const SizedBox(height: 16),
              _buildTransactionListCard(transactions),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyBalanceCard({
    required int transactionCount,
    required double totalModal,
    required double totalRevenue,
    required double totalProfit,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Saldo Harian', 'Daily Balance'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedApp?['nama_aplikasi'] ?? '-'} • ${_formatDay(_selectedDate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickSelectedDate,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text(context.tr('Ubah Hari', 'Change Day')),
                ),
              ],
            ),
            if (_dailyBalance != null) ...[
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Saldo akhir hari ini akan diteruskan sebagai saldo awal hari berikutnya sampai diubah manual.',
                  'Today closing balance will continue as the next day opening balance until manually edited.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _moneyField(
                    controller: _openingBalanceCtrl,
                    label: context.tr('Saldo awal', 'Opening balance'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _moneyField(
                    controller: _closingBalanceCtrl,
                    label: context.tr('Saldo akhir', 'Closing balance'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _balanceNotesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.tr('Catatan saldo', 'Balance notes'),
                hintText: context.tr(
                  'Saldo akhir akan menjadi saldo awal hari berikutnya jika belum diubah manual.',
                  'Closing balance becomes the next day opening balance until manually changed.',
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildMetricGrid(
              items: [
                _MetricItem(
                  context.tr('Transaksi', 'Transactions'),
                  transactionCount.toString(),
                  Icons.receipt_long_rounded,
                ),
                _MetricItem(
                  context.tr('Modal', 'Capital'),
                  _currencyFormat.format(totalModal),
                  Icons.inventory_2_outlined,
                ),
                _MetricItem(
                  context.tr('Omzet', 'Revenue'),
                  _currencyFormat.format(totalRevenue),
                  Icons.account_balance_wallet_outlined,
                ),
                _MetricItem(
                  context.tr('Laba', 'Profit'),
                  _currencyFormat.format(totalProfit),
                  Icons.trending_up_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _savingBalance ? null : _saveDailyBalance,
              icon: _savingBalance
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(context.tr('Simpan Saldo', 'Save Balance')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionFormCard() {
    if (_categories.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr(
                    'Kategori dan provider transaksi sedang dimuat.',
                    'Transaction categories and providers are loading.',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final filteredServices = _filteredServices();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Input Transaksi PPOB', 'PPOB Transaction Entry'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _readonlyInfo(
                    context.tr('Aplikasi', 'App'),
                    '${_selectedApp?['nama_aplikasi'] ?? '-'} • ${_selectedApp?['jenis_layanan'] ?? '-'}',
                  ),
                  const SizedBox(height: 12),
                  if (compact) ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      menuMaxHeight: 360,
                      initialValue: _selectedCategory?['id_kategori']?.toString(),
                      decoration: InputDecoration(
                        labelText: context.tr('Kategori', 'Category'),
                        isDense: true,
                      ),
                      items: _categories
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item['id_kategori']?.toString(),
                              child: _dropdownText(
                                item['nama_kategori']?.toString() ?? '',
                              ),
                            ),
                          )
                          .toList(),
                      selectedItemBuilder: (context) => _categories
                          .map(
                            (item) => Align(
                              alignment: Alignment.centerLeft,
                              child: _dropdownText(
                                item['nama_kategori']?.toString() ?? '',
                                emphasized: true,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        final category = _resolveCategory(_categories, value);
                        final nextServices = _servicesForCategory(_services, value);
                        setState(() {
                          _selectedCategory = category;
                          _selectedService =
                              nextServices.isEmpty ? null : nextServices.first;
                          _manualTransactionType =
                              category?['tipe_transaksi']?.toString();
                        });
                      },
                      validator: (value) => value == null || value.isEmpty
                          ? context.tr('Wajib dipilih', 'Required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      menuMaxHeight: 320,
                      initialValue: _currentTransactionType(),
                      decoration: InputDecoration(
                        labelText: context.tr('Jenis transaksi', 'Transaction type'),
                        isDense: true,
                      ),
                      items: const [
                        'prabayar',
                        'pascabayar',
                        'pembayaran_kode',
                        'pemesanan',
                        'transaksi_agen',
                      ]
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: _dropdownText(_transactionTypeLabel(item)),
                            ),
                          )
                          .toList(),
                      selectedItemBuilder: (context) => const [
                        'prabayar',
                        'pascabayar',
                        'pembayaran_kode',
                        'pemesanan',
                        'transaksi_agen',
                      ]
                          .map(
                            (item) => Align(
                              alignment: Alignment.centerLeft,
                              child: _dropdownText(
                                _transactionTypeLabel(item),
                                emphasized: true,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _manualTransactionType = value);
                      },
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            menuMaxHeight: 360,
                            initialValue: _selectedCategory?['id_kategori']?.toString(),
                            decoration: InputDecoration(
                              labelText: context.tr('Kategori', 'Category'),
                              isDense: true,
                            ),
                            items: _categories
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item['id_kategori']?.toString(),
                                    child: _dropdownText(
                                      item['nama_kategori']?.toString() ?? '',
                                    ),
                                  ),
                                )
                                .toList(),
                            selectedItemBuilder: (context) => _categories
                                .map(
                                  (item) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: _dropdownText(
                                      item['nama_kategori']?.toString() ?? '',
                                      emphasized: true,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              final category = _resolveCategory(_categories, value);
                              final nextServices =
                                  _servicesForCategory(_services, value);
                              setState(() {
                                _selectedCategory = category;
                                _selectedService = nextServices.isEmpty
                                    ? null
                                    : nextServices.first;
                                _manualTransactionType =
                                    category?['tipe_transaksi']?.toString();
                              });
                            },
                            validator: (value) => value == null || value.isEmpty
                                ? context.tr('Wajib dipilih', 'Required')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            menuMaxHeight: 320,
                            initialValue: _currentTransactionType(),
                            decoration: InputDecoration(
                              labelText: context.tr('Jenis transaksi', 'Transaction type'),
                              isDense: true,
                            ),
                            items: const [
                              'prabayar',
                              'pascabayar',
                              'pembayaran_kode',
                              'pemesanan',
                              'transaksi_agen',
                            ]
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child:
                                        _dropdownText(_transactionTypeLabel(item)),
                                  ),
                                )
                                .toList(),
                            selectedItemBuilder: (context) => const [
                              'prabayar',
                              'pascabayar',
                              'pembayaran_kode',
                              'pemesanan',
                              'transaksi_agen',
                            ]
                                .map(
                                  (item) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: _dropdownText(
                                      _transactionTypeLabel(item),
                                      emphasized: true,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _manualTransactionType = value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 360,
                    initialValue: _selectedService?['id_layanan']?.toString(),
                    decoration: InputDecoration(
                      labelText: context.tr('Provider / transaksi', 'Provider / service'),
                      isDense: true,
                    ),
                    items: filteredServices
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item['id_layanan']?.toString(),
                            child: _dropdownText(
                              item['nama_layanan']?.toString() ?? '',
                            ),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) => filteredServices
                        .map(
                          (item) => Align(
                            alignment: Alignment.centerLeft,
                            child: _dropdownText(
                              item['nama_layanan']?.toString() ?? '',
                              emphasized: true,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(
                        () => _selectedService = _resolveService(
                          _services,
                          value,
                          _selectedCategory?['id_kategori']?.toString(),
                        ),
                      );
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? context.tr('Wajib dipilih', 'Required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickTransactionDate,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                      '${context.tr('Tanggal transaksi', 'Transaction date')}: ${_formatDateTime(_transactionDate)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (compact) ...[
                    TextFormField(
                      controller: _customerCtrl,
                      decoration: InputDecoration(
                        labelText: context.tr('Nama', 'Name'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _targetCtrl,
                      decoration: InputDecoration(
                        labelText: _targetInputLabel(),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? context.tr('Wajib diisi', 'Required')
                          : null,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _customerCtrl,
                            decoration: InputDecoration(
                              labelText: context.tr('Nama', 'Name'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _targetCtrl,
                            decoration: InputDecoration(
                              labelText: _targetInputLabel(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? context.tr('Wajib diisi', 'Required')
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_requiresTokenCustomerId) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tokenIdCtrl,
                      decoration: InputDecoration(
                        labelText: context.tr('ID token PLN', 'PLN token ID'),
                        hintText: context.tr(
                          'Khusus token listrik prabayar',
                          'Required for prepaid electricity token',
                        ),
                      ),
                      validator: (value) {
                        if (!_requiresTokenCustomerId) return null;
                        return value == null || value.trim().isEmpty
                            ? context.tr('Wajib diisi', 'Required')
                            : null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _moneyField(
                          controller: _modalCtrl,
                          label: context.tr('Harga modal', 'Capital price'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? context.tr('Wajib diisi', 'Required')
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _moneyField(
                          controller: _sellingCtrl,
                          label: context.tr('Harga jual', 'Selling price'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? context.tr('Wajib diisi', 'Required')
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: InputDecoration(
                      labelText: context.tr('Metode bayar', 'Payment method'),
                    ),
                    items: ['cash', 'transfer', 'qris']
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(item.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _paymentMethod = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: context.tr('Catatan', 'Notes'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _savingTransaction ? null : _submitTransaction,
                    icon: _savingTransaction
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      context.tr('Simpan & Cetak Struk', 'Save & Print Receipt'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionListCard(List<Map<String, dynamic>> transactions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                  'Riwayat transaksi harian', 'Daily transaction history'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              Text(
                context.tr(
                  'Belum ada transaksi untuk aplikasi dan tanggal ini.',
                  'No transactions found for this app and date.',
                ),
              )
            else
              ...transactions.map((item) => _buildTransactionTile(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportFuture,
      builder: (context, snapshot) {
        final allRows = snapshot.data ?? const <Map<String, dynamic>>[];
        final rows = allRows.where((item) {
          if (_reportCategoryId == null || _reportCategoryId!.isEmpty) {
            return true;
          }
          return item['category_id']?.toString() == _reportCategoryId;
        }).toList();
        final totalModal = rows.fold<double>(
          0,
          (sum, item) => sum + _doubleValue(item['modal_price']),
        );
        final totalRevenue = rows.fold<double>(
          0,
          (sum, item) => sum + _doubleValue(item['selling_price']),
        );
        final totalProfit = rows.fold<double>(
          0,
          (sum, item) => sum + _doubleValue(item['profit']),
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                          'Laporan Keuangan PPOB', 'PPOB Financial Report'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      menuMaxHeight: 320,
                      initialValue: _reportAppId,
                      decoration: InputDecoration(
                        labelText: context.tr('Aplikasi', 'App'),
                        isDense: true,
                      ),
                      items: _apps
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item['id_aplikasi']?.toString(),
                              child: _dropdownText(
                                item['nama_aplikasi']?.toString() ?? '',
                              ),
                            ),
                          )
                          .toList(),
                      selectedItemBuilder: (context) => _apps
                          .map(
                            (item) => Align(
                              alignment: Alignment.centerLeft,
                              child: _dropdownText(
                                item['nama_aplikasi']?.toString() ?? '',
                                emphasized: true,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _reportAppId = value);
                        _reloadReport();
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      menuMaxHeight: 320,
                      initialValue: _reportCategoryId,
                      decoration: InputDecoration(
                        labelText: context.tr('Kategori', 'Category'),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: _dropdownText(
                            context.tr('Semua kategori', 'All categories'),
                          ),
                        ),
                        ..._categories.map(
                          (item) => DropdownMenuItem<String>(
                            value: item['id_kategori']?.toString(),
                            child: _dropdownText(
                              item['nama_kategori']?.toString() ?? '',
                            ),
                          ),
                        ),
                      ],
                      selectedItemBuilder: (context) => [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _dropdownText(
                            context.tr('Semua kategori', 'All categories'),
                            emphasized: true,
                          ),
                        ),
                        ..._categories.map(
                          (item) => Align(
                            alignment: Alignment.centerLeft,
                            child: _dropdownText(
                              item['nama_kategori']?.toString() ?? '',
                              emphasized: true,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _reportCategoryId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickReportDateRange,
                          icon: const Icon(Icons.date_range_outlined),
                          label: Text(
                            '${_formatDay(_reportStartDate)} - ${_formatDay(_reportEndDate)}',
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            setState(() {
                              _reportStartDate = DateTime.now();
                              _reportEndDate = DateTime.now();
                            });
                            _reloadReport();
                          },
                          icon: const Icon(Icons.today_rounded),
                          label: Text(context.tr('1 Hari', '1 Day')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildReportSummaryGrid(
              totalTransactions: rows.length,
              totalModal: totalModal,
              totalRevenue: totalRevenue,
              totalProfit: totalProfit,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Daftar transaksi', 'Transaction list'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      Text(context.tr('Belum ada data.', 'No data yet.'))
                    else
                      ...rows.map(
                        (row) => _buildTransactionTile(row, compact: true),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, height: 1.2),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid({required List<_MetricItem> items}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _metricCard(item.title, item.value, item.icon);
      },
    );
  }

  Widget _buildReportSummaryGrid({
    required int totalTransactions,
    required double totalModal,
    required double totalRevenue,
    required double totalProfit,
  }) {
    return _buildMetricGrid(
      items: [
        _MetricItem(
          context.tr('Total Transaksi', 'Total Transactions'),
          totalTransactions.toString(),
          Icons.receipt_long,
        ),
        _MetricItem(
          context.tr('Total Modal', 'Total Capital'),
          _currencyFormat.format(totalModal),
          Icons.inventory_2_outlined,
        ),
        _MetricItem(
          context.tr('Total Omzet', 'Total Revenue'),
          _currencyFormat.format(totalRevenue),
          Icons.payments_outlined,
        ),
        _MetricItem(
          context.tr('Total Laba', 'Total Profit'),
          _currencyFormat.format(totalProfit),
          Icons.trending_up_rounded,
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
    Map<String, dynamic> item, {
    bool compact = false,
  }) {
    final rawDate = item['transaction_date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    final totalPay = _doubleValue(item['selling_price']);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showTransactionDetails(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['service_name']?.toString() ?? '-',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['target_number'] ?? '-'} • ${_formatDateTime(date)} • ${_currencyFormat.format(totalPay)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${item['transaction_code'] ?? '-'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'receipt') {
                  _showReceiptPreview(item);
                } else if (value == 'delete') {
                  _deleteTransactionWithPassword(item);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'receipt',
                  child: Text(context.tr('Lihat Struk', 'View Receipt')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.tr('Hapus', 'Delete')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        isDense: true,
      ),
      validator: validator,
    );
  }

  Widget _readonlyInfo(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

}

class _MetricItem {
  const _MetricItem(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

extension ListFirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
