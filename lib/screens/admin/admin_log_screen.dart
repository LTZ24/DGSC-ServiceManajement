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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

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
      final match = RegExp(r'^\[(.+?)\]\s+\[(.+?)\]\s+(.*)$').firstMatch(line);
      if (match != null) {
        entries.add(_LogEntry(
          timestamp: match.group(1) ?? '',
          level: (match.group(2) ?? 'INFO').toUpperCase(),
          message: match.group(3) ?? '',
          details: '',
        ));
      } else if (entries.isNotEmpty) {
        final last = entries.removeLast();
        final nextDetails = last.details.isEmpty ? line : '${last.details}\n$line';
        entries.add(last.copyWith(details: nextDetails));
      } else {
        entries.add(_LogEntry(
          timestamp: '',
          level: 'INFO',
          message: line,
          details: '',
        ));
      }
    }

    return entries.reversed.toList();
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
      case 'INFO':
      default:
        return AppTheme.primaryColor;
    }
  }

  Future<void> _download() async {
    final file = await AppLogService.getLogFile();
    if (!mounted) return;

    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('File log tidak ditemukan.', 'Log file not found.')),
        backgroundColor: AppTheme.dangerColor,
      ));
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'DGSC app log',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('Gagal mengunduh log.', 'Failed to export log.')),
        backgroundColor: AppTheme.dangerColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Log', 'Log')),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('Refresh', 'Refresh'),
          ),
          IconButton(
            onPressed: _download,
            icon: const Icon(Icons.download),
            tooltip: context.tr('Download', 'Download'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppTheme.primaryColor.withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.receipt_long,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.tr('Belum ada log aplikasi.', 'No app logs yet.'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final color = _levelColor(entry.level);

                    return Container(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 6,
                              color: color,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                color.withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            entry.level,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: color,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            entry.timestamp,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SelectableText(
                                      entry.message,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(height: 1.25),
                                    ),
                                    if (entry.details.trim().isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerHighest
                                              .withValues(alpha: 0.6),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: color
                                                .withValues(alpha: 0.20),
                                          ),
                                        ),
                                        child: SelectableText(
                                          entry.details,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                height: 1.25,
                                                color: scheme.onSurfaceVariant,
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
                    );
                  },
                ),
    );
  }
}

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

  _LogEntry copyWith({String? details}) {
    return _LogEntry(
      timestamp: timestamp,
      level: level,
      message: message,
      details: details ?? this.details,
    );
  }
}
