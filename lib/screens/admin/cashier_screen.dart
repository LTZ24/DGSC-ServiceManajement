import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/backend_service.dart';
import '../../services/backend_types.dart';
import '../../widgets/app_drawer.dart';
import 'ppob_receipt_preview_screen.dart';

class AdminCashierScreen extends StatefulWidget {
  const AdminCashierScreen({super.key});

  @override
  State<AdminCashierScreen> createState() => _AdminCashierScreenState();
}

class _AdminCashierScreenState extends State<AdminCashierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerSearchCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  DateTime _selectedDate = DateTime.now();
  String _paymentMethod = 'cash';

  List<Map<String, dynamic>> _spareParts = const [];
  List<Map<String, dynamic>> _customers = const [];
  List<Map<String, dynamic>> _services = const [];
  List<Map<String, dynamic>> _ppobTransactions = const [];
  List<_CashierLineItem> _lineItems = const [];

  Map<String, dynamic>? _selectedCustomer;
  Map<String, dynamic>? _selectedService;
  Map<String, dynamic>? _selectedPpobTransaction;
  Map<String, dynamic> _receiptSettings = const {};
  Map<String, dynamic> _printerSettings = const {};
  Map<String, dynamic> _storeSettings = const {};

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _customerSearchCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        BackendService.sparePartsStream().first,
        BackendService.customersStream().first,
        BackendService.servicesStream().first,
        BackendService.ppobTransactionsStream().first,
        BackendService.getPpobReceiptSettings(),
        BackendService.getPpobPrinterSettings(),
        BackendService.getStoreSettings(),
      ]);

      final sparePartsSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final customersSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final servicesSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final ppobSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _spareParts = sparePartsSnap.docs.map((doc) => doc.data()).toList();
        _customers = customersSnap.docs.map((doc) => doc.data()).toList();
        _services = servicesSnap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .take(80)
            .toList();
        _ppobTransactions = ppobSnap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .take(80)
            .toList();
        _receiptSettings = results[4] as Map<String, dynamic>;
        _printerSettings = results[5] as Map<String, dynamic>;
        _storeSettings = (results[6] as Map<String, dynamic>?) ?? const {};
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Iterable<Map<String, dynamic>> _customerMatches() {
    final query = _customerSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _customers.where((customer) {
      final name = (customer['name'] ?? '').toString().toLowerCase();
      final phone = (customer['phone'] ?? '').toString().toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).take(6);
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() => _selectedCustomer = customer);
    final name = (customer['name'] ?? '').toString();
    final phone = (customer['phone'] ?? '').toString();
    _customerSearchCtrl.text = phone.isEmpty ? name : '$name • $phone';
    _customerNameCtrl.text = name;
    _customerPhoneCtrl.text = phone;
  }

  void _applyCustomerFallback({String? name, String? phone}) {
    if (_customerNameCtrl.text.trim().isEmpty && (name ?? '').trim().isNotEmpty) {
      _customerNameCtrl.text = name!.trim();
    }
    if (_customerPhoneCtrl.text.trim().isEmpty && (phone ?? '').trim().isNotEmpty) {
      _customerPhoneCtrl.text = phone!.trim();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  double _serviceCharge() {
    final cost = _asDouble(_selectedService?['cost']);
    if (cost > 0) return cost;
    return _asDouble(_selectedService?['estimated_cost']);
  }

  double _ppobModal() => _asDouble(_selectedPpobTransaction?['modal_price']);
  double _ppobSelling() => _asDouble(_selectedPpobTransaction?['selling_price']);

  double _partsModal() =>
      _lineItems.fold<double>(0, (sum, item) => sum + item.totalModal);

  double _partsSelling() =>
      _lineItems.fold<double>(0, (sum, item) => sum + item.totalSelling);

  double _totalModal() => _partsModal() + _ppobModal();
  double _totalSelling() => _partsSelling() + _serviceCharge() + _ppobSelling();

  String _transactionTitle() {
    final sections = <String>[];
    if (_lineItems.isNotEmpty) {
      sections.add(
        context.tr(
          '${_lineItems.length} item spare part',
          '${_lineItems.length} spare part items',
        ),
      );
    }
    if (_selectedService != null) {
      sections.add(context.tr('Transaksi servis', 'Service transaction'));
    }
    if (_selectedPpobTransaction != null) {
      sections.add(context.tr('Lampiran PPOB', 'PPOB attachment'));
    }
    if (sections.isEmpty) {
      return context.tr('Transaksi Kasir', 'Cashier Transaction');
    }
    return sections.join(' + ');
  }

  List<Map<String, dynamic>> _buildReceiptLineItems() {
    return _lineItems
        .map(
          (item) => {
            'part_id': item.part['id'],
            'part_code': item.part['part_code'] ?? '',
            'part_name': item.part['part_name'] ?? '',
            'category': item.part['category'] ?? '',
            'qty': item.qty,
            'modal_price': item.modalPrice,
            'selling_price': item.sellingPrice,
            'total_modal': item.totalModal,
            'total_selling': item.totalSelling,
          },
        )
        .toList();
  }

  List<Map<String, String>> _buildReceiptExtraFields() {
    final fields = <Map<String, String>>[];
    if (_selectedService != null) {
      fields.add({
        'label': context.tr('Servis', 'Service'),
        'value':
            '${_selectedService?['service_code'] ?? '-'} • ${_selectedService?['device_brand'] ?? '-'} ${_selectedService?['model'] ?? ''}'.trim(),
      });
    }
    if (_selectedPpobTransaction != null) {
      fields.add({
        'label': 'PPOB',
        'value':
            '${_selectedPpobTransaction?['transaction_code'] ?? '-'} • ${_selectedPpobTransaction?['service_name'] ?? '-'}',
      });
    }
    return fields;
  }

  Future<void> _showAddItemSheet({_CashierLineItem? existing}) async {
    final qtyCtrl = TextEditingController(text: '${existing?.qty ?? 1}');
    final sellingCtrl = TextEditingController(
      text: existing == null ? '' : existing.sellingPrice.toStringAsFixed(0),
    );
    Map<String, dynamic>? selectedPart = existing?.part;

    final lineItem = await showModalBottomSheet<_CashierLineItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null
                      ? ctx.tr('Tambah Spare Part', 'Add Spare Part')
                      : ctx.tr('Edit Spare Part', 'Edit Spare Part'),
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedPart?['id']?.toString() ?? 'new_part'),
                  initialValue: selectedPart?['id']?.toString(),
                  decoration: InputDecoration(
                    labelText: ctx.tr('Pilih spare part', 'Choose spare part'),
                  ),
                  items: _spareParts
                      .map(
                        (part) => DropdownMenuItem<String>(
                          value: part['id']?.toString(),
                          child: Text(
                            '${part['part_name'] ?? '-'} • ${part['part_code'] ?? '-'} • ${ctx.tr('Stok', 'Stock')} ${part['stock_quantity'] ?? 0}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    selectedPart = _spareParts.firstWhere(
                      (part) => part['id']?.toString() == value,
                      orElse: () => <String, dynamic>{},
                    );
                    final unitPrice = _asDouble(selectedPart?['unit_price']);
                    if (sellingCtrl.text.trim().isEmpty || existing == null) {
                      sellingCtrl.text = unitPrice.toStringAsFixed(0);
                    }
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: ctx.tr('Qty', 'Qty'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: sellingCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: ctx.tr(
                            'Harga jual / unit',
                            'Selling price / unit',
                          ),
                          prefixText: 'Rp ',
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedPart != null && selectedPart!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${ctx.tr('Modal', 'Cost')}: ${_currencyFormat.format(_asDouble(selectedPart?['unit_price']))}\n'
                      '${ctx.tr('Kategori', 'Category')}: ${selectedPart?['category'] ?? '-'}',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    if (selectedPart == null || selectedPart!.isEmpty) return;
                    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                    final sellingPrice =
                        double.tryParse(sellingCtrl.text.trim()) ?? 0;
                    if (qty <= 0 || sellingPrice < 0) return;
                    Navigator.pop(
                      ctx,
                      _CashierLineItem(
                        part: selectedPart!,
                        qty: qty,
                        sellingPrice: sellingPrice,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(ctx.tr('Simpan Item', 'Save Item')),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    qtyCtrl.dispose();
    sellingCtrl.dispose();

    if (lineItem == null || !mounted) return;

    final availableStock =
        int.tryParse(lineItem.part['stock_quantity']?.toString() ?? '0') ?? 0;
    if (lineItem.qty > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Qty melebihi stok tersedia.',
              'Quantity exceeds available stock.',
            ),
          ),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    setState(() {
      final next = List<_CashierLineItem>.from(_lineItems);
      final index = next.indexWhere(
        (item) => item.part['id']?.toString() == lineItem.part['id']?.toString(),
      );
      if (index >= 0) {
        next[index] = lineItem;
      } else {
        next.add(lineItem);
      }
      _lineItems = next;
    });
  }

  void _removeLineItem(_CashierLineItem item) {
    setState(() {
      _lineItems = _lineItems
          .where((candidate) =>
              candidate.part['id']?.toString() != item.part['id']?.toString())
          .toList();
    });
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    if (_lineItems.isEmpty &&
        _selectedService == null &&
        _selectedPpobTransaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Tambahkan spare part atau lampirkan transaksi servis/PPOB terlebih dahulu.',
              'Add spare parts or attach a service/PPOB transaction first.',
            ),
          ),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Konfirmasi Transaksi', 'Confirm Transaction')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ctx.tr('Customer', 'Customer')}: ${_customerNameCtrl.text.trim().isEmpty ? '-' : _customerNameCtrl.text.trim()}',
            ),
            Text(
              '${ctx.tr('No. HP', 'Phone')}: ${_customerPhoneCtrl.text.trim().isEmpty ? '-' : _customerPhoneCtrl.text.trim()}',
            ),
            Text(
              '${ctx.tr('Total', 'Total')}: ${_currencyFormat.format(_totalSelling())}',
            ),
            Text(
              '${ctx.tr('Metode', 'Method')}: ${_paymentMethod.toUpperCase()}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('Simpan', 'Save')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final transactionCode = BackendService.generateCashierTransactionCode();
    final lineItems = _buildReceiptLineItems();
    final extraFields = _buildReceiptExtraFields();
    final now = DateTime.now();

    final transaction = {
      'transaction_code': transactionCode,
      'transaction_date': now,
      'category_name': 'Kasir',
      'product_name': _transactionTitle(),
      'customer_id': _selectedCustomer?['id'],
      'customer_name': _customerNameCtrl.text.trim(),
      'customer_phone': _customerPhoneCtrl.text.trim(),
      'customer_info': _customerNameCtrl.text.trim(),
      'service_id': _selectedService?['id'],
      'service_code': _selectedService?['service_code'] ?? '',
      'ppob_transaction_id': _selectedPpobTransaction?['id'],
      'ppob_transaction_code':
          _selectedPpobTransaction?['transaction_code'] ?? '',
      'line_items': lineItems,
      'modal_price': _totalModal(),
      'selling_price': _totalSelling(),
      'payment_method': _paymentMethod,
      'notes': _notesCtrl.text.trim(),
      'created_by': BackendService.currentUser?.uid,
      'created_by_name': BackendService.currentUser?.displayName ??
          BackendService.currentUser?.email ??
          'Admin',
      'receipt_payload': {
        'target_label': context.tr('No. HP', 'Phone'),
        'customer_label': context.tr('Customer', 'Customer'),
        'line_items': lineItems,
        'extra_fields': extraFields,
      },
    };

    setState(() => _saving = true);
    try {
      await BackendService.addCashierTransaction(transaction);
      if (!mounted) return;

      final receiptTransaction = {
        ...transaction,
        'transaction_date': now.toIso8601String(),
        'provider_app_name': context.tr('Kasir', 'Cashier'),
        'service_name': _transactionTitle(),
        'target_number': _customerPhoneCtrl.text.trim(),
        'profit': _totalSelling() - _totalModal(),
      };

      _resetForm();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PpobReceiptPreviewScreen(
            transaction: receiptTransaction,
            receiptSettings: _receiptSettings,
            storeSettings: _storeSettings,
            printerSettings: _printerSettings,
          ),
        ),
      );
      await _prepare();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Transaksi kasir berhasil disimpan.',
              'Cashier transaction saved successfully.',
            ),
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForm() {
    _customerSearchCtrl.clear();
    _customerNameCtrl.clear();
    _customerPhoneCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _selectedCustomer = null;
      _selectedService = null;
      _selectedPpobTransaction = null;
      _lineItems = const [];
      _paymentMethod = 'cash';
    });
  }

  String _formatDate(DateTime value) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(value);
  }

  String _customerSummary(Map<String, dynamic> data) {
    final customerName = (data['customer_name'] ?? data['customer_info'] ?? '')
        .toString()
        .trim();
    final customerPhone = (data['customer_phone'] ?? '').toString().trim();
    if (customerName.isEmpty && customerPhone.isEmpty) return '-';
    if (customerName.isEmpty) return customerPhone;
    if (customerPhone.isEmpty) return customerName;
    return '$customerName • $customerPhone';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Kasir', 'Cashier')),
        actions: [
          IconButton(
            onPressed: _prepare,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.tr('Refresh', 'Refresh'),
          ),
        ],
      ),
      drawer: const AppDrawer(isAdmin: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 56),
                        const SizedBox(height: 12),
                        Text(
                          context.tr(
                            'Data kasir gagal dimuat',
                            'Failed to load cashier data',
                          ),
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
                )
              : RefreshIndicator(
                  onRefresh: _prepare,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: BackendService.cashierTransactionsStream(
                      date: _selectedDate,
                    ),
                    builder: (context, snapshot) {
                      final transactions = (snapshot.data?.docs ?? const [])
                          .map((doc) => {'id': doc.id, ...doc.data()})
                          .toList();
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildHeaderCard(),
                          const SizedBox(height: 16),
                          _buildCustomerCard(),
                          const SizedBox(height: 16),
                          _buildAttachmentCard(),
                          const SizedBox(height: 16),
                          _buildSparePartCard(),
                          const SizedBox(height: 16),
                          _buildPaymentCard(),
                          const SizedBox(height: 16),
                          _buildSummaryCard(),
                          const SizedBox(height: 16),
                          _buildSubmitButton(),
                          const SizedBox(height: 20),
                          _buildHistoryCard(transactions),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Transaksi Kasir', 'Cashier Transaction'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                      'Spare part sebagai transaksi utama, dengan opsi lampiran servis dan PPOB.',
                      'Spare parts as the main transaction, with optional service and PPOB attachments.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(_formatDate(_selectedDate)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    final matches = _customerMatches().toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Customer', 'Customer'),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerSearchCtrl,
                decoration: InputDecoration(
                  labelText: context.tr(
                    'Cari data customer (nama / no. telp)',
                    'Find customer data (name / phone)',
                  ),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (_) => setState(() => _selectedCustomer = null),
              ),
              if (matches.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: matches
                        .map(
                          (customer) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_outline),
                            title: Text((customer['name'] ?? '-').toString()),
                            subtitle: Text((customer['phone'] ?? '-').toString()),
                            onTap: () => _selectCustomer(customer),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerNameCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Nama customer', 'Customer name'),
                ),
                validator: (value) => value?.trim().isEmpty == true
                    ? context.tr(
                        'Nama customer wajib diisi',
                        'Customer name is required',
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: context.tr('No. telepon', 'Phone number'),
                ),
                validator: (value) => value?.trim().isEmpty == true
                    ? context.tr(
                        'No. telepon wajib diisi',
                        'Phone number is required',
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Lampiran Transaksi', 'Transaction Attachments'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedService?['id']?.toString() ?? 'service_none'),
              initialValue: _selectedService?['id']?.toString(),
              decoration: InputDecoration(
                labelText: context.tr(
                  'Attach transaksi servis',
                  'Attach service transaction',
                ),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(context.tr('Tanpa servis', 'No service')),
                ),
                ..._services.map(
                  (service) => DropdownMenuItem<String>(
                    value: service['id']?.toString(),
                    child: Text(
                      '${service['service_code'] ?? '-'} • ${service['customer_name'] ?? '-'}',
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                Map<String, dynamic>? selected;
                for (final service in _services) {
                  if (service['id']?.toString() == value) {
                    selected = service;
                    break;
                  }
                }
                setState(() => _selectedService = selected);
                _applyCustomerFallback(
                  name: selected?['customer_name']?.toString(),
                  phone: selected?['customer_phone']?.toString(),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(
                _selectedPpobTransaction?['id']?.toString() ?? 'ppob_none',
              ),
              initialValue: _selectedPpobTransaction?['id']?.toString(),
              decoration: InputDecoration(
                labelText: context.tr(
                  'Attach transaksi PPOB',
                  'Attach PPOB transaction',
                ),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(context.tr('Tanpa PPOB', 'No PPOB')),
                ),
                ..._ppobTransactions.map(
                  (transaction) => DropdownMenuItem<String>(
                    value: transaction['id']?.toString(),
                    child: Text(
                      '${transaction['transaction_code'] ?? '-'} • ${transaction['service_name'] ?? '-'}',
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                Map<String, dynamic>? selected;
                for (final transaction in _ppobTransactions) {
                  if (transaction['id']?.toString() == value) {
                    selected = transaction;
                    break;
                  }
                }
                setState(() => _selectedPpobTransaction = selected);
                _applyCustomerFallback(
                  name: selected?['customer_info']?.toString(),
                  phone: selected?['target_number']?.toString(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSparePartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Spare Part', 'Spare Parts'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddItemSheet(),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('Tambah', 'Add')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_lineItems.isEmpty)
              Text(
                context.tr(
                  'Belum ada spare part yang ditambahkan.',
                  'No spare parts added yet.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Column(
                children: _lineItems
                    .map(
                      (item) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            '${item.part['part_name'] ?? '-'} • ${item.part['part_code'] ?? '-'}',
                          ),
                          subtitle: Text(
                            '${context.tr('Qty', 'Qty')} ${item.qty} • ${_currencyFormat.format(item.totalSelling)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _showAddItemSheet(existing: item),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => _removeLineItem(item),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppTheme.dangerColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Pembayaran', 'Payment'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_paymentMethod),
              initialValue: _paymentMethod,
              decoration: InputDecoration(
                labelText: context.tr('Metode pembayaran', 'Payment method'),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                DropdownMenuItem(value: 'qris', child: Text('QRIS')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _paymentMethod = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.tr('Catatan', 'Notes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalModal = _totalModal();
    final totalSelling = _totalSelling();
    final profit = totalSelling - totalModal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Ringkasan Transaksi', 'Transaction Summary'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _summaryRow(
              context.tr('Modal spare part', 'Spare part cost'),
              _currencyFormat.format(_partsModal()),
            ),
            _summaryRow(
              context.tr('Total spare part', 'Spare part total'),
              _currencyFormat.format(_partsSelling()),
            ),
            _summaryRow(
              context.tr('Lampiran servis', 'Service attachment'),
              _currencyFormat.format(_serviceCharge()),
            ),
            _summaryRow(
              context.tr('Lampiran PPOB', 'PPOB attachment'),
              _currencyFormat.format(_ppobSelling()),
            ),
            const Divider(height: 24),
            _summaryRow(
              context.tr('Total modal', 'Total cost'),
              _currencyFormat.format(totalModal),
              emphasize: true,
            ),
            _summaryRow(
              context.tr('Total transaksi', 'Transaction total'),
              _currencyFormat.format(totalSelling),
              emphasize: true,
            ),
            _summaryRow(
              context.tr('Profit', 'Profit'),
              _currencyFormat.format(profit),
              emphasize: true,
              accent: AppTheme.successColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool emphasize = false,
    Color? accent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton.icon(
      onPressed: _saving ? null : _submitTransaction,
      icon: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.receipt_long_outlined),
      label: Text(
        context.tr('Konfirmasi & Preview Struk', 'Confirm & Preview Receipt'),
      ),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildHistoryCard(List<Map<String, dynamic>> transactions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Riwayat Hari Ini', 'Today History'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              Text(
                context.tr(
                  'Belum ada transaksi kasir pada tanggal ini.',
                  'No cashier transactions for this date yet.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Column(
                children: transactions
                    .take(12)
                    .map(
                      (transaction) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x141D4ED8),
                          child: Icon(
                            Icons.point_of_sale_rounded,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(
                          (transaction['transaction_code'] ?? '-').toString(),
                        ),
                        subtitle: Text(
                          '${_customerSummary(transaction)}\n${transaction['product_name'] ?? '-'}',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          _currencyFormat.format(
                            _asDouble(transaction['selling_price']),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _CashierLineItem {
  const _CashierLineItem({
    required this.part,
    required this.qty,
    required this.sellingPrice,
  });

  final Map<String, dynamic> part;
  final int qty;
  final double sellingPrice;

  double get modalPrice {
    if (part['unit_price'] is num) return (part['unit_price'] as num).toDouble();
    return double.tryParse(part['unit_price']?.toString() ?? '0') ?? 0;
  }

  double get totalModal => modalPrice * qty;
  double get totalSelling => sellingPrice * qty;
}
