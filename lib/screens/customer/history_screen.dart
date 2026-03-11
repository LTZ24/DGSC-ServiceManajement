import 'package:flutter/material.dart';
import '../../l10n/app_text.dart';
import '../../config/theme.dart';
import '../../services/backend_types.dart';
import '../../services/backend_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/status_badge.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Stream<QuerySnapshot> _historyStream;

  @override
  void initState() {
    super.initState();
    final uid = BackendService.currentUser?.uid ?? '';
    _historyStream = BackendService.userBookingsStream(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Riwayat Servis', 'Service History'))),
      drawer: const AppDrawer(isAdmin: false),
      body: StreamBuilder<QuerySnapshot>(
        stream: _historyStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: mutedColor),
                  const SizedBox(height: 16),
                    Text(context.tr('Belum ada riwayat servis', 'No service history yet'),
                      style: TextStyle(color: mutedColor)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final status = data['status'] ?? 'pending';
              return AppListCard(
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
                          _row(
                                context, context.tr('Perangkat', 'Device'), data['device_type'] ?? '-'),
                              _row(context, context.tr('Merek', 'Brand'), data['brand'] ?? '-'),
                              _row(context, context.tr('Model', 'Model'), data['model'] ?? '-'),
                              _row(context, context.tr('Masalah', 'Issue'),
                              data['issue_description'] ?? '-'),
                              _row(context, context.tr('Tanggal', 'Date'),
                              data['preferred_date'] ?? '-'),
                          if ((data['diagnosis_result'] ?? '')
                              .toString()
                              .isNotEmpty)
                            _row(
                                context, context.tr('Diagnosis', 'Diagnosis'), data['diagnosis_result']),
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
      case 'pending':
        return AppTheme.warningColor;
      case 'approved':
        return AppTheme.infoColor;
      case 'converted':
        return AppTheme.primaryColor;
      case 'rejected':
      case 'cancelled':
        return AppTheme.dangerColor;
      default:
        return AppTheme.successColor;
    }
  }

  static IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.check;
      case 'converted':
        return Icons.build;
      case 'rejected':
      case 'cancelled':
        return Icons.close;
      default:
        return Icons.check_circle;
    }
  }

  static Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

