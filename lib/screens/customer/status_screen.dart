import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/backend_types.dart';
import '../../services/backend_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/status_badge.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final String _uid;
  late final Stream<QuerySnapshot> _bookingsStream;
  late final Stream<QuerySnapshot> _servicesStream;
  Map<String, dynamic>? _storeSettings;
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _uid = BackendService.currentUser?.uid ?? '';
    _bookingsStream = BackendService.userBookingsStream(_uid);
    _servicesStream = BackendService.userServicesStream(_uid);
    _tabController = TabController(length: 2, vsync: this);
    _loadStoreSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreSettings() async {
    final settings = await BackendService.getStoreSettings();
    if (!mounted) return;
    setState(() => _storeSettings = settings);
  }

  Future<void> _selectPaymentMethod(
    Map<String, dynamic> serviceData,
    String serviceId,
    String method,
  ) async {
    final paymentLabel = _paymentLabel(method);
    final paymentLabelLower = paymentLabel.toLowerCase();
    final historyTitle =
        context.tr('Metode pembayaran dipilih', 'Payment method selected');
    final historyDescription = context.tr(
      'Customer memilih metode pembayaran $paymentLabelLower.',
      'Customer selected $paymentLabelLower as the payment method.',
    );
    final notifyTitle =
        context.tr('Pilihan pembayaran customer', 'Customer payment choice');
    final notifyMessage = context.tr(
      'Customer ${serviceData['customer_name'] ?? ''} memilih $paymentLabel untuk servis ${serviceData['service_code'] ?? ''}.',
      'Customer ${serviceData['customer_name'] ?? ''} selected $paymentLabel for service ${serviceData['service_code'] ?? ''}.',
    );
    final snackTitle = historyTitle;

    await BackendService.updateService(serviceId, {
      'payment_choice': method,
      'payment_method': method,
      'payment_status':
          method == 'cash_on_pickup' ? 'pending' : 'awaiting_confirmation',
    });
    await BackendService.appendServiceHistory(
      serviceId: serviceId,
      status: 'awaiting_confirmation',
      title: historyTitle,
      description: historyDescription,
      actor: 'customer',
      meta: {'payment_choice': method},
    );
    await BackendService.notifyAdmins(
      title: notifyTitle,
      message: notifyMessage,
      relatedId: serviceId,
      type: 'payment',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$snackTitle: $paymentLabel')),
    );
  }

  Future<void> _openWhatsApp(Map<String, dynamic> serviceData) async {
    final phone = _normalizeWhatsAppNumber(
      (_storeSettings?['whatsapp_phone'] ?? _storeSettings?['phone'] ?? '')
          .toString(),
    );
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr('Nomor WhatsApp admin belum diatur',
                'Admin WhatsApp number has not been set'))),
      );
      return;
    }

    final message = Uri.encodeComponent(
      context.tr(
          'Halo Admin, saya ingin konfirmasi pembayaran/pengambilan untuk servis ${serviceData['service_code'] ?? ''} (${serviceData['device_brand'] ?? ''} ${serviceData['model'] ?? ''}).',
          'Hello Admin, I want to confirm payment/pickup for service ${serviceData['service_code'] ?? ''} (${serviceData['device_brand'] ?? ''} ${serviceData['model'] ?? ''}).'),
    );
    final uri = Uri.parse('https://wa.me/$phone?text=$message');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr(
                'Gagal membuka WhatsApp', 'Failed to open WhatsApp'))),
      );
    }
  }

  String _normalizeWhatsAppNumber(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('62')) return digits;
    if (digits.startsWith('0')) return '62${digits.substring(1)}';
    return digits;
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'transfer':
        return context.tr('Transfer Bank', 'Bank Transfer');
      case 'qris':
        return 'QRIS';
      case 'cash_on_pickup':
        return context.tr('Bayar Saat Ambil', 'Pay on Pickup');
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Status Servis', 'Service Status')),
      ),
      drawer: const AppDrawer(isAdmin: false),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.accentColor.withValues(alpha: 0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.track_changes,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Pantau status secara real-time',
                                  'Track status in real-time'),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr(
                                  'Lihat perkembangan booking, servis, dan pembayaran dalam satu tampilan yang konsisten.',
                                  'View booking, service, and payment progress in one consistent screen.'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Theme.of(context).colorScheme.onSurface,
                    unselectedLabelColor: mutedColor,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                    unselectedLabelStyle:
                        const TextStyle(fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: context.tr('Booking', 'Bookings')),
                      Tab(text: context.tr('Servis', 'Services')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _bookingsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.calendar_today,
                        title:
                            context.tr('Belum ada booking', 'No bookings yet'),
                        description: context.tr(
                            'Booking baru akan muncul di sini setelah formulir servis dikirim.',
                            'New bookings will appear here after the service form is submitted.'),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final status = data['status'] ?? 'pending';
                        return AppListCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${data["device_type"] ?? ""} - ${data["brand"] ?? ""} ${data["model"] ?? ""}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    StatusBadge(status: status.toString()),
                                  ],
                                ),
                                if ((data['issue_description'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    data['issue_description'],
                                    style: TextStyle(
                                        fontSize: 13, color: mutedColor),
                                  ),
                                ],
                                if ((data['preferred_date'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          size: 14, color: mutedColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        data['preferred_date'],
                                        style: TextStyle(
                                            fontSize: 12, color: mutedColor),
                                      ),
                                    ],
                                  ),
                                ],
                                if ((data['diagnosis_result'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  const Divider(),
                                  Row(
                                    children: [
                                      const Icon(Icons.medical_services,
                                          size: 14, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          data['diagnosis_result'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.blue),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _servicesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.build, size: 64, color: mutedColor),
                            const SizedBox(height: 16),
                            Text(
                              context.tr('Belum ada servis', 'No services yet'),
                              style: TextStyle(color: mutedColor),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _loadStoreSettings,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final status =
                              (data['status'] ?? 'pending').toString();
                          final paymentChoice =
                              (data['payment_choice'] ?? '').toString();
                          final qrisBase64 =
                              (_storeSettings?['qris_image_base64'] ?? '')
                                  .toString();
                          final bankName =
                              (_storeSettings?['bank_name'] ?? '').toString();
                          final bankAccountNumber =
                              (_storeSettings?['bank_account_number'] ?? '')
                                  .toString();
                          final bankAccountName =
                              (_storeSettings?['bank_account_name'] ?? '')
                                  .toString();
                          final amount = (data['cost'] as num? ?? 0).toDouble();

                          return AppListCard(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                        child: const Icon(
                                          Icons.build,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${data["device_brand"] ?? ""} ${data["model"] ?? ""}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              data['service_code'] ?? '',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: mutedColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(status: status),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _infoRow(
                                    context,
                                    'Status',
                                    _statusDescription(context, status),
                                  ),
                                  if ((data['initial_detail'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    _infoRow(
                                      context,
                                      context.tr(
                                          'Detail proses', 'Process details'),
                                      data['initial_detail'],
                                    ),
                                  if ((data['service_detail'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    _infoRow(
                                      context,
                                      context.tr(
                                          'Detail servis', 'Service details'),
                                      data['service_detail'],
                                    ),
                                  if ((data['status_note'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    _infoRow(
                                      context,
                                      context.tr('Info admin', 'Admin info'),
                                      data['status_note'],
                                    ),
                                  if ((data['technician'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    _infoRow(
                                      context,
                                      context.tr('Teknisi', 'Technician'),
                                      data['technician'],
                                    ),
                                  if ((data['estimated_cost'] as num? ?? 0) > 0)
                                    _infoRow(
                                      context,
                                      context.tr('Estimasi', 'Estimate'),
                                      currencyFormat.format(
                                        (data['estimated_cost'] as num)
                                            .toDouble(),
                                      ),
                                    ),
                                  if (amount > 0)
                                    _infoRow(
                                      context,
                                      context.tr('Total final', 'Final total'),
                                      currencyFormat.format(amount),
                                    ),
                                  const SizedBox(height: 8),
                                  _buildTimelineSection(context, data),
                                  if (status == 'completed') ...[
                                    const Divider(height: 24),
                                    Text(
                                      context.tr('Pembayaran & Pengambilan',
                                          'Payment & Pickup'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: Text(context.tr(
                                              'Transfer', 'Transfer')),
                                          selected: paymentChoice == 'transfer',
                                          onSelected: (_) =>
                                              _selectPaymentMethod(
                                            data,
                                            doc.id,
                                            'transfer',
                                          ),
                                        ),
                                        ChoiceChip(
                                          label:
                                              Text(context.tr('QRIS', 'QRIS')),
                                          selected: paymentChoice == 'qris',
                                          onSelected: (_) =>
                                              _selectPaymentMethod(
                                            data,
                                            doc.id,
                                            'qris',
                                          ),
                                        ),
                                        ChoiceChip(
                                          label: Text(context.tr(
                                              'Bayar Saat Ambil',
                                              'Pay on Pickup')),
                                          selected:
                                              paymentChoice == 'cash_on_pickup',
                                          onSelected: (_) =>
                                              _selectPaymentMethod(
                                            data,
                                            doc.id,
                                            'cash_on_pickup',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (paymentChoice == 'transfer')
                                      _paymentBox(
                                        context,
                                        title: context.tr('Pembayaran Transfer',
                                            'Transfer Payment'),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _infoRow(
                                              context,
                                              context.tr('Bank', 'Bank'),
                                              bankName.isEmpty ? '-' : bankName,
                                            ),
                                            _infoRow(
                                              context,
                                              context.tr(
                                                  'No. Rek', 'Account No.'),
                                              bankAccountNumber.isEmpty
                                                  ? '-'
                                                  : bankAccountNumber,
                                            ),
                                            _infoRow(
                                              context,
                                              context.tr(
                                                  'Atas Nama', 'Account Name'),
                                              bankAccountName.isEmpty
                                                  ? '-'
                                                  : bankAccountName,
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (paymentChoice == 'qris')
                                      _paymentBox(
                                        context,
                                        title: context.tr(
                                            'Pembayaran QRIS', 'QRIS Payment'),
                                        child: qrisBase64.isEmpty
                                            ? Text(
                                                context.tr(
                                                    'QRIS toko belum diupload admin.',
                                                    'Store QRIS has not been uploaded by admin yet.'),
                                                style: TextStyle(
                                                    color: mutedColor),
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    child: Image.memory(
                                                      base64Decode(qrisBase64),
                                                      height: 220,
                                                      width: double.infinity,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    context.tr(
                                                        'Scan QRIS di atas lalu kirim konfirmasi ke admin.',
                                                        'Scan the QRIS above then send confirmation to admin.'),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: mutedColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    if (paymentChoice == 'cash_on_pickup')
                                      _paymentBox(
                                        context,
                                        title: context.tr(
                                            'Bayar Saat Pengambilan',
                                            'Pay on Pickup'),
                                        child: Text(
                                          context.tr(
                                              'Silakan lakukan pembayaran saat perangkat diambil di toko. Gunakan tombol WhatsApp untuk konfirmasi ke admin.',
                                              'Please make the payment when the device is picked up at the store. Use the WhatsApp button to confirm with the admin.'),
                                          style: TextStyle(color: mutedColor),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _openWhatsApp(data),
                                        icon: const Icon(Icons.chat),
                                        label: Text(context.tr(
                                            'Hubungi WhatsApp Admin',
                                            'Contact Admin WhatsApp')),
                                      ),
                                    ),
                                  ],
                                  if (status == 'sudah_diambil') ...[
                                    const Divider(height: 24),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppTheme.successColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            context.tr(
                                                'Perangkat sudah diambil. Pembayaran telah dicatat.',
                                                'The device has been picked up. Payment has been recorded.'),
                                            style: TextStyle(color: mutedColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentBox(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildTimelineSection(
      BuildContext context, Map<String, dynamic> data) {
    final timeline = _buildTimeline(context, data);
    if (timeline.isEmpty) return const SizedBox.shrink();

    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Timeline Servis', 'Service Timeline'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...timeline.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final createdAt = item['created_at'];
            final dateText = createdAt is Timestamp
                ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
                    .format(createdAt.toDate())
                : '-';
            final isLast = index == timeline.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            _timelineColor(item['status'].toString())
                                .withValues(alpha: 0.12),
                        child: Icon(
                          _timelineIcon(item['status'].toString()),
                          size: 14,
                          color: _timelineColor(item['status'].toString()),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _translateTimelineText(
                              context,
                              (item['title'] ?? '').toString(),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if ((item['description'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _translateTimelineText(
                                  context,
                                  item['description'].toString(),
                                ),
                                style:
                                    TextStyle(fontSize: 12, color: mutedColor),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            dateText,
                            style: TextStyle(fontSize: 11, color: mutedColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildTimeline(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final raw = data['status_history'];
    if (raw is List && raw.isNotEmpty) {
      final history =
          raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      history.sort((a, b) {
        final at = a['created_at'];
        final bt = b['created_at'];
        final aDate = at is Timestamp
            ? at.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = bt is Timestamp
            ? bt.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
      return history;
    }

    final fallback = <Map<String, dynamic>>[];
    if (data['created_at'] is Timestamp) {
      fallback.add({
        'status': 'pending',
        'title': context.tr('Servis dibuat', 'Service created'),
        'description': context.tr(
          'Data servis sudah dibuat dan menunggu proses admin.',
          'Service data has been created and is waiting for admin processing.',
        ),
        'created_at': data['created_at'],
      });
    }
    if (data['completed_at'] is Timestamp) {
      fallback.add({
        'status': 'completed',
        'title': context.tr('Servis selesai', 'Service completed'),
        'description': (data['service_detail'] ?? '').toString().isNotEmpty
            ? data['service_detail'].toString()
            : context.tr(
                'Servis telah selesai dikerjakan.',
                'The service has been completed.',
              ),
        'created_at': data['completed_at'],
      });
    }
    if (data['taken_at'] is Timestamp) {
      fallback.add({
        'status': 'sudah_diambil',
        'title': context.tr('Perangkat diambil', 'Device picked up'),
        'description': context.tr(
          'Perangkat sudah diambil customer.',
          'The device has been picked up by the customer.',
        ),
        'created_at': data['taken_at'],
      });
    }
    return fallback;
  }

  IconData _timelineIcon(String status) {
    switch (status) {
      case 'in_progress':
        return Icons.build_circle_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'sudah_diambil':
        return Icons.inventory_2_outlined;
      case 'cancelled':
      case 'failed':
        return Icons.cancel_outlined;
      case 'awaiting_confirmation':
        return Icons.payments_outlined;
      default:
        return Icons.schedule;
    }
  }

  Color _timelineColor(String status) {
    switch (status) {
      case 'in_progress':
        return AppTheme.infoColor;
      case 'completed':
      case 'sudah_diambil':
        return AppTheme.successColor;
      case 'cancelled':
      case 'failed':
        return AppTheme.dangerColor;
      case 'awaiting_confirmation':
        return AppTheme.primaryColor;
      default:
        return AppTheme.warningColor;
    }
  }

  String _statusDescription(BuildContext context, String status) {
    switch (status) {
      case 'pending':
        return context.tr(
          'Menunggu antrian atau tindak lanjut admin.',
          'Waiting for queue or admin follow-up.',
        );
      case 'in_progress':
        return context.tr(
          'Servis sedang dikerjakan oleh admin/teknisi.',
          'The service is being handled by the admin/technician.',
        );
      case 'completed':
        return context.tr(
          'Servis selesai. Silakan pilih metode pembayaran dan konfirmasi pengambilan.',
          'The service is complete. Please choose a payment method and confirm pickup.',
        );
      case 'cancelled':
        return context.tr(
          'Servis dibatalkan oleh admin.',
          'The service was cancelled by the admin.',
        );
      case 'failed':
        return context.tr(
          'Servis dinyatakan gagal / tidak dapat dilanjutkan.',
          'The service was marked as failed and cannot continue.',
        );
      case 'sudah_diambil':
        return context.tr(
          'Perangkat sudah diambil customer.',
          'The device has been picked up by the customer.',
        );
      default:
        return status;
    }
  }

  String _translateTimelineText(BuildContext context, String text) {
    switch (text) {
      case 'Servis dibuat':
        return context.tr('Servis dibuat', 'Service created');
      case 'Data servis sudah dibuat dan menunggu proses admin.':
        return context.tr(
          'Data servis sudah dibuat dan menunggu proses admin.',
          'Service data has been created and is waiting for admin processing.',
        );
      case 'Servis selesai':
        return context.tr('Servis selesai', 'Service completed');
      case 'Servis telah selesai dikerjakan.':
        return context.tr(
          'Servis telah selesai dikerjakan.',
          'The service has been completed.',
        );
      case 'Perangkat diambil':
        return context.tr('Perangkat diambil', 'Device picked up');
      case 'Perangkat sudah diambil customer.':
        return context.tr(
          'Perangkat sudah diambil customer.',
          'The device has been picked up by the customer.',
        );
      default:
        return text;
    }
  }
}
