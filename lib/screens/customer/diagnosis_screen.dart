import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/diagnosis_dialog.dart';

class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnosis Kerusakan')),
      drawer: const AppDrawer(isAdmin: false),
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
                'Diagnosis Kerusakan',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gunakan sistem pakar Certainty Factor untuk mendiagnosis kerusakan perangkat Anda secara otomatis.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
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
                            const SnackBar(
                              content: Text('Diagnosis selesai! Anda dapat menggunakan hasil ini saat booking.'),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Mulai Diagnosis'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
