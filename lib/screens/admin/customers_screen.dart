import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/backend_types.dart';
import '../../services/backend_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_list_card.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});
  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final _searchCtrl = TextEditingController();
  late final Stream<QuerySnapshot> _customersStream;
  List<QueryDocumentSnapshot> _cachedDocs = const [];

  @override
  void initState() {
    super.initState();
    _customersStream = BackendService.customersStream();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshCustomers() async {
    if (!mounted) return;
    setState(() {});
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
              top: 20,
              left: 20,
              right: 20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('Tambah Pelanggan', 'Add Customer'),
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                    Text(context.tr('Membuat akun baru untuk pelanggan', 'Create a new account for a customer'),
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
                      child: Text(errorMsg!,
                          style: const TextStyle(
                              color: AppTheme.dangerColor, fontSize: 12)),
                    ),
                  TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: context.tr('Nama / Username *', 'Name / Username *'),
                      prefixIcon: const Icon(Icons.person)),
                      validator: (v) =>
                            v?.isEmpty == true ? context.tr('Wajib diisi', 'Required') : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: context.tr('Email *', 'Email *'), prefixIcon: const Icon(Icons.email)),
                      validator: (v) {
                        if (v == null || v.isEmpty) return context.tr('Wajib diisi', 'Required');
                        if (!v.contains('@')) return context.tr('Format email tidak valid', 'Invalid email format');
                        return null;
                      }),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: context.tr('Password *', 'Password *'),
                        prefixIcon: const Icon(Icons.lock)),
                      validator: (v) {
                        if (v == null || v.isEmpty) return context.tr('Wajib diisi', 'Required');
                        if (v.length < 6) return context.tr('Minimal 6 karakter', 'Minimum 6 characters');
                        return null;
                      }),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: context.tr('No. HP', 'Phone Number'), prefixIcon: const Icon(Icons.phone))),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: addressCtrl,
                      decoration: InputDecoration(
                          labelText: context.tr('Alamat (opsional)', 'Address (optional)'),
                        prefixIcon: const Icon(Icons.location_on))),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() {
                                isLoading = true;
                                errorMsg = null;
                              });
                              try {
                                await BackendService.register(
                                  email: emailCtrl.text.trim(),
                                  password: passwordCtrl.text,
                                  username: nameCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                  address: addressCtrl.text.trim().isEmpty
                                      ? null
                                      : addressCtrl.text.trim(),
                                  role: 'customer',
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr('Akun pelanggan berhasil dibuat', 'Customer account created successfully')),
                                          backgroundColor:
                                              AppTheme.successColor));
                                }
                              } catch (e) {
                                setModalState(() {
                                  errorMsg = e.toString();
                                  isLoading = false;
                                });
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(context.tr('Buat Akun Pelanggan', 'Create Customer Account')),
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
      appBar: AppBar(title: Text(context.tr('Pelanggan', 'Customers'))),
      drawer: const AppDrawer(isAdmin: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _customersStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedDocs = snapshot.data!.docs;
          }
          final sourceDocs = snapshot.data?.docs ?? _cachedDocs;
          if (snapshot.connectionState == ConnectionState.waiting &&
              sourceDocs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = sourceDocs;
          final query = _searchCtrl.text.toLowerCase();
          if (query.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data();
              return (data['name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(query) ||
                  (data['phone'] ?? '').toString().contains(query) ||
                  (data['email'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(query);
            }).toList();
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.tr('Cari nama, HP, email...', 'Search name, phone, email...'),
                  prefixIcon: const Icon(Icons.search)),
              ),
            ),
            Expanded(
              child: RefreshIndicator.adaptive(
                onRefresh: _refreshCustomers,
                child: docs.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: Center(
                              child: Text(
                                context.tr(
                                  'Tidak ada pelanggan',
                                  'No customers',
                                ),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          return AppListCard(
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
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(
                                  '${data["phone"] ?? "-"} | ${data["email"] ?? "-"}',
                                  style: const TextStyle(fontSize: 12)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.dangerColor),
                                onPressed: () async {
                                  await BackendService.deleteCustomer(doc.id);
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
