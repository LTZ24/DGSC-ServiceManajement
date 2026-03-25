import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/diagnosis_config_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/diagnosis_dialog.dart';

class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen({super.key});

  static const _guestLoginArguments = {'role': 'customer'};

  Future<void> _refreshDiagnosis() async {
    await DiagnosisConfigService.syncPublishedDataset();
  }

  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;
    final isGuest = routeName == '/diagnosis';

    final content = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isGuest
          ? null
          : AppBar(
              title:
                  Text(context.tr('Diagnosis Kerusakan', 'Damage Diagnosis')),
            ),
      drawer: isGuest ? null : const AppDrawer(isAdmin: false),
      body: RefreshIndicator.adaptive(
        onRefresh: _refreshDiagnosis,
        child: _DiagnosisLanding(
          isGuest: isGuest,
          onExitGuest: isGuest ? () => _exitGuest(context) : null,
          onStartDiagnosis: () => _openDiagnosis(context),
        ),
      ),
    );

    if (!isGuest) return content;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _exitGuest(context);
        }
      },
      child: content,
    );
  }

  void _openDiagnosis(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => DiagnosisDialog(
        onResultSelected: (results, category, symptoms) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'Diagnosis selesai! Anda dapat menggunakan hasil ini saat booking.',
                  'Diagnosis complete! You can use this result when booking.',
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _exitGuest(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
      arguments: _guestLoginArguments,
    );
  }
}

class _DiagnosisLanding extends StatelessWidget {
  const _DiagnosisLanding({
    required this.isGuest,
    required this.onStartDiagnosis,
    this.onExitGuest,
  });

  final bool isGuest;
  final VoidCallback onStartDiagnosis;
  final VoidCallback? onExitGuest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleColor =
        isDark ? AppTheme.darkMutedText : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFD7E0EC);
    final cardColor = isDark ? AppTheme.darkSurface : Colors.white;
    final secondaryCardColor =
        isDark ? AppTheme.darkSurfaceAlt : const Color(0xFFF8FAFC);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF081120),
                  Color(0xFF0C1628),
                  Color(0xFF111B2E),
                ]
              : const [
                  Color(0xFFF4F8FF),
                  Color(0xFFF8FBFF),
                  Color(0xFFFFFFFF),
                ],
        ),
      ),
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            size: 18,
                            color: Color(0xFF1D4ED8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.tr(
                              isGuest ? 'Diagnosis Guest' : 'Diagnosis Cepat',
                              isGuest ? 'Guest Diagnosis' : 'Quick Diagnosis',
                            ),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isGuest)
                      TextButton.icon(
                        onPressed: onExitGuest,
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(context.tr('Keluar', 'Exit')),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1E293B),
                          backgroundColor: Colors.white.withValues(alpha: 0.92),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(color: borderColor),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 700;
                          final titleBlock = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr(
                                  'Diagnosis Kerusakan Perangkat',
                                  'Device Damage Diagnosis',
                                ),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                context.tr(
                                  'Pilih jenis perangkat, tandai gejala yang muncul, lalu sistem akan menampilkan kemungkinan kerusakan beserta estimasi solusi.',
                                  'Choose your device type, mark the symptoms, and the system will show the most likely damage and the suggested solution.',
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: subtitleColor,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          );

                          final heroIcon = Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1D4ED8),
                                  Color(0xFF0EA5E9),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.monitor_heart_outlined,
                              color: Colors.white,
                              size: 34,
                            ),
                          );

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                heroIcon,
                                const SizedBox(width: 18),
                                Expanded(child: titleBlock),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              heroIcon,
                              const SizedBox(height: 16),
                              titleBlock,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StepCard(
                            number: '1',
                            title: context.tr(
                              'Pilih Perangkat',
                              'Choose Device',
                            ),
                            subtitle: context.tr(
                              'HP, tablet, atau laptop.',
                              'Phone, tablet, or laptop.',
                            ),
                            color: const Color(0xFFE0F2FE),
                            accent: const Color(0xFF0284C7),
                          ),
                          _StepCard(
                            number: '2',
                            title: context.tr('Pilih Gejala', 'Pick Symptoms'),
                            subtitle: context.tr(
                              'Centang gejala yang dirasakan.',
                              'Check the symptoms you notice.',
                            ),
                            color: const Color(0xFFDCFCE7),
                            accent: const Color(0xFF16A34A),
                          ),
                          _StepCard(
                            number: '3',
                            title: context.tr('Lihat Hasil', 'Review Result'),
                            subtitle: context.tr(
                              'Dapatkan hasil dan saran awal.',
                              'Get the initial diagnosis and advice.',
                            ),
                            color: const Color(0xFFFFF7ED),
                            accent: const Color(0xFFEA580C),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: secondaryCardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                'Yang akan Anda dapatkan',
                                'What You Will Get',
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _BenefitRow(
                              icon: Icons.insights_outlined,
                              text: context.tr(
                                'Estimasi tingkat kemungkinan kerusakan.',
                                'Estimated probability of the damage.',
                              ),
                              color: const Color(0xFF1D4ED8),
                            ),
                            const SizedBox(height: 10),
                            _BenefitRow(
                              icon: Icons.lightbulb_outline_rounded,
                              text: context.tr(
                                'Saran solusi awal sebelum servis.',
                                'Initial solution suggestions before service.',
                              ),
                              color: const Color(0xFF16A34A),
                            ),
                            const SizedBox(height: 10),
                            _BenefitRow(
                              icon: Icons.receipt_long_outlined,
                              text: context.tr(
                                'Bisa dipakai sebagai acuan saat booking servis.',
                                'Can be used as a reference when booking service.',
                              ),
                              color: const Color(0xFFEA580C),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onStartDiagnosis,
                          icon: const Icon(Icons.search_rounded),
                          label: Text(
                            context.tr('Mulai Diagnosis', 'Start Diagnosis'),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr(
                          isGuest
                              ? 'Keluar dari halaman ini akan kembali ke login customer.'
                              : 'Gunakan hasil diagnosis untuk membantu proses booking atau konsultasi servis.',
                          isGuest
                              ? 'Leaving this page will take you back to customer login.'
                              : 'Use the diagnosis result to support booking or service consultation.',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtitleColor,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.accent,
  });

  final String number;
  final String title;
  final String subtitle;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF334155),
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
          ),
        ),
      ],
    );
  }
}
