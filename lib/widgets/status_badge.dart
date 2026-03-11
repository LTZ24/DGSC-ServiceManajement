import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../l10n/app_text.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double? fontSize;

  const StatusBadge({super.key, required this.status, this.fontSize});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = AppTheme.warningColor.withValues(alpha: 0.15);
        textColor = Colors.orange.shade800;
        label = context.tr('Menunggu', 'Pending');
        break;
      case 'approved':
        bgColor = AppTheme.infoColor.withValues(alpha: 0.15);
        textColor = AppTheme.infoColor;
        label = context.tr('Disetujui', 'Approved');
        break;
      case 'rejected':
        bgColor = AppTheme.dangerColor.withValues(alpha: 0.15);
        textColor = AppTheme.dangerColor;
        label = context.tr('Ditolak', 'Rejected');
        break;
      case 'converted':
        bgColor = AppTheme.primaryColor.withValues(alpha: 0.15);
        textColor = AppTheme.primaryColor;
        label = context.tr('Jadi Servis', 'Converted');
        break;
      case 'processed':
      case 'in_progress':
        bgColor = AppTheme.infoColor.withValues(alpha: 0.15);
        textColor = AppTheme.infoColor;
        label = context.tr('Diproses', 'In Progress');
        break;
      case 'completed':
      case 'selesai':
        bgColor = AppTheme.successColor.withValues(alpha: 0.15);
        textColor = Colors.green.shade800;
        label = context.tr('Selesai', 'Completed');
        break;
      case 'sudah_diambil':
        bgColor = AppTheme.primaryColor.withValues(alpha: 0.15);
        textColor = AppTheme.primaryColor;
        label = context.tr('Sudah Diambil', 'Picked Up');
        break;
      case 'cancelled':
        bgColor = AppTheme.dangerColor.withValues(alpha: 0.15);
        textColor = AppTheme.dangerColor;
        label = context.tr('Dibatalkan', 'Cancelled');
        break;
      case 'failed':
        bgColor = AppTheme.dangerColor.withValues(alpha: 0.15);
        textColor = AppTheme.dangerColor;
        label = context.tr('Gagal', 'Failed');
        break;
      case 'awaiting_confirmation':
        bgColor = AppTheme.infoColor.withValues(alpha: 0.15);
        textColor = AppTheme.infoColor;
        label = context.tr('Menunggu Konfirmasi', 'Awaiting Confirmation');
        break;
      case 'paid':
        bgColor = AppTheme.successColor.withValues(alpha: 0.15);
        textColor = Colors.green.shade800;
        label = context.tr('Lunas', 'Paid');
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.15);
        textColor = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
