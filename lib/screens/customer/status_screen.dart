import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/firebase_db_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/status_badge.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});
  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseDbService.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Servis'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Booking'), Tab(text: 'Servis')],
        ),
      ),
      drawer: const AppDrawer(isAdmin: false),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Bookings tab
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseDbService.userBookingsStream(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Belum ada booking', style: TextStyle(color: Colors.grey)),
                  ],
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${data["device_type"] ?? ""} - ${data["brand"] ?? ""} ${data["model"] ?? ""}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              StatusBadge(status: status),
                            ],
                          ),
                          if ((data['issue_description'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(data['issue_description'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          ],
                          if ((data['preferred_date'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(data['preferred_date'],
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ]),
                          ],
                          if ((data['diagnosis_result'] ?? '').toString().isNotEmpty) ...[
                            const Divider(),
                            Row(children: [
                              const Icon(Icons.medical_services, size: 14, color: Colors.blue),
                              const SizedBox(width: 4),
                              Expanded(child: Text(data['diagnosis_result'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.blue))),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Services tab
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseDbService.userServicesStream(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.build, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Belum ada servis', style: TextStyle(color: Colors.grey)),
                  ],
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: const Icon(Icons.build, color: AppTheme.primaryColor),
                      ),
                      title: Text('${data["device_brand"] ?? ""} ${data["model"] ?? ""}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['service_code'] ?? '',
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          if ((data['technician'] ?? '').toString().isNotEmpty)
                            Text('Teknisi: ${data["technician"]}',
                                style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: StatusBadge(status: status),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}