import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/firebase_db_service.dart';
import '../../widgets/app_drawer.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});
  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 20, left: 20, right: 20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tambah Pelanggan',
                      style: Theme.of(ctx).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Membuat akun baru untuk pelanggan',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),
                  if (errorMsg != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(errorMsg!, style: const TextStyle(color: AppTheme.dangerColor, fontSize: 12)),
                    ),
                  TextFormField(controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nama / Username *', prefixIcon: Icon(Icons.person)),
                      validator: (v) => v?.isEmpty == true ? 'Wajib diisi' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: emailCtrl, keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email *', prefixIcon: Icon(Icons.email)),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib diisi';
                        if (!v.contains('@')) return 'Format email tidak valid';
                        return null;
                      }),
                  const SizedBox(height: 12),
                  TextFormField(controller: passwordCtrl, obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password *', prefixIcon: Icon(Icons.lock)),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib diisi';
                        if (v.length < 6) return 'Minimal 6 karakter';
                        return null;
                      }),
                  const SizedBox(height: 12),
                  TextFormField(controller: phoneCtrl, keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'No. HP', prefixIcon: Icon(Icons.phone))),
                  const SizedBox(height: 12),
                  TextFormField(controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'Alamat (opsional)', prefixIcon: Icon(Icons.location_on))),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() { isLoading = true; errorMsg = null; });
                        try {
                          await FirebaseDbService.register(
                            email: emailCtrl.text.trim(),
                            password: passwordCtrl.text,
                            username: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                            role: 'customer',
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Akun pelanggan berhasil dibuat'), backgroundColor: AppTheme.successColor));
                          }
                        } catch (e) {
                          setModalState(() { errorMsg = e.toString().replaceAll('[firebase_auth/', '').replaceAll(']', ''); isLoading = false; });
                        }
                      },
                      child: isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Buat Akun Pelanggan'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pelanggan')),
      drawer: const AppDrawer(isAdmin: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseDbService.customersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data?.docs ?? [];
          final query = _searchCtrl.text.toLowerCase();
          if (query.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['name'] ?? '').toString().toLowerCase().contains(query) ||
                  (data['phone'] ?? '').toString().contains(query) ||
                  (data['email'] ?? '').toString().toLowerCase().contains(query);
            }).toList();
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    hintText: 'Cari nama, HP, email...',
                    prefixIcon: Icon(Icons.search)),
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text('Tidak ada pelanggan',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              child: Text(
                                (data['name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(data['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            subtitle: Text(
                                '${data["phone"] ?? "-"} | ${data["email"] ?? "-"}',
                                style: const TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppTheme.dangerColor),
                              onPressed: () async {
                                await FirebaseDbService.deleteCustomer(doc.id);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}