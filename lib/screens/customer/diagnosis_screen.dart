import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/diagnosis_dialog.dart';

class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;
    final isGuest = routeName == '/diagnosis';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor =
        isDark ? AppTheme.darkMutedText : const Color(0xFF667085);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Diagnosis Kerusakan', 'Damage Diagnosis'))),
      drawer: AppDrawer(isAdmin: false, isGuest: isGuest),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.medical_services_outlined,
                size: 100,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('Diagnosis Kerusakan', 'Damage Diagnosis'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('Gunakan sistem pakar Certainty Factor untuk mendiagnosis kerusakan perangkat Anda secara otomatis.', 'Use the Certainty Factor expert system to diagnose your device problems automatically.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: subtitleColor),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => DiagnosisDialog(
                        onResultSelected: (results, category, symptoms) {
                          // Optionally navigate to booking with results
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  context.tr('Diagnosis selesai! Anda dapat menggunakan hasil ini saat booking.', 'Diagnosis complete! You can use this result when booking.')),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.search),
                  label: Text(context.tr('Mulai Diagnosis', 'Start Diagnosis')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
