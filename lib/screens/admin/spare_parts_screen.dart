import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/backend_service.dart';
import '../../services/backend_types.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_list_card.dart';

class AdminSparePartsScreen extends StatefulWidget {
  const AdminSparePartsScreen({super.key});

  @override
  State<AdminSparePartsScreen> createState() => _AdminSparePartsScreenState();
}

class _AdminSparePartsScreenState extends State<AdminSparePartsScreen> {
  static const List<Map<String, String>> _partCategories = [
    {'name': 'LCD', 'code': 'LCD'},
    {'name': 'PCB', 'code': 'PCB'},
    {'name': 'IC', 'code': 'IC'},
    {'name': 'Flexible', 'code': 'FLX'},
    {'name': 'Battery', 'code': 'BAT'},
    {'name': 'Camera', 'code': 'CAM'},
    {'name': 'Charger Port', 'code': 'CHG'},
    {'name': 'Housing', 'code': 'HSG'},
    {'name': 'Lainnya', 'code': 'DLL'},
  ];

  bool _showLowStock = false;
  final _searchCtrl = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _sparePartsStream;
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _sparePartsStream = BackendService.sparePartsStream();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshSpareParts() async {
    if (!mounted) return;
    setState(() {});
  }

  String _buildPartCode(String categoryCode, String name) {
    final cleanedName = name.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), ' ');
    final slug = cleanedName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.length >= 3 ? part.substring(0, 3) : part)
        .join();
    final date = DateTime.now();
    final stamp = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return '$categoryCode-${slug.isEmpty ? 'PART' : slug}-$stamp';
  }

  void _showCreateEditDialog(BuildContext context,
      {DocumentSnapshot<Map<String, dynamic>>? doc}) {
    final data = doc?.data();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: data?['part_name'] ?? '');
    final stockCtrl =
        TextEditingController(text: (data?['stock_quantity'] ?? 0).toString());
    final priceCtrl =
        TextEditingController(text: (data?['unit_price'] ?? 0).toString());
    final supplierCtrl = TextEditingController(text: data?['supplier'] ?? '');
    final minStockCtrl = TextEditingController(
      text: (data?['minimum_stock'] ?? 5).toString(),
    );
    String selectedCategory = (data?['category'] ?? _partCategories.first['name'])
        .toString();
    String selectedCategoryCode = (data?['category_code'] ?? _partCategories.first['code'])
        .toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  doc != null
                      ? ctx.tr('Edit Spare Part', 'Edit Spare Part')
                      : ctx.tr('Tambah Spare Part', 'Add Spare Part'),
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Nama Part', 'Part Name'),
                  ),
                  validator: (v) => v?.trim().isEmpty == true
                      ? context.tr('Wajib', 'Required')
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: context.tr('Kategori', 'Category'),
                  ),
                  items: _partCategories
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item['name'],
                          child: Text(item['name']!),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    final category = _partCategories.firstWhere(
                      (item) => item['name'] == value,
                      orElse: () => _partCategories.first,
                    );
                    selectedCategory = category['name']!;
                    selectedCategoryCode = category['code']!;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${context.tr('Kode part', 'Part code')}: ${doc != null ? (data?['part_code'] ?? '-') : _buildPartCode(selectedCategoryCode, nameCtrl.text)}',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('Stok', 'Stock'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: minStockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('Min Stok', 'Min Stock'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr('Harga Satuan', 'Unit Price'),
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: supplierCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Supplier', 'Supplier'),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final snackLabel = doc != null
                        ? ctx.tr('Diperbarui', 'Updated')
                        : ctx.tr('Ditambahkan', 'Added');
                    final partCode = doc != null
                        ? (data?['part_code'] ?? _buildPartCode(selectedCategoryCode, nameCtrl.text))
                        : _buildPartCode(selectedCategoryCode, nameCtrl.text);
                    final partData = {
                      'part_name': nameCtrl.text.trim(),
                      'category': selectedCategory,
                      'category_code': selectedCategoryCode,
                      'part_code': partCode,
                      'stock_quantity': int.tryParse(stockCtrl.text) ?? 0,
                      'unit_price': double.tryParse(priceCtrl.text) ?? 0.0,
                      'supplier': supplierCtrl.text.trim(),
                      'minimum_stock': int.tryParse(minStockCtrl.text) ?? 5,
                    };
                    if (doc != null) {
                      await BackendService.updateSparePart(doc.id, partData);
                    } else {
                      await BackendService.addSparePart(partData);
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(snackLabel)),
                    );
                  },
                  child: Text(context.tr('Simpan', 'Save')),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Spare Part', 'Spare Parts')),
        actions: [
          IconButton(
            icon: Icon(
              _showLowStock ? Icons.warning : Icons.warning_outlined,
              color: _showLowStock ? Colors.yellow : Colors.white,
            ),
            tooltip: context.tr('Stok Menipis', 'Low Stock'),
            onPressed: () => setState(() => _showLowStock = !_showLowStock),
          ),
        ],
      ),
      drawer: const AppDrawer(isAdmin: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEditDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _sparePartsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (_showLowStock) {
            docs = docs.where((d) {
              final data = d.data();
              return (data['stock_quantity'] as int? ?? 0) <
                  (data['minimum_stock'] as int? ?? 5);
            }).toList();
          }
          final query = _searchCtrl.text.toLowerCase();
          if (query.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data();
              return (data['part_name'] ?? '').toString().toLowerCase().contains(query) ||
                  (data['category'] ?? '').toString().toLowerCase().contains(query) ||
                  (data['part_code'] ?? '').toString().toLowerCase().contains(query);
            }).toList();
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: context.tr(
                      'Cari nama, kategori, kode part...',
                      'Search name, category, part code...',
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator.adaptive(
                  onRefresh: _refreshSpareParts,
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
                                    'Tidak ada spare part',
                                    'No spare parts',
                                  ),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final stock = data['stock_quantity'] as int? ?? 0;
                            final minStock = data['minimum_stock'] as int? ?? 5;
                            return AppListCard(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: stock < minStock
                                      ? AppTheme.dangerColor
                                          .withValues(alpha: 0.15)
                                      : AppTheme.successColor
                                          .withValues(alpha: 0.15),
                                  child: Text(
                                    '$stock',
                                    style: TextStyle(
                                      color: stock < minStock
                                          ? AppTheme.dangerColor
                                          : AppTheme.successColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  data['part_name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${data['part_code'] ?? '-'} • ${data['category'] ?? '-'} • ${currencyFormat.format((data['unit_price'] as num? ?? 0).toDouble())}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _showCreateEditDialog(
                                        context,
                                        doc: doc,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppTheme.dangerColor,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          BackendService.deleteSparePart(doc.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
