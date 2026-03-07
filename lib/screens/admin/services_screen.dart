import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/firebase_db_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/status_badge.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});
  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  String? _statusFilter;
  final _searchCtrl = TextEditingController();
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20, left: 20, right: 20),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Buat Servis Baru',
                    style: Theme.of(ctx).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseDbService.customersStream(),
                  builder: (ctx2, snap) {
                    final docs = snap.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'Pelanggan',
                          prefixIcon: Icon(Icons.person)),
                      items: docs.map((d) {
                        final cd = d.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: d.id,
                          child: Text('${cd["name"]} (${cd["phone"] ?? ""})',
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        customerId = val;
                        final cd = docs.firstWhere((d) => d.id == val).data()
                            as Map<String, dynamic>;
                        customerName = cd['name'];
                        customerPhone = cd['phone'];
                      },
                      validator: (v) => v == null ? 'Pilih pelanggan' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                StatefulBuilder(builder: (ctx3, setSt) =>
                  DropdownButtonFormField<String>(
                    value: deviceType,
                    decoration: const InputDecoration(labelText: 'Jenis Perangkat'),
                    items: const [
                      DropdownMenuItem(value: 'Handphone', child: Text('Handphone')),
                      DropdownMenuItem(value: 'Laptop', child: Text('Laptop')),
                    ],
                    onChanged: (v) => setSt(() => deviceType = v!),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: brandCtrl,
                  decoration: const InputDecoration(labelText: 'Merek'),
                  validator: (v) => v?.isEmpty == true ? 'Wajib' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(labelText: 'Model'),
                  validator: (v) => v?.isEmpty == true ? 'Wajib' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: problemCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Keluhan / Masalah',
                      alignLabelWithHint: true),
                  validator: (v) => v?.isEmpty == true ? 'Wajib' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: techCtrl,
                  decoration: const InputDecoration(labelText: 'Teknisi'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await FirebaseDbService.addService({
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
                          const SnackBar(content: Text('Servis dibuat')));
                    }
                  },
                  child: const Text('Simpan'),
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
        title: const Text('Servis'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (val) => setState(() => _statusFilter = val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('Semua')),
              PopupMenuItem(value: 'pending', child: Text('Pending')),
              PopupMenuItem(value: 'in_progress', child: Text('Dikerjakan')),
              PopupMenuItem(value: 'completed', child: Text('Selesai')),
              PopupMenuItem(value: 'sudah_diambil', child: Text('Sudah Diambil')),
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
        stream: FirebaseDbService.servicesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data?.docs ?? [];
          if (_statusFilter != null) {
            docs = docs
                .where((d) => (d.data() as Map)['status'] == _statusFilter)
                .toList();
          }
          final query = _searchCtrl.text.toLowerCase();
          if (query.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['customer_name'] ?? '').toString().toLowerCase().contains(query) ||
                  (data['model'] ?? '').toString().toLowerCase().contains(query) ||
                  (data['service_code'] ?? '').toString().toLowerCase().contains(query);
            }).toList();
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Cari nama, model, kode...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text('Tidak ada servis',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _ServiceCard(
                          docId: doc.id,
                          data: data,
                          currencyFormat: currencyFormat,
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final NumberFormat currencyFormat;
  const _ServiceCard(
      {required this.docId,
      required this.data,
      required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                  data['service_code'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                )),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                '${data["device_brand"] ?? ""} ${data["model"] ?? ""}  (${data["device_type"] ?? ""})',
                style: const TextStyle(fontSize: 14)),
            Text(data['customer_name'] ?? '',
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
            if ((data['problem'] ?? '').toString().isNotEmpty)
              Text(data['problem'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
            if ((data['technician'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const Icon(Icons.engineering, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(data['technician'],
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
            if ((data['cost'] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    currencyFormat.format((data['cost'] as num).toDouble()),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor)),
              ),
            const SizedBox(height: 8),
            Row(children: [
              if (status != 'sudah_diambil')
                TextButton.icon(
                  onPressed: () =>
                      FirebaseDbService.advanceServiceStatus(docId, status),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Lanjutkan', style: TextStyle(fontSize: 12)),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.dangerColor),
                onPressed: () async {
                  await FirebaseDbService.deleteService(docId);
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}