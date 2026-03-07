import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/firebase_db_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/status_badge.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});
  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            tooltip: 'Filter',
            onSelected: (val) => setState(() => _statusFilter = val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('Semua')),
              PopupMenuItem(value: 'pending', child: Text('Pending')),
              PopupMenuItem(value: 'approved', child: Text('Disetujui')),
              PopupMenuItem(value: 'rejected', child: Text('Ditolak')),
              PopupMenuItem(value: 'converted', child: Text('Dikonversi')),
              PopupMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
            ],
          ),
        ],
      ),
      drawer: const AppDrawer(isAdmin: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseDbService.allBookingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          var docs = snapshot.data?.docs ?? [];
          if (_statusFilter != null) {
            docs = docs
                .where((d) => (d.data() as Map)['status'] == _statusFilter)
                .toList();
          }
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Tidak ada booking',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _BookingCard(docId: doc.id, data: data);
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
  const _BookingCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
            if ((data['customer_name'] ?? '').toString().isNotEmpty)
              Text(data['customer_name'],
                  style:
                      const TextStyle(fontSize: 13, color: Colors.grey)),
            Text(data['device_type'] ?? '',
                style: const TextStyle(fontSize: 12)),
            if ((data['issue_description'] ?? '').toString().isNotEmpty)
              Text(data['issue_description'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
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
                        style: const TextStyle(
                            fontSize: 12, color: Colors.blue))),
              ]),
            ],
            const SizedBox(height: 10),
            Row(children: [
              if (status == 'pending') ...[
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () => _updateStatus(context, 'approved'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Setujui'),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerColor),
                  onPressed: () => _updateStatus(context, 'rejected'),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Tolak'),
                )),
              ],
              if (status == 'approved')
                Expanded(
                    child: ElevatedButton.icon(
                  onPressed: () => _convertToService(context),
                  icon: const Icon(Icons.build, size: 16),
                  label: const Text('Buat Servis'),
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
    await FirebaseDbService.updateBookingStatus(docId, status);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text('Status: $status')));
    }
  }

  Future<void> _convertToService(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
              title: const Text('Buat Servis'),
              content: Text(
                  'Konversi booking ${data["brand"]} ${data["model"]} ke servis?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Buat')),
              ],
            ));
    if (confirm != true) return;

    await FirebaseDbService.addService({
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
    await FirebaseDbService.updateBookingStatus(docId, 'converted');

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Servis berhasil dibuat'),
        backgroundColor: AppTheme.successColor,
      ));
    }
  }

  Future<void> _delete(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
              title: const Text('Hapus Booking'),
              content: const Text('Yakin ingin menghapus?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dangerColor),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Hapus'),
                ),
              ],
            ));
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(docId)
        .delete();
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(const SnackBar(content: Text('Dihapus')));
    }
  }
}