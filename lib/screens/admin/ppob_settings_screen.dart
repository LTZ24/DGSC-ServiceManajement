import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/backend_service.dart';
import '../../services/backend_types.dart';
import '../../services/ppob_catalog_service.dart';

class PpobSettingsScreen extends StatefulWidget {
  const PpobSettingsScreen({super.key});

  @override
  State<PpobSettingsScreen> createState() => _PpobSettingsScreenState();
}

class _PpobSettingsScreenState extends State<PpobSettingsScreen> {
  String? _backupPath;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await BackendService.ensurePpobMasterData();
    final backupPath = await PpobCatalogService.getBackupDirectoryPath();
    if (mounted) {
      setState(() => _backupPath = backupPath);
    }
  }

  Future<void> _showAppDialog({Map<String, dynamic>? data}) async {
    final isEdit = data != null;
    final idCtrl =
        TextEditingController(text: data?['id_aplikasi']?.toString() ?? '');
    final nameCtrl =
        TextEditingController(text: data?['nama_aplikasi']?.toString() ?? '');
    final typeCtrl =
        TextEditingController(text: data?['jenis_layanan']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr(
          isEdit ? 'Edit Aplikasi PPOB' : 'Tambah Aplikasi PPOB',
          isEdit ? 'Edit PPOB App' : 'Add PPOB App',
        )),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: idCtrl,
                  enabled: !isEdit,
                  decoration: InputDecoration(
                      labelText: context.tr('Kode aplikasi', 'App code')),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.tr('Wajib diisi', 'Required')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                      labelText: context.tr('Nama aplikasi', 'App name')),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.tr('Wajib diisi', 'Required')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: typeCtrl,
                  decoration: InputDecoration(
                      labelText: context.tr('Jenis layanan', 'Service type')),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final payload = {
                  'id_aplikasi': idCtrl.text.trim(),
                  'nama_aplikasi': nameCtrl.text.trim(),
                  'jenis_layanan': typeCtrl.text.trim(),
                };
                if (isEdit) {
                  await BackendService.updatePpobApp(
                      data['id_aplikasi'].toString(), payload);
                } else {
                  await BackendService.addPpobApp(payload);
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: Text(context.tr('Simpan', 'Save')),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryDialog({Map<String, dynamic>? data}) async {
    final isEdit = data != null;
    final idCtrl =
        TextEditingController(text: data?['id_kategori']?.toString() ?? '');
    final nameCtrl =
        TextEditingController(text: data?['nama_kategori']?.toString() ?? '');
    String transactionType = (data?['tipe_transaksi'] ?? 'prabayar').toString();
    final formKey = GlobalKey<FormState>();
    const types = [
      'prabayar',
      'pascabayar',
      'pembayaran_kode',
      'pemesanan',
      'transaksi_agen'
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: Text(context.tr(
            isEdit ? 'Edit Kategori' : 'Tambah Kategori',
            isEdit ? 'Edit Category' : 'Add Category',
          )),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: idCtrl,
                    enabled: !isEdit,
                    decoration: InputDecoration(
                        labelText:
                            context.tr('Kode kategori', 'Category code')),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.tr('Wajib diisi', 'Required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                        labelText:
                            context.tr('Nama kategori', 'Category name')),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.tr('Wajib diisi', 'Required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: transactionType,
                    decoration: InputDecoration(
                        labelText:
                            context.tr('Jenis transaksi', 'Transaction type')),
                    items: types
                        .map((item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => transactionType = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: Text(context.tr('Batal', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final payload = {
                    'id_kategori': idCtrl.text.trim(),
                    'nama_kategori': nameCtrl.text.trim(),
                    'tipe_transaksi': transactionType,
                  };
                  if (isEdit) {
                    await BackendService.updatePpobCategory(
                        data['id_kategori'].toString(), payload);
                  } else {
                    await BackendService.addPpobCategory(payload);
                  }
                  if (!ctx2.mounted) return;
                  Navigator.pop(ctx2);
                } catch (e) {
                  if (!ctx2.mounted) return;
                  ScaffoldMessenger.of(ctx2).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: Text(context.tr('Simpan', 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showServiceDialog({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> categories,
    Map<String, dynamic>? data,
  }) async {
    final isEdit = data != null;
    final idCtrl =
        TextEditingController(text: data?['id_layanan']?.toString() ?? '');
    final nameCtrl =
        TextEditingController(text: data?['nama_layanan']?.toString() ?? '');
    final overrideCtrl =
        TextEditingController(text: data?['tipe_override']?.toString() ?? '');
    String selectedCategory = (data?['category_id'] ??
            (categories.isNotEmpty ? categories.first.id : ''))
        .toString();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: Text(context.tr(
            isEdit ? 'Edit Layanan' : 'Tambah Layanan',
            isEdit ? 'Edit Service' : 'Add Service',
          )),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue:
                        selectedCategory.isEmpty ? null : selectedCategory,
                    decoration: InputDecoration(
                        labelText: context.tr('Kategori', 'Category')),
                    items: categories
                        .map((item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(
                                  item.data()['nama_kategori']?.toString() ??
                                      ''),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedCategory = value);
                      }
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? context.tr('Wajib diisi', 'Required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: idCtrl,
                    enabled: !isEdit,
                    decoration: InputDecoration(
                        labelText: context.tr('Kode layanan', 'Service code')),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.tr('Wajib diisi', 'Required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                        labelText: context.tr('Nama layanan', 'Service name')),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.tr('Wajib diisi', 'Required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: overrideCtrl,
                    decoration: InputDecoration(
                        labelText: context.tr(
                            'Override tipe transaksi (opsional)',
                            'Transaction type override (optional)')),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: Text(context.tr('Batal', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final payload = {
                    'id_layanan': idCtrl.text.trim(),
                    'category_id': selectedCategory,
                    'nama_layanan': nameCtrl.text.trim(),
                    'tipe_override': overrideCtrl.text.trim(),
                  };
                  if (isEdit) {
                    await BackendService.updatePpobService(
                        data['id_layanan'].toString(), payload);
                  } else {
                    await BackendService.addPpobService(payload);
                  }
                  if (!ctx2.mounted) return;
                  Navigator.pop(ctx2);
                } catch (e) {
                  if (!ctx2.mounted) return;
                  ScaffoldMessenger.of(ctx2).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: Text(context.tr('Simpan', 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Pengaturan PPOB', 'PPOB Settings')),
          actions: [
            IconButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/admin/ppob-receipt-settings'),
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: context.tr('Pengaturan Struk', 'Receipt Settings'),
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: context.tr('Aplikasi', 'Apps')),
              Tab(text: context.tr('Jenis Transaksi', 'Transaction Types')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAppsTab(),
            _buildCategoriesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: BackendService.ppobAppsStream(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('Provider Aplikasi PPOB',
                                'PPOB Application Providers'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showAppDialog(),
                          icon: const Icon(Icons.add),
                          label: Text(context.tr('Tambah', 'Add')),
                        ),
                      ],
                    ),
                    if (_backupPath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${context.tr('Backup lokal', 'Local backup')}: $_backupPath',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          'Backup JSON akan ikut diperbarui saat data aplikasi, kategori, atau layanan PPOB diubah.',
                          'JSON backup will be updated automatically when PPOB app, category, or service data changes.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final data = doc.data();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.12),
                    child: const Icon(Icons.apps_rounded,
                        color: AppTheme.primaryColor),
                  ),
                  title: Text(data['nama_aplikasi']?.toString() ?? ''),
                  subtitle: Text(
                    '${data['id_aplikasi'] ?? ''} • ${data['jenis_layanan'] ?? ''}',
                  ),
                  trailing: IconButton(
                    onPressed: () => _showAppDialog(data: data),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildCategoriesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: BackendService.ppobCategoriesStream(),
      builder: (context, categorySnapshot) {
        final categoryDocs = categorySnapshot.data?.docs ?? [];
        return StreamBuilder<QuerySnapshot>(
          stream: BackendService.ppobServicesStream(),
          builder: (context, serviceSnapshot) {
            final serviceDocs = serviceSnapshot.data?.docs ?? [];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr(
                              'Kategori & Layanan', 'Categories & Services'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showCategoryDialog(),
                              icon: const Icon(Icons.category_outlined),
                              label: Text(context.tr(
                                  'Tambah Kategori', 'Add Category')),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: categoryDocs.isEmpty
                                  ? null
                                  : () => _showServiceDialog(
                                      categories: categoryDocs),
                              icon: const Icon(Icons.add_box_outlined),
                              label: Text(
                                  context.tr('Tambah Layanan', 'Add Service')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...categoryDocs.map((categoryDoc) {
                  final categoryData = categoryDoc.data();
                  final services = serviceDocs
                      .where((serviceDoc) =>
                          serviceDoc.data()['category_id'] == categoryDoc.id)
                      .toList();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      title:
                          Text(categoryData['nama_kategori']?.toString() ?? ''),
                      subtitle: Text(
                        '${categoryData['id_kategori'] ?? ''} • ${categoryData['tipe_transaksi'] ?? ''}',
                      ),
                      trailing: IconButton(
                        onPressed: () =>
                            _showCategoryDialog(data: categoryData),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      children: [
                        if (services.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                context.tr(
                                    'Belum ada layanan', 'No services yet'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          )
                        else
                          ...services.map((serviceDoc) {
                            final serviceData = serviceDoc.data();
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                  Icons.subdirectory_arrow_right_rounded),
                              title: Text(
                                  serviceData['nama_layanan']?.toString() ??
                                      ''),
                              subtitle: Text(
                                '${serviceData['id_layanan'] ?? ''}${(serviceData['tipe_override'] ?? '').toString().isEmpty ? '' : ' • ${serviceData['tipe_override']}'}',
                              ),
                              trailing: IconButton(
                                onPressed: () => _showServiceDialog(
                                  categories: categoryDocs,
                                  data: serviceData,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}
