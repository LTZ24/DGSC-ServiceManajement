import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/backend_types.dart';
import '../../services/backend_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/status_badge.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  String? _statusFilter;
  final _searchCtrl = TextEditingController();
  late final Stream<QuerySnapshot> _servicesStream;
  final Map<String, Map<String, dynamic>> _serviceOverrides = {};
  final Set<String> _deletedServiceIds = <String>{};
  List<QueryDocumentSnapshot> _cachedDocs = const [];
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _servicesStream = BackendService.servicesStream();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showCreateDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final problemCtrl = TextEditingController();
    final techCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    String deviceType = 'Handphone';
    String? customerId;
    String? customerName;
    String? customerPhone;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('Buat Servis Baru', 'Create New Service'),
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: BackendService.customersStream(),
                  builder: (ctx2, snap) {
                    final docs = snap.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: context.tr('Pelanggan', 'Customer'),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      items: docs.map((d) {
                        final cd = d.data();
                        return DropdownMenuItem<String>(
                          value: d.id,
                          child: Text(
                            '${cd["name"]} (${cd["phone"] ?? ""})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        customerId = val;
                        final cd = docs.firstWhere((d) => d.id == val).data();
                        customerName = cd['name'];
                        customerPhone = cd['phone'];
                      },
                      validator: (v) => v == null ? context.tr('Pilih pelanggan', 'Select a customer') : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (ctx3, setSt) => DropdownButtonFormField<String>(
                    value: deviceType,
                    decoration: InputDecoration(
                      labelText: context.tr('Jenis Perangkat', 'Device Type'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'Handphone',
                        child: Text(context.tr('Handphone', 'Phone')),
                      ),
                      DropdownMenuItem(
                        value: 'Laptop',
                        child: Text(context.tr('Laptop', 'Laptop')),
                      ),
                    ],
                    onChanged: (v) => setSt(() => deviceType = v!),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: brandCtrl,
                  decoration: InputDecoration(labelText: context.tr('Merek', 'Brand')),
                  validator: (v) => v?.isEmpty == true ? context.tr('Wajib', 'Required') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: modelCtrl,
                  decoration: InputDecoration(labelText: context.tr('Model', 'Model')),
                  validator: (v) => v?.isEmpty == true ? context.tr('Wajib', 'Required') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: problemCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr('Keluhan / Masalah', 'Issue / Problem'),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => v?.isEmpty == true ? context.tr('Wajib', 'Required') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: techCtrl,
                  decoration: InputDecoration(labelText: context.tr('Teknisi', 'Technician')),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await BackendService.addService({
                      'customer_id': customerId ?? '',
                      'customer_name': customerName ?? '',
                      'customer_phone': customerPhone ?? '',
                      'device_type': deviceType,
                      'device_brand': brandCtrl.text,
                      'model': modelCtrl.text,
                      'problem': problemCtrl.text,
                      'technician': techCtrl.text,
                      'status': 'pending',
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(context.tr('Servis dibuat', 'Service created'))),
                      );
                    }
                  },
                  child: Text(context.tr('Simpan', 'Save')),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Servis', 'Services')),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (val) => setState(() => _statusFilter = val),
            itemBuilder: (_) => [
              PopupMenuItem(value: null, child: Text(context.tr('Semua', 'All'))),
              PopupMenuItem(value: 'pending', child: Text(context.tr('Menunggu', 'Pending'))),
              PopupMenuItem(value: 'in_progress', child: Text(context.tr('Diproses', 'In Progress'))),
              PopupMenuItem(value: 'completed', child: Text(context.tr('Selesai', 'Completed'))),
              PopupMenuItem(value: 'failed', child: Text(context.tr('Gagal', 'Failed'))),
              PopupMenuItem(value: 'cancelled', child: Text(context.tr('Dibatalkan', 'Cancelled'))),
              PopupMenuItem(
                  value: 'sudah_diambil', child: Text(context.tr('Sudah Diambil', 'Picked Up'))),
            ],
          ),
        ],
      ),
      drawer: const AppDrawer(isAdmin: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _servicesStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedDocs = snapshot.data!.docs;
          }
          final sourceDocs = snapshot.data?.docs ?? _cachedDocs;
          if (snapshot.connectionState == ConnectionState.waiting &&
              sourceDocs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = sourceDocs;
          docs = docs.where((d) => !_deletedServiceIds.contains(d.id)).toList();
          if (_statusFilter != null) {
            docs = docs
                .where((d) {
                  final base = Map<String, dynamic>.from(d.data());
                  final override = _serviceOverrides[d.id];
                  final effectiveStatus = (override?['status'] ?? base['status'])?.toString();
                  return effectiveStatus == _statusFilter;
                })
                .toList();
          }
          final query = _searchCtrl.text.toLowerCase();
          if (query.isNotEmpty) {
            docs = docs.where((d) {
              final item = d.data();
              return (item['customer_name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(query) ||
                  (item['model'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(query) ||
                  (item['service_code'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(query);
            }).toList();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: context.tr('Cari nama, model, kode...', 'Search name, model, code...'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Text(
                          context.tr('Tidak ada servis', 'No services'),
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = Map<String, dynamic>.from(doc.data());
                          final override = _serviceOverrides[doc.id];
                          if (override != null) {
                            data.addAll(override);
                          }
                          return _ServiceCard(
                            docId: doc.id,
                            data: data,
                            currencyFormat: currencyFormat,
                            onDataChanged: (patch) {
                              setState(() {
                                if (patch == null) {
                                  _serviceOverrides.remove(doc.id);
                                } else {
                                  final existing = _serviceOverrides[doc.id] ?? <String, dynamic>{};
                                  existing.addAll(patch);
                                  _serviceOverrides[doc.id] = existing;
                                }
                              });
                            },
                            onDeleted: () {
                              setState(() {
                                _deletedServiceIds.add(doc.id);
                                _serviceOverrides.remove(doc.id);
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final NumberFormat currencyFormat;
  final ValueChanged<Map<String, dynamic>?> onDataChanged;
  final VoidCallback onDeleted;

  const _ServiceCard({
    required this.docId,
    required this.data,
    required this.currencyFormat,
    required this.onDataChanged,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString();
    final estimatedCost = (data['estimated_cost'] as num? ?? 0).toDouble();
    final finalCost = (data['cost'] as num? ?? 0).toDouble();
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return AppListCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['service_code'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data["device_brand"] ?? ""} ${data["model"] ?? ""} (${data["device_type"] ?? ""})',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data['customer_name'] ?? '-',
              style: TextStyle(fontSize: 12, color: mutedColor),
            ),
            if ((data['problem'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _infoRow(context, context.tr('Keluhan', 'Issue'), data['problem'].toString()),
              ),
            if ((data['initial_detail'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _infoRow(
                  context,
                  context.tr('Detail proses', 'Process details'),
                  data['initial_detail'].toString(),
                ),
              ),
            if ((data['service_detail'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _infoRow(
                  context,
                  context.tr('Detail selesai', 'Completion details'),
                  data['service_detail'].toString(),
                ),
              ),
            if ((data['status_note'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _infoRow(
                  context,
                  context.tr('Catatan', 'Notes'),
                  data['status_note'].toString(),
                ),
              ),
            if ((data['technician'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.engineering, size: 14, color: mutedColor),
                    const SizedBox(width: 4),
                    Text(
                      '${context.tr('Teknisi', 'Technician')}: ${data['technician']}',
                      style: TextStyle(fontSize: 12, color: mutedColor),
                    ),
                  ],
                ),
              ),
            if (estimatedCost > 0 || finalCost > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (estimatedCost > 0)
                    _priceChip(
                      context.tr('Estimasi', 'Estimate'),
                      currencyFormat.format(estimatedCost),
                      AppTheme.warningColor,
                    ),
                  if (finalCost > 0)
                    _priceChip(
                      context.tr('Total final', 'Final total'),
                      currencyFormat.format(finalCost),
                      AppTheme.successColor,
                    ),
                ],
              ),
            ],
            if ((data['payment_choice'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _infoRow(
                  context,
                  context.tr('Pembayaran', 'Payment'),
                  _paymentLabel(context, (data['payment_choice'] ?? '').toString()),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (status != 'cancelled' &&
                    status != 'failed' &&
                    status != 'sudah_diambil')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handlePrimaryAction(context, status),
                      icon: Icon(_primaryIcon(status), size: 16),
                      label: Text(_primaryLabel(context, status)),
                    ),
                  ),
                if (status != 'cancelled' &&
                    status != 'failed' &&
                    status != 'sudah_diambil')
                  const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(context, value),
                  itemBuilder: (_) => [
                    if (status != 'pending')
                      PopupMenuItem(
                        value: 'pending',
                        child: Text(context.tr('Set Menunggu', 'Set Pending')),
                      ),
                    if (status != 'failed')
                      PopupMenuItem(
                        value: 'failed',
                        child: Text(context.tr('Tandai Gagal', 'Mark Failed')),
                      ),
                    if (status != 'cancelled')
                      PopupMenuItem(
                        value: 'cancelled',
                        child: Text(context.tr('Batalkan', 'Cancel')),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.tr('Hapus', 'Delete')),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _priceChip(String label, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $amount',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  String _primaryLabel(BuildContext context, String status) {
    switch (status) {
      case 'pending':
        return context.tr('Mulai Proses', 'Start Process');
      case 'in_progress':
        return context.tr('Selesaikan', 'Complete');
      case 'completed':
        return context.tr('Sudah Diambil', 'Picked Up');
      default:
        return context.tr('Lanjutkan', 'Continue');
    }
  }

  IconData _primaryIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.play_arrow;
      case 'in_progress':
        return Icons.check_circle;
      case 'completed':
        return Icons.inventory_2;
      default:
        return Icons.arrow_forward;
    }
  }

  String _paymentLabel(BuildContext context, String paymentChoice) {
    switch (paymentChoice) {
      case 'transfer':
        return context.tr('Transfer Bank', 'Bank Transfer');
      case 'qris':
        return 'QRIS';
      case 'cash_on_pickup':
        return context.tr('Bayar Saat Ambil', 'Pay on Pickup');
      default:
        return paymentChoice;
    }
  }

  Future<void> _handlePrimaryAction(BuildContext context, String status) async {
    switch (status) {
      case 'pending':
        final result = await _showProcessDialog(context);
        if (result == null) return;
        final previousData = Map<String, dynamic>.from(data);
        onDataChanged({
          'status': 'in_progress',
          'initial_detail': result['detail'],
          'estimated_cost': result['estimated_cost'],
          'technician': result['technician'],
          'status_note': result['note'],
          'payment_status': 'pending',
        });
        try {
        await BackendService.updateService(docId, {
          'status': 'in_progress',
          'initial_detail': result['detail'],
          'estimated_cost': result['estimated_cost'],
          'technician': result['technician'],
          'status_note': result['note'],
          'payment_status': 'pending',
        });
        await BackendService.appendServiceHistory(
          serviceId: docId,
          status: 'in_progress',
          title: context.tr('Servis mulai diproses', 'Service processing started'),
          description: ((result['detail'] ?? '').toString().trim().isNotEmpty)
              ? result['detail'].toString()
              : context.tr('Servis mulai dikerjakan oleh admin/teknisi.', 'The service has started being worked on by admin/technician.'),
          actor: 'admin',
          meta: {
            'estimated_cost': result['estimated_cost'],
            'technician': result['technician'],
          },
        );
        await BackendService.notifyServiceCustomer(
          customerId: (data['customer_id'] ?? '').toString(),
          serviceId: docId,
          title: context.tr('Servis sedang diproses', 'Service is in progress'),
          message:
                context.tr('Servis ${data['service_code'] ?? ''} sudah masuk tahap diproses. ${_composeNote(context, result['note'].toString())}', 'Service ${data['service_code'] ?? ''} has entered the in-progress stage. ${_composeNote(context, result['note'].toString())}'),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Servis masuk tahap diproses', 'Service moved to in-progress stage'))),
          );
        }
        } catch (e) {
          onDataChanged(previousData);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${context.tr('Gagal', 'Failed')}: $e')),
            );
          }
        }
        return;
      case 'in_progress':
        final result = await _showCompleteDialog(context);
        if (result == null) return;
        final previousData = Map<String, dynamic>.from(data);
        onDataChanged({
          'status': 'completed',
          'service_detail': result['detail'],
          'status_note': result['note'],
          'cost': result['final_cost'],
          'payment_status': 'pending',
        });
        try {
        await BackendService.updateService(docId, {
          'status': 'completed',
          'service_detail': result['detail'],
          'status_note': result['note'],
          'cost': result['final_cost'],
          'payment_status': 'pending',
          'completed_at': FieldValue.serverTimestamp(),
        });
        await BackendService.appendServiceHistory(
          serviceId: docId,
          status: 'completed',
          title: context.tr('Servis selesai', 'Service completed'),
          description: ((result['detail'] ?? '').toString().trim().isNotEmpty)
              ? result['detail'].toString()
            : context.tr('Servis telah selesai dikerjakan.', 'The service has been completed.'),
          actor: 'admin',
          meta: {
            'final_cost': result['final_cost'],
          },
        );
        await BackendService.notifyServiceCustomer(
          customerId: (data['customer_id'] ?? '').toString(),
          serviceId: docId,
          title: context.tr('Servis selesai', 'Service completed'),
          message:
              context.tr('Servis ${data['service_code'] ?? ''} selesai diproses. Silakan cek detail servis dan pilih metode pembayaran.', 'Service ${data['service_code'] ?? ''} has been completed. Please review the details and choose a payment method.'),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Servis ditandai selesai', 'Service marked as completed'))),
          );
        }
        } catch (e) {
          onDataChanged(previousData);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${context.tr('Gagal', 'Failed')}: $e')),
            );
          }
        }
        return;
      case 'completed':
        final result = await _showPickupDialog(context);
        if (result == null) return;
        final previousData = Map<String, dynamic>.from(data);
        onDataChanged({
          'status': 'sudah_diambil',
          'payment_method': result['payment_method'].toString(),
          'payment_choice': result['payment_method'].toString(),
        });
        try {
        await BackendService.markServicePickedUp(
          serviceId: docId,
          serviceData: data,
          paymentMethod: result['payment_method'].toString(),
          amount: (result['amount'] as double?) ?? 0.0,
        );
        await BackendService.notifyServiceCustomer(
          customerId: (data['customer_id'] ?? '').toString(),
          serviceId: docId,
          title: context.tr('Servis sudah diambil', 'Service has been picked up'),
          message:
              context.tr('Perangkat untuk servis ${data['service_code'] ?? ''} sudah diambil. Transaksi sudah dicatat ke keuangan.', 'The device for service ${data['service_code'] ?? ''} has been picked up. The transaction has been recorded in finance.'),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Pengambilan selesai dan masuk keuangan', 'Pickup completed and recorded in finance')),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
        } catch (e) {
          onDataChanged(previousData);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${context.tr('Gagal', 'Failed')}: $e')),
            );
          }
        }
        return;
    }
  }

  Future<void> _handleMenuAction(BuildContext context, String value) async {
    if (value == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('Hapus Servis', 'Delete Service')),
          content: Text(context.tr('Yakin ingin menghapus data servis ini?', 'Are you sure you want to delete this service data?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('Batal', 'Cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('Hapus', 'Delete')),
            ),
          ],
        ),
      );
      if (confirm == true) {
        onDeleted();
        await BackendService.deleteService(docId);
      }
      return;
    }

    final note = await _showStatusNoteDialog(context, value);
    if (note == null) return;

    final previousData = Map<String, dynamic>.from(data);
    onDataChanged({
      'status': value,
      'status_note': note,
    });

    try {
      await BackendService.updateService(docId, {
        'status': value,
        'status_note': note,
      });
      await BackendService.appendServiceHistory(
        serviceId: docId,
        status: value,
        title: _statusTitle(context, value),
        description: note.trim().isEmpty ? context.tr('Status diperbarui oleh admin.', 'Status updated by admin.') : note,
        actor: 'admin',
      );

      await BackendService.notifyServiceCustomer(
        customerId: (data['customer_id'] ?? '').toString(),
        serviceId: docId,
        title: _statusTitle(context, value),
        message:
            '${context.tr('Status servis', 'Service status')} ${data['service_code'] ?? ''} ${context.tr('diperbarui menjadi', 'updated to')} ${_statusLabel(context, value).toLowerCase()}. ${_composeNote(context, note)}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('Status diubah ke', 'Status changed to')} ${_statusLabel(context, value)}')),
        );
      }
    } catch (e) {
      onDataChanged(previousData);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('Gagal', 'Failed')}: $e')),
        );
      }
    }
  }

  String _statusLabel(BuildContext context, String value) {
    switch (value) {
      case 'pending':
        return context.tr('Menunggu', 'Pending');
      case 'in_progress':
        return context.tr('Diproses', 'In Progress');
      case 'completed':
        return context.tr('Selesai', 'Completed');
      case 'sudah_diambil':
        return context.tr('Sudah Diambil', 'Picked Up');
      case 'failed':
        return context.tr('Gagal', 'Failed');
      case 'cancelled':
        return context.tr('Dibatalkan', 'Cancelled');
      default:
        return value;
    }
  }

  String _statusTitle(BuildContext context, String value) {
    switch (value) {
      case 'pending':
        return context.tr('Servis menunggu', 'Service pending');
      case 'in_progress':
        return context.tr('Servis diproses', 'Service in progress');
      case 'completed':
        return context.tr('Servis selesai', 'Service completed');
      case 'sudah_diambil':
        return context.tr('Servis sudah diambil', 'Service picked up');
      case 'failed':
        return context.tr('Servis gagal', 'Service failed');
      case 'cancelled':
        return context.tr('Servis dibatalkan', 'Service cancelled');
      default:
        return context.tr('Status servis diperbarui', 'Service status updated');
    }
  }

  String _composeNote(BuildContext context, String note) {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return '';
    return '${context.tr('Catatan', 'Note')}: $trimmed';
  }

  Future<Map<String, dynamic>?> _showProcessDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final detailCtrl = TextEditingController(
      text: (data['initial_detail'] ?? '').toString(),
    );
    final noteCtrl = TextEditingController(
      text: (data['status_note'] ?? '').toString(),
    );
    final techCtrl = TextEditingController(
      text: (data['technician'] ?? '').toString(),
    );
    final estimateCtrl = TextEditingController(
      text: ((data['estimated_cost'] as num? ?? 0) > 0)
          ? (data['estimated_cost'] as num).toString()
          : '',
    );

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Mulai Proses Servis', 'Start Service Process')),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: techCtrl,
                  decoration: InputDecoration(labelText: context.tr('Teknisi', 'Technician')),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: detailCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr('Detail awal servis (opsional)', 'Initial service details (optional)'),
                    alignLabelWithHint: true,
                    hintText:
                        context.tr('Contoh: cek mesin, bongkar unit, tunggu spare part', 'Example: inspect engine, disassemble unit, wait for spare part'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: estimateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr('Estimasi harga (opsional)', 'Estimated price (optional)'),
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.tr('Catatan ke customer (opsional)', 'Note to customer (optional)'),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, {
                'technician': techCtrl.text.trim(),
                'detail': detailCtrl.text.trim(),
                'note': noteCtrl.text.trim(),
                'estimated_cost': double.tryParse(estimateCtrl.text) ?? 0.0,
              });
            },
            child: Text(context.tr('Lanjutkan', 'Continue')),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showCompleteDialog(
      BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final detailCtrl = TextEditingController(
      text: (data['service_detail'] ?? '').toString(),
    );
    final noteCtrl = TextEditingController(
      text: (data['status_note'] ?? '').toString(),
    );
    final totalCtrl = TextEditingController(
      text: ((data['cost'] as num? ?? 0) > 0)
          ? (data['cost'] as num).toString()
          : ((data['estimated_cost'] as num? ?? 0) > 0)
              ? (data['estimated_cost'] as num).toString()
              : '',
    );

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Selesaikan Servis', 'Complete Service')),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: detailCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: context.tr('Detail pekerjaan servis', 'Service work details'),
                    alignLabelWithHint: true,
                    hintText:
                        context.tr('Contoh: ganti IC charger, bersihkan mesin, update software', 'Example: replace charging IC, clean engine, update software'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: totalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr('Total harga final', 'Final total price'),
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.tr('Info tambahan ke customer (opsional)', 'Additional info to customer (optional)'),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, {
                'detail': detailCtrl.text.trim(),
                'note': noteCtrl.text.trim(),
                'final_cost': double.tryParse(totalCtrl.text) ?? 0.0,
              });
            },
            child: Text(context.tr('Simpan', 'Save')),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showPickupDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(
      text: ((data['cost'] as num? ?? 0) > 0)
          ? (data['cost'] as num).toString()
          : '',
    );
    String paymentMethod =
        (data['payment_choice'] ?? data['payment_method'] ?? 'cash_on_pickup')
            .toString();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Konfirmasi Pengambilan', 'Confirm Pickup')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration:
                    InputDecoration(labelText: context.tr('Metode pembayaran', 'Payment method')),
                items: [
                  DropdownMenuItem(
                    value: 'transfer',
                    child: Text(context.tr('Transfer Bank', 'Bank Transfer')),
                  ),
                  DropdownMenuItem(value: 'qris', child: Text(context.tr('QRIS', 'QRIS'))),
                  DropdownMenuItem(
                    value: 'cash_on_pickup',
                    child: Text(context.tr('Bayar Saat Ambil', 'Pay on Pickup')),
                  ),
                ],
                onChanged: (value) => paymentMethod = value ?? 'cash_on_pickup',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('Nominal transaksi', 'Transaction amount'),
                  prefixText: 'Rp ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, {
                'payment_method': paymentMethod,
                'amount': double.tryParse(amountCtrl.text) ?? 0.0,
              });
            },
            child: Text(context.tr('Simpan', 'Save')),
          ),
        ],
      ),
    );
  }

  Future<String?> _showStatusNoteDialog(
      BuildContext context, String status) async {
    final ctrl = TextEditingController(
      text: (data['status_note'] ?? '').toString(),
    );
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${context.tr('Catatan', 'Notes')} ${_statusLabel(context, status)}'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.tr('Catatan (opsional)', 'Notes (optional)'),
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(context.tr('Simpan', 'Save')),
          ),
        ],
      ),
    );
  }
}

