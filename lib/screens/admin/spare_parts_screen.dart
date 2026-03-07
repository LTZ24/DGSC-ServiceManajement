import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/firebase_db_service.dart';
import '../../widgets/app_drawer.dart';

class AdminSparePartsScreen extends StatefulWidget {
  const AdminSparePartsScreen({super.key});
  @override
  State<AdminSparePartsScreen> createState() => _AdminSparePartsScreenState();
}

class _AdminSparePartsScreenState extends State<AdminSparePartsScreen> {
  bool _showLowStock = false;
  final _searchCtrl = TextEditingController();
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showCreateEditDialog(BuildContext context, {DocumentSnapshot? doc}) {
    final data = doc != null ? doc.data() as Map<String, dynamic> : null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: data?['part_name'] ?? '');
    final categoryCtrl = TextEditingController(text: data?['category'] ?? '');
    final stockCtrl = TextEditingController(text: (data?['stock_quantity'] ?? 0).toString());
    final priceCtrl = TextEditingController(text: (data?['unit_price'] ?? 0).toString());
    final supplierCtrl = TextEditingController(text: data?['supplier'] ?? '');
    final minStockCtrl = TextEditingController(text: (data?['minimum_stock'] ?? 5).toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
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
                Text(doc != null ? 'Edit Spare Part' : 'Tambah Spare Part',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Part'),
                    validator: (v) => v?.isEmpty == true ? 'Wajib' : null),
                const SizedBox(height: 12),
                TextFormField(controller: categoryCtrl,
                    decoration: const InputDecoration(labelText: 'Kategori')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stok'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: minStockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min Stok'))),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Harga Satuan', prefixText: 'Rp ')),
                const SizedBox(height: 12),
                TextFormField(controller: supplierCtrl,
                    decoration: const InputDecoration(labelText: 'Supplier')),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final partData = {
                      'part_name': nameCtrl.text,
                      'category': categoryCtrl.text,
                      'stock_quantity': int.tryParse(stockCtrl.text) ?? 0,
                      'unit_price': double.tryParse(priceCtrl.text) ?? 0.0,
                      'supplier': supplierCtrl.text,
                      'minimum_stock': int.tryParse(minStockCtrl.text) ?? 5,
                    };
                    if (doc != null) {
                      await FirebaseDbService.updateSparePart(doc.id, partData);
                    } else {
                      await FirebaseDbService.addSparePart(partData);
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(doc != null ? 'Diperbarui' : 'Ditambahkan')));
                    }
                  },
                  child: const Text('Simpan'),
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
        title: const Text('Spare Part'),
        actions: [
          IconButton(
            icon: Icon(_showLowStock ? Icons.warning : Icons.warning_outlined,
                color: _showLowStock ? Colors.yellow : Colors.white),
            tooltip: 'Stok Menipis',
            onPressed: () => setState(() => _showLowStock = !_showLowStock),
          ),
        ],
      ),
      drawer: const AppDrawer(isAdmin: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEditDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseDbService.sparePartsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data?.docs ?? [];
          if (_showLowStock) {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['stock_quantity'] as int? ?? 0) <
                  (data['minimum_stock'] as int? ?? 5);
            }).toList();
          }
          final query = _searchCtrl.text.toLowerCase();
          if (query.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['part_name'] ?? '').toString().toLowerCase().contains(query) ||
                  (data['category'] ?? '').toString().toLowerCase().contains(query);
            }).toList();
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    hintText: 'Cari nama, kategori...',
                    prefixIcon: Icon(Icons.search)),
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text('Tidak ada spare part',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final stock = data['stock_quantity'] as int? ?? 0;
                        final minStock = data['minimum_stock'] as int? ?? 5;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: stock < minStock
                                  ? AppTheme.dangerColor.withValues(alpha: 0.15)
                                  : AppTheme.successColor.withValues(alpha: 0.15),
                              child: Text('$stock',
                                  style: TextStyle(
                                      color: stock < minStock
                                          ? AppTheme.dangerColor
                                          : AppTheme.successColor,
                                      fontWeight: FontWeight.bold)),
                            ),
                            title: Text(data['part_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${data["category"] ?? "-"} | ${currencyFormat.format((data["unit_price"] as num? ?? 0).toDouble())}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showCreateEditDialog(context, doc: doc),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.dangerColor, size: 20),
                                onPressed: () =>
                                    FirebaseDbService.deleteSparePart(doc.id),
                              ),
                            ]),
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