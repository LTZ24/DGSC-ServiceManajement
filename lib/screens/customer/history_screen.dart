import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/firebase_db_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/status_badge.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseDbService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Servis')),
      drawer: const AppDrawer(isAdmin: false),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseDbService.userBookingsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada riwayat servis',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        _statusColor(status).withValues(alpha: 0.15),
                    child: Icon(_statusIcon(status),
                        color: _statusColor(status), size: 20),
                  ),
                  title: Text(
                    '${data["brand"] ?? ""} ${data["model"] ?? ""}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: StatusBadge(status: status),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row('Perangkat', data['device_type'] ?? '-'),
                          _row('Merek', data['brand'] ?? '-'),
                          _row('Model', data['model'] ?? '-'),
                          _row('Masalah', data['issue_description'] ?? '-'),
                          _row('Tanggal', data['preferred_date'] ?? '-'),
                          if ((data['diagnosis_result'] ?? '').toString().isNotEmpty)
                            _row('Diagnosis', data['diagnosis_result']),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppTheme.warningColor;
      case 'approved': return AppTheme.infoColor;
      case 'converted': return AppTheme.primaryColor;
      case 'rejected': case 'cancelled': return AppTheme.dangerColor;
      default: return AppTheme.successColor;
    }
  }

  static IconData _statusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.pending;
      case 'approved': return Icons.check;
      case 'converted': return Icons.build;
      case 'rejected': case 'cancelled': return Icons.close;
      default: return Icons.check_circle;
    }
  }

  static Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}