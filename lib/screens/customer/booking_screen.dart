import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_types.dart';
import '../../services/cf_engine.dart';
import '../../services/backend_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/diagnosis_dialog.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  final _issueController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _preferredDate;
  bool _isLoading = false;
  String _selectedDeviceType = 'Handphone';
  String? _selectedBrand;

  // Diagnosis data (CF-based)
  List<CfResult>? _diagnosisResults;
  CfCategory? _diagnosisCategory;
  List<CfSymptom>? _diagnosisSymptoms;

  final List<String> _deviceTypes = ['Handphone', 'Laptop'];
  final List<String> _brands = [
    'Samsung',
    'Apple',
    'Xiaomi',
    'OPPO',
    'Vivo',
    'Realme',
    'Asus',
    'Lenovo',
    'HP',
    'Dell',
    'Acer',
    'MSI',
    'Lainnya',
  ];

  @override
  void dispose() {
    _modelController.dispose();
    _serialController.dispose();
    _issueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null) setState(() => _preferredDate = date);
  }

  void _openDiagnosis() {
    showDialog(
      context: context,
      builder: (_) => DiagnosisDialog(
        onResultSelected: (results, category, symptoms) {
          setState(() {
            _diagnosisResults = results;
            _diagnosisCategory = category;
            _diagnosisSymptoms = symptoms;
            if (category.name.toLowerCase().contains('handphone')) {
              _selectedDeviceType = 'Handphone';
            } else {
              _selectedDeviceType = 'Laptop';
            }
            if (results.isNotEmpty) {
              final top = results.first;
              _issueController.text =
                  'Diagnosis: ${top.damage.name} (${top.cfPercentage.toStringAsFixed(1)}%)';
            }
          });
        },
      ),
    );
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final customerFallback = context.tr('Customer', 'Customer');

    final authProfile = context.read<AuthProvider>().profile;

    final user = BackendService.currentUser;
    final uid = user?.uid ?? '';
    final profile = authProfile ??
      (uid.isEmpty ? null : await BackendService.getUserProfile(uid));
    if (!mounted) return;
    final resolvedName =
        (profile?['username']?.toString().trim().isNotEmpty ?? false)
            ? profile!['username'].toString().trim()
            : (user?.displayName?.trim().isNotEmpty ?? false)
                ? user!.displayName!.trim()
                : (user?.email?.split('@').first.trim().isNotEmpty ?? false)
                    ? user!.email!.split('@').first.trim()
                    : customerFallback;
    final resolvedPhone = profile?['phone']?.toString().trim() ?? '';

    final data = <String, dynamic>{
      'customer_id': uid,
      'customer_name': resolvedName,
      'customer_phone': resolvedPhone,
      'device_type': _selectedDeviceType,
      'brand': _selectedBrand ?? '',
      'model': _modelController.text.trim(),
      'serial_number': _serialController.text.trim(),
      'issue_description': _issueController.text.trim(),
      'notes': _notesController.text.trim(),
      'status': 'pending',
    };

    if (_preferredDate != null) {
      data['preferred_date'] = DateFormat('yyyy-MM-dd').format(_preferredDate!);
    }

    if (_diagnosisResults != null && _diagnosisCategory != null) {
      data['diagnosis_category'] = _diagnosisCategory!.name;
      data['diagnosis_symptoms'] =
          _diagnosisSymptoms?.map((s) => s.name).join(', ') ?? '';
      data['diagnosis_result'] = _diagnosisResults!
          .map((r) => '${r.damage.name}: ${r.cfPercentage.toStringAsFixed(1)}%')
          .join('; ');
      data['diagnosis_cf_percentage'] = _diagnosisResults!.isNotEmpty
          ? _diagnosisResults!.first.cfPercentage
          : 0;
    }

    final notifyAdminTitle =
        context.tr('Booking servis baru', 'New service booking');
    final notifyAdminMessage = context.tr(
      'Booking baru dari ${data['customer_name'] ?? 'customer'} untuk ${data['brand'] ?? ''} ${data['model'] ?? ''}.',
      'New booking from ${data['customer_name'] ?? 'customer'} for ${data['brand'] ?? ''} ${data['model'] ?? ''}.',
    );

    try {
      final bookingRef = await BackendService.addBooking(data);

      try {
        await BackendService.notifyAdmins(
          title: notifyAdminTitle,
          message: notifyAdminMessage,
          relatedId: bookingRef.id,
          type: 'booking',
        );
      } catch (_) {
        // Ignore notification failures so booking submission remains successful.
      }

      // Save diagnosis history if diagnosis was done
      if (_diagnosisResults != null && _diagnosisCategory != null) {
        await BackendService.saveDiagnosisHistory(
          categoryId: _diagnosisCategory!.id,
          categoryName: _diagnosisCategory!.name,
          deviceInfo:
              '$_selectedDeviceType ${_selectedBrand ?? ""} ${_modelController.text.trim()}',
          selectedSymptomIds:
              _diagnosisSymptoms?.map((s) => s.id).toList() ?? [],
          results: _diagnosisResults!
              .map((r) => {
                    'damage_id': r.damage.id,
                    'damage_name': r.damage.name,
                    'cf_combined': r.cfCombined,
                    'cf_percentage': r.cfPercentage,
                  })
              .toList(),
          topDiagnosis: _diagnosisResults!.first.damage.name,
          cfPercentage: _diagnosisResults!.first.cfPercentage,
          userId: uid,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr(
              'Booking berhasil dikirim!', 'Booking submitted successfully!')),
          backgroundColor: AppTheme.successColor,
        ));
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/customer/status',
          (route) => route.settings.name == '/customer/dashboard',
        );
      }
    } on BackendException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${context.tr('Gagal', 'Failed')}: ${e.message}'),
          backgroundColor: AppTheme.dangerColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshBooking() async {
    await context.read<AuthProvider>().refreshProfile();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar:
          AppBar(title: Text(context.tr('Booking Servis', 'Service Booking'))),
      drawer: const AppDrawer(isAdmin: false),
      body: RefreshIndicator.adaptive(
        onRefresh: _refreshBooking,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 450),
                tween: Tween(begin: 0.96, end: 1),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.scale(scale: value, child: child),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withValues(alpha: 0.82),
                        AppTheme.accentColor.withValues(alpha: 0.88),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.event_available,
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
                                  context.tr('Booking Servis Premium',
                                      'Premium Service Booking'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.tr(
                                      'Isi data perangkat sekali, lalu pantau progres servis dari halaman status.',
                                      'Fill in your device data once, then track service progress from the status page.'),
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
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildHeroChip(Icons.schedule,
                              context.tr('Respon cepat', 'Fast response')),
                          _buildHeroChip(
                              Icons.support_agent,
                              context.tr('Update status real-time',
                                  'Real-time status updates')),
                          _buildHeroChip(
                              Icons.payments_outlined,
                              context.tr(
                                  'Pembayaran fleksibel', 'Flexible payment')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _BookingSectionCard(
                title: context.tr('Diagnosis awal', 'Initial diagnosis'),
                subtitle: context.tr(
                    'Opsional, tetapi membantu admin memahami gejala lebih cepat.',
                    'Optional, but helps admin understand the symptoms faster.'),
                child: InkWell(
                  onTap: _openDiagnosis,
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.accentColor.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(children: [
                      const Icon(Icons.medical_services,
                          color: AppTheme.accentColor, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                context.tr(
                                    'Diagnosis Kerusakan', 'Damage Diagnosis'),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                              _diagnosisResults != null
                                  ? '${context.tr('Hasil teratas', 'Top result')}: ${_diagnosisResults!.first.damage.name}'
                                  : context.tr(
                                      'Cek kerusakan perangkat Anda sebelum booking.',
                                      'Check your device issues before booking.'),
                              style: TextStyle(fontSize: 12, color: mutedColor),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _BookingSectionCard(
                title: context.tr('Informasi perangkat', 'Device information'),
                subtitle: context.tr(
                    'Data ini membantu tim menyiapkan estimasi pengerjaan dan spare part.',
                    'This data helps the team prepare estimates and spare parts.'),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDeviceType,
                      decoration: InputDecoration(
                          labelText:
                              context.tr('Jenis Perangkat', 'Device Type'),
                          prefixIcon: const Icon(Icons.devices)),
                      items: _deviceTypes
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedDeviceType = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                          labelText: context.tr('Merek', 'Brand'),
                          prefixIcon: const Icon(Icons.branding_watermark)),
                      items: _brands
                          .map(
                              (b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedBrand = val),
                      validator: (v) => v == null
                          ? context.tr('Pilih merek', 'Select a brand')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _modelController,
                      decoration: InputDecoration(
                          labelText: context.tr('Model', 'Model'),
                          prefixIcon: const Icon(Icons.phone_android),
                          hintText: context.tr('Contoh: Galaxy S21, iPhone 14',
                              'Example: Galaxy S21, iPhone 14')),
                      validator: (v) => v == null || v.isEmpty
                          ? context.tr('Model wajib diisi', 'Model is required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _serialController,
                      decoration: InputDecoration(
                          labelText: context.tr('Nomor Seri (opsional)',
                              'Serial Number (optional)'),
                          prefixIcon: const Icon(Icons.qr_code)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _BookingSectionCard(
                title: context.tr('Detail kendala', 'Issue details'),
                subtitle: context.tr(
                    'Tulis gejala utama agar proses pengecekan lebih akurat.',
                    'Write the main symptoms so the inspection process is more accurate.'),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _issueController,
                      maxLines: 4,
                      decoration: InputDecoration(
                          labelText: context.tr(
                              'Deskripsi Kerusakan', 'Issue Description'),
                          alignLabelWithHint: true,
                          hintText: context.tr(
                              'Jelaskan masalah perangkat Anda...',
                              'Describe your device problem...')),
                      validator: (v) => v == null || v.isEmpty
                          ? context.tr('Deskripsi wajib diisi',
                              'Description is required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                            labelText: context.tr(
                                'Tanggal Preferensi', 'Preferred Date'),
                            prefixIcon: const Icon(Icons.calendar_today)),
                        child: Text(
                          _preferredDate != null
                              ? DateFormat('dd MMMM yyyy', 'id_ID')
                                  .format(_preferredDate!)
                              : context.tr('Pilih tanggal kunjungan',
                                  'Choose a visit date'),
                          style: TextStyle(
                            color: _preferredDate != null ? null : mutedColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                          labelText: context.tr('Catatan Tambahan (opsional)',
                              'Additional Notes (optional)'),
                          alignLabelWithHint: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr(
                            'Setelah booking dikirim, admin akan meninjau data lalu status booking dan servis dapat dipantau dari menu Status.',
                            'After the booking is sent, the admin will review the data and the booking/service status can be tracked from the Status menu.'),
                        style: TextStyle(color: mutedColor, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitBooking,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: Text(_isLoading
                        ? context.tr('Mengirim...', 'Sending...')
                        : context.tr('Kirim Booking', 'Submit Booking')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _BookingSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
