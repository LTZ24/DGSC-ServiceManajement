import 'package:flutter/material.dart';
import '../config/theme.dart';

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
        label = 'Menunggu';
        break;
      case 'processed':
      case 'in_progress':
        bgColor = AppTheme.infoColor.withValues(alpha: 0.15);
        textColor = AppTheme.infoColor;
        label = status == 'in_progress' ? 'Dikerjakan' : 'Diproses';
        break;
      case 'completed':
      case 'selesai':
        bgColor = AppTheme.successColor.withValues(alpha: 0.15);
        textColor = Colors.green.shade800;
        label = 'Selesai';
        break;
      case 'sudah_diambil':
        bgColor = AppTheme.primaryColor.withValues(alpha: 0.15);
        textColor = AppTheme.primaryColor;
        label = 'Sudah Diambil';
        break;
      case 'cancelled':
        bgColor = AppTheme.dangerColor.withValues(alpha: 0.15);
        textColor = AppTheme.dangerColor;
        label = 'Dibatalkan';
        break;
      case 'paid':
        bgColor = AppTheme.successColor.withValues(alpha: 0.15);
        textColor = Colors.green.shade800;
        label = 'Lunas';
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
