import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/backend_types.dart';
import '../../services/backend_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/status_badge.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});
  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  String? _statusFilter;
  late final Stream<QuerySnapshot> _bookingsStream;
  final Map<String, String> _statusOverrides = {};
  List<QueryDocumentSnapshot> _cachedDocs = const [];

  @override
  void initState() {
    super.initState();
    _bookingsStream = BackendService.allBookingsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Booking', 'Bookings')),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            tooltip: context.tr('Filter', 'Filter'),
            onSelected: (val) => setState(() => _statusFilter = val),
            itemBuilder: (_) => [
              PopupMenuItem(value: null, child: Text(context.tr('Semua', 'All'))),
              PopupMenuItem(value: 'pending', child: Text(context.tr('Pending', 'Pending'))),
              PopupMenuItem(value: 'approved', child: Text(context.tr('Disetujui', 'Approved'))),
              PopupMenuItem(value: 'rejected', child: Text(context.tr('Ditolak', 'Rejected'))),
              PopupMenuItem(value: 'converted', child: Text(context.tr('Dikonversi', 'Converted'))),
              PopupMenuItem(value: 'cancelled', child: Text(context.tr('Dibatalkan', 'Cancelled'))),
            ],
          ),
        ],
      ),
      drawer: const AppDrawer(isAdmin: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: _bookingsStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedDocs = snapshot.data!.docs;
          }
          final sourceDocs = snapshot.data?.docs ?? _cachedDocs;
          if (snapshot.connectionState == ConnectionState.waiting &&
              sourceDocs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${context.tr('Error', 'Error')}: ${snapshot.error}'));
          }
          var docs = sourceDocs;
          if (_statusFilter != null) {
            docs = docs
                .where((d) {
                  final baseStatus = (d.data() as Map)['status']?.toString();
                  final effectiveStatus = _statusOverrides[d.id] ?? baseStatus;
                  return effectiveStatus == _statusFilter;
                })
                .toList();
          }
          if (docs.isEmpty) {
            final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: mutedColor),
                  const SizedBox(height: 16),
                  Text(context.tr('Tidak ada booking', 'No bookings'),
                      style: TextStyle(color: mutedColor)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = Map<String, dynamic>.from(doc.data());
              final overrideStatus = _statusOverrides[doc.id];
              if (overrideStatus != null) {
                data['status'] = overrideStatus;
              }
              return _BookingCard(
                docId: doc.id,
                data: data,
                onStatusChanged: (status) {
                  setState(() {
                    if (status == null) {
                      _statusOverrides.remove(doc.id);
                    } else {
                      _statusOverrides[doc.id] = status;
                    }
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final ValueChanged<String?> onStatusChanged;

  const _BookingCard({
    required this.docId,
    required this.data,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    final customerId = (data['customer_id'] ?? '').toString();
    return AppListCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${data["brand"] ?? ""} ${data["model"] ?? ""}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 4),
            _CustomerAccountInfo(
              customerId: customerId,
              fallbackName: (data['customer_name'] ?? '').toString(),
              fallbackPhone: (data['customer_phone'] ?? '').toString(),
            ),
            Text(data['device_type'] ?? '',
                style: const TextStyle(fontSize: 12)),
            if ((data['issue_description'] ?? '').toString().isNotEmpty)
              Text(data['issue_description'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if ((data['diagnosis_result'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.medical_services,
                    size: 13, color: Colors.blue),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(data['diagnosis_result'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.blue))),
              ]),
            ],
            const SizedBox(height: 10),
            Row(children: [
              if (status == 'pending') ...[
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () => _updateStatus(context, 'approved'),
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(context.tr('Setujui', 'Approve')),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerColor),
                  onPressed: () => _updateStatus(context, 'rejected'),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(context.tr('Tolak', 'Reject')),
                )),
              ],
              if (status == 'approved')
                Expanded(
                    child: ElevatedButton.icon(
                  onPressed: () => _convertToService(context),
                  icon: const Icon(Icons.build, size: 16),
                  label: Text(context.tr('Buat Servis', 'Create Service')),
                )),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.dangerColor),
                onPressed: () => _delete(context),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext ctx, String status) async {
    final previousStatus = (data['status'] ?? 'pending').toString();
    onStatusChanged(status);
    try {
      await BackendService.updateBookingStatus(docId, status);
      await BackendService.addNotification(
        userId: (data['customer_id'] ?? '').toString(),
        type: 'booking',
        title: status == 'approved'
            ? ctx.tr('Booking diterima', 'Booking approved')
            : ctx.tr('Booking ditolak', 'Booking rejected'),
        message: status == 'approved'
            ? ctx.tr('Booking ${data['brand'] ?? ''} ${data['model'] ?? ''} telah diterima admin.', 'Booking ${data['brand'] ?? ''} ${data['model'] ?? ''} has been approved by admin.')
            : ctx.tr('Booking ${data['brand'] ?? ''} ${data['model'] ?? ''} ditolak admin. Silakan cek detail atau hubungi toko.', 'Booking ${data['brand'] ?? ''} ${data['model'] ?? ''} was rejected by admin. Please check the details or contact the store.'),
        relatedId: docId,
      );
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text('${ctx.tr('Status', 'Status')}: $status')));
      }
    } catch (e) {
      onStatusChanged(previousStatus);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('${ctx.tr('Gagal mengubah status booking', 'Failed to change booking status')}: $e')),
        );
      }
    }
  }

  Future<void> _convertToService(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
              title: Text(ctx.tr('Buat Servis', 'Create Service')),
              content: Text(
                  ctx.tr('Konversi booking ${data["brand"]} ${data["model"]} ke servis?', 'Convert booking ${data["brand"]} ${data["model"]} to a service?')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(ctx.tr('Batal', 'Cancel'))),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(ctx.tr('Create', 'Create'))),
              ],
            ));
    if (confirm != true) return;
    onStatusChanged('converted');

    await BackendService.addService({
      'origin_booking_id': docId,
      'customer_id': data['customer_id'] ?? '',
      'customer_name': data['customer_name'] ?? '',
      'customer_phone': data['customer_phone'] ?? '',
      'device_type': data['device_type'] ?? '',
      'device_brand': data['brand'] ?? '',
      'model': data['model'] ?? '',
      'serial_number': data['serial_number'] ?? '',
      'problem': data['issue_description'] ?? '',
      'status': 'pending',
    });
    await BackendService.updateBookingStatus(docId, 'converted');
    await BackendService.addNotification(
      userId: (data['customer_id'] ?? '').toString(),
      type: 'booking',
      title: ctx.tr('Booking diproses menjadi servis', 'Booking converted to service'),
      message:
          ctx.tr('Booking ${data['brand'] ?? ''} ${data['model'] ?? ''} sudah dibuat menjadi data servis aktif.', 'Booking ${data['brand'] ?? ''} ${data['model'] ?? ''} has been created as an active service.'),
      relatedId: docId,
    );

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(ctx.tr('Servis berhasil dibuat', 'Service created successfully')),
        backgroundColor: AppTheme.successColor,
      ));
    }
  }

  Future<void> _delete(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
              title: Text(ctx.tr('Hapus Booking', 'Delete Booking')),
              content: Text(ctx.tr('Yakin ingin menghapus?', 'Are you sure you want to delete this?')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(ctx.tr('Batal', 'Cancel'))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dangerColor),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(ctx.tr('Hapus', 'Delete')),
                ),
              ],
            ));
    if (confirm != true) return;
    await BackendService.deleteBooking(docId);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text(ctx.tr('Dihapus', 'Deleted'))));
    }
  }
}

class _CustomerAccountInfo extends StatelessWidget {
  final String customerId;
  final String fallbackName;
  final String fallbackPhone;

  const _CustomerAccountInfo({
    required this.customerId,
    required this.fallbackName,
    required this.fallbackPhone,
  });

  @override
  Widget build(BuildContext context) {
    if (customerId.isEmpty) {
      return _buildInfo(fallbackName, fallbackPhone, '');
    }

    if (fallbackName.isNotEmpty || fallbackPhone.isNotEmpty) {
      return _buildInfo(fallbackName, fallbackPhone, '');
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: BackendService.getUserProfile(customerId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = fallbackName.isNotEmpty
            ? fallbackName
            : (profile?['username']?.toString() ?? '');
        final phone = fallbackPhone.isNotEmpty
            ? fallbackPhone
            : (profile?['phone']?.toString() ?? '');
        final email = profile?['email']?.toString() ?? '';
        return _buildInfo(name, phone, email);
      },
    );
  }

  Widget _buildInfo(String name, String phone, String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty)
          Text(name, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        if (phone.isNotEmpty)
          Text(phone,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        if (email.isNotEmpty)
          Text(email,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

