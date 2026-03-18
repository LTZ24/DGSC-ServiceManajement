import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/app_log_service.dart';

class AdminLogScreen extends StatefulWidget {
  const AdminLogScreen({super.key});

  @override
  State<AdminLogScreen> createState() => _AdminLogScreenState();
}

class _AdminLogScreenState extends State<AdminLogScreen> {
  bool _loading = true;
  List<_LogEntry> _entries = const [];
  String? _filterLevel;

  static const _levels = ['ERROR', 'WARN', 'INFO', 'SUCCESS'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final text = await AppLogService.readAll();
    final entries = _parseEntries(text);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  List<_LogEntry> _parseEntries(String raw) {
    final lines = raw.split('\n');
    final entries = <_LogEntry>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final match =
          RegExp(r'^\[(.+?)\]\s+\[(.+?)\]\s+(.*)$').firstMatch(line);
      if (match != null) {
        entries.add(_LogEntry(
          timestamp: match.group(1) ?? '',
          level: (match.group(2) ?? 'INFO').toUpperCase(),
          message: match.group(3) ?? '',
          details: '',
        ));
      } else if (entries.isNotEmpty) {
        final last = entries.removeLast();
        entries.add(last.copyWith(
          details: last.details.isEmpty ? line : '${last.details}\n$line',
        ));
      } else {
        entries.add(_LogEntry(
            timestamp: '', level: 'INFO', message: line, details: ''));
      }
    }

    return entries.reversed.toList();
  }

  List<_LogEntry> get _filtered {
    if (_filterLevel == null) return _entries;
    return _entries.where((e) => e.level == _filterLevel).toList();
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'ERROR':
        return AppTheme.dangerColor;
      case 'WARN':
      case 'WARNING':
        return AppTheme.warningColor;
      case 'SUCCESS':
        return AppTheme.successColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case 'ERROR':
        return Icons.error_outline_rounded;
      case 'WARN':
      case 'WARNING':
        return Icons.warning_amber_rounded;
      case 'SUCCESS':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Future<void> _download() async {
    final file = await AppLogService.getLogFile();
    if (!mounted) return;
    if (file == null) {
      _snack(context.tr('File log tidak ditemukan.', 'Log file not found.'),
          isError: true);
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'DGSC app log'),
      );
    } catch (_) {
      if (!mounted) return;
      _snack(context.tr('Gagal mengekspor log.', 'Failed to export log.'),
          isError: true);
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Hapus Log', 'Clear Log')),
        content: Text(context.tr(
          'Semua log akan dihapus secara permanen. Lanjutkan?',
          'All logs will be permanently deleted. Continue?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Hapus', 'Clear')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AppLogService.clear();
      if (!mounted) return;
      _snack(context.tr('Log berhasil dihapus.', 'Log cleared.'));
      await _load();
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? AppTheme.dangerColor : AppTheme.successColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;

    final counts = <String, int>{};
    for (final e in _entries) {
      counts[e.level] = (counts[e.level] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Log Aplikasi', 'App Log')),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.tr('Refresh', 'Refresh'),
          ),
          IconButton(
            onPressed: _loading || _entries.isEmpty ? null : _download,
            icon: const Icon(Icons.download_rounded),
            tooltip: context.tr('Export', 'Export'),
          ),
          IconButton(
            onPressed: _loading || _entries.isEmpty ? null : _confirmClear,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: context.tr('Hapus Log', 'Clear Log'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Filter chips ──────────────────────────────
                if (_entries.isNotEmpty)
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      children: [
                        _FilterChip(
                          label: context.tr('Semua', 'All'),
                          count: _entries.length,
                          color: scheme.primary,
                          selected: _filterLevel == null,
                          onTap: () => setState(() => _filterLevel = null),
                        ),
                        ..._levels
                            .where((l) => counts.containsKey(l))
                            .map((level) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _FilterChip(
                                    label: level,
                                    count: counts[level] ?? 0,
                                    color: _levelColor(level),
                                    selected: _filterLevel == level,
                                    onTap: () =>
                                        setState(() => _filterLevel = level),
                                  ),
                                )),
                      ],
                    ),
                  ),

                // ── Divider ───────────────────────────────────
                if (_entries.isNotEmpty) const Divider(height: 1),

                // ── List / empty state ────────────────────────
                Expanded(
                  child: _entries.isEmpty
                      ? _EmptyState(isDark: isDark)
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                context.tr(
                                  'Tidak ada log untuk level ini.',
                                  'No logs for this level.',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        color: scheme.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final entry = filtered[index];
                                return _LogCard(
                                  entry: entry,
                                  color: _levelColor(entry.level),
                                  icon: _levelIcon(entry.level),
                                  isDark: isDark,
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: use explicit, always-visible colors instead of scheme.surface
    final bgColor = isDark ? const Color(0xFF1E2530) : const Color(0xFFF0F4FF);
    final iconBg = AppTheme.primaryColor.withValues(alpha: 0.12);
    final textColor =
        isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87;
    final subColor =
        isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black54;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('Belum ada log.', 'No logs yet.'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'Log akan muncul saat ada aktivitas aplikasi.',
                  'Logs will appear when there is app activity.',
                ),
                style: TextStyle(fontSize: 13, color: subColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ FIX: explicit unselected bg that is visible in both themes
    final unselectedBg =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final unselectedFg =
        isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : unselectedBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : unselectedFg,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.20)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : unselectedFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Log card
// ─────────────────────────────────────────────────────────────

class _LogCard extends StatefulWidget {
  const _LogCard({
    required this.entry,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  final _LogEntry entry;
  final Color color;
  final IconData icon;
  final bool isDark;

  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard> {
  bool _expanded = false;

  bool get _hasDetails => widget.entry.details.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final color = widget.color;
    final isDark = widget.isDark;

    // ✅ FIX: card uses an explicit color that contrasts with the scaffold.
    // In M3, scaffoldBackgroundColor == scheme.surface, so using surface on
    // the card makes it invisible. We use surfaceContainerLow/High instead.
    final cardColor = isDark
        ? const Color(0xFF1E2530) // dark: slightly lighter than scaffold
        : Colors.white;           // light: pure white always visible
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final detailsBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final detailsBorder = color.withValues(alpha: 0.20);
    final tsColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.40);
    final msgColor = isDark
        ? Colors.white.withValues(alpha: 0.87)
        : Colors.black87;
    final detailsColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: _hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored side accent
              Container(width: 4, color: color),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: icon + badge + timestamp + expand arrow
                      Row(
                        children: [
                          Icon(widget.icon, color: color, size: 15),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              entry.level,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fmtTs(entry.timestamp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: tsColor),
                            ),
                          ),
                          if (_hasDetails)
                            Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: tsColor,
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Message
                      SelectableText(
                        entry.message,
                        style:
                            TextStyle(fontSize: 13, height: 1.4, color: msgColor),
                      ),

                      // Details (expandable)
                      if (_hasDetails && _expanded) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: detailsBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: detailsBorder),
                          ),
                          child: SelectableText(
                            entry.details,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: detailsColor,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtTs(String ts) {
    if (ts.isEmpty) return '';
    try {
      final dt = DateTime.parse(ts).toLocal();
      String p(int v) => v.toString().padLeft(2, '0');
      return '${dt.year}-${p(dt.month)}-${p(dt.day)}  ${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
    } catch (_) {
      return ts;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────

class _LogEntry {
  final String timestamp;
  final String level;
  final String message;
  final String details;

  const _LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.details,
  });

  _LogEntry copyWith({String? details}) => _LogEntry(
        timestamp: timestamp,
        level: level,
        message: message,
        details: details ?? this.details,
      );
}