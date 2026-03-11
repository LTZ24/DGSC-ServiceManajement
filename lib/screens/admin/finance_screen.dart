import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/backend_types.dart';
import '../../services/backend_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/status_badge.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});
  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  late final Stream<QuerySnapshot> _transactionsStream;
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _transactionsStream = BackendService.transactionsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Keuangan', 'Finance'))),
      drawer: const AppDrawer(isAdmin: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: _transactionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          double totalRevenue = 0, paidRevenue = 0, pendingRevenue = 0;
          for (final d in docs) {
            final data = d.data();
            final amount = (data['amount'] as num? ?? 0).toDouble();
            totalRevenue += amount;
            if (data['payment_status'] == 'paid') {
              paidRevenue += amount;
            } else if (data['payment_status'] == 'pending') {
              pendingRevenue += amount;
            }
          }
          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 250));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RevenueCard(
                    title: context.tr('Total Pendapatan', 'Total Revenue'),
                    amount: currencyFormat.format(totalRevenue),
                    icon: Icons.account_balance_wallet,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _RevenueCard(
                      title: context.tr('Sudah Dibayar', 'Paid'),
                      amount: currencyFormat.format(paidRevenue),
                      icon: Icons.check_circle,
                      color: AppTheme.successColor,
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _RevenueCard(
                      title: context.tr('Belum Dibayar', 'Unpaid'),
                      amount: currencyFormat.format(pendingRevenue),
                      icon: Icons.pending,
                      color: AppTheme.warningColor,
                    )),
                  ]),
                  const SizedBox(height: 24),
                    Text(context.tr('Riwayat Transaksi', 'Transaction History'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (docs.isEmpty)
                    Center(
                      child: Text(context.tr('Belum ada transaksi', 'No transactions yet'),
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)))
                  else
                    ...docs.map((doc) {
                      final data = doc.data();
                      final ts = data['transaction_date'];
                      String dateStr = '-';
                      if (ts is Timestamp) {
                        dateStr = DateFormat('dd MMM yyyy').format(ts.toDate());
                      }
                      return AppListCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTheme.successColor.withValues(alpha: 0.1),
                            child: const Icon(Icons.receipt,
                                color: AppTheme.successColor),
                          ),
                          title: Text(
                              currencyFormat.format(
                                  (data['amount'] as num? ?? 0).toDouble()),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${data["payment_method"] ?? "-"} | $dateStr'),
                          trailing: StatusBadge(
                              status: data['payment_status'] ?? 'pending'),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  const _RevenueCard(
      {required this.title,
      required this.amount,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text(amount,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            ],
          )),
        ]),
      ),
    );
  }
}

