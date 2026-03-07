import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/firebase_db_service.dart';
import '../../widgets/app_drawer.dart';

class AdminCounterScreen extends StatefulWidget {
  const AdminCounterScreen({super.key});
  @override
  State<AdminCounterScreen> createState() => _AdminCounterScreenState();
}

class _AdminCounterScreenState extends State<AdminCounterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  void _showAddTransactionDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String? categoryId;
    String? categoryName;
    final productCtrl = TextEditingController();
    final customerCtrl = TextEditingController();
    final modalCtrl = TextEditingController();
    final sellingCtrl = TextEditingController();
    String paymentMethod = 'cash';

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
                Text('Tambah Transaksi',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseDbService.counterCategoriesStream(),
                  builder: (ctx2, snap) {
                    final docs = snap.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: docs.map((d) {
                        final cd = d.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: d.id,
                          child: Text(cd['name'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (val) {
                        categoryId = val;
                        final cd = docs.firstWhere((d) => d.id == val).data() as Map;
                        categoryName = cd['name'];
                      },
                      validator: (v) => v == null ? 'Pilih kategori' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(controller: productCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Produk'),
                    validator: (v) => v?.isEmpty == true ? 'Wajib' : null),
                const SizedBox(height: 12),
                TextFormField(controller: customerCtrl,
                    decoration: const InputDecoration(labelText: 'Info Pelanggan')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: modalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga Modal', prefixText: 'Rp '),
                      validator: (v) => v?.isEmpty == true ? 'Wajib' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: sellingCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga Jual', prefixText: 'Rp '),
                      validator: (v) => v?.isEmpty == true ? 'Wajib' : null)),
                ]),
                const SizedBox(height: 12),
                StatefulBuilder(builder: (ctx3, setSt) =>
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: const InputDecoration(labelText: 'Metode Bayar'),
                      items: ['cash', 'transfer', 'qris'].map((m) =>
                          DropdownMenuItem(value: m, child: Text(m.toUpperCase()))).toList(),
                      onChanged: (val) => setSt(() => paymentMethod = val!),
                    )),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await FirebaseDbService.addCounterTransaction({
                      'transaction_date': Timestamp.fromDate(_selectedDate),
                      'category_id': categoryId,
                      'category_name': categoryName,
                      'product_name': productCtrl.text,
                      'customer_info': customerCtrl.text,
                      'modal_price': double.tryParse(modalCtrl.text) ?? 0,
                      'selling_price': double.tryParse(sellingCtrl.text) ?? 0,
                      'payment_method': paymentMethod,
                      'created_by': FirebaseDbService.currentUser?.uid,
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Transaksi ditambahkan')));
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

  void _showAddExpenseDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20, left: 20, right: 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tambah Pengeluaran',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                  validator: (v) => v?.isEmpty == true ? 'Wajib' : null),
              const SizedBox(height: 12),
              TextFormField(controller: amountCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jumlah', prefixText: 'Rp '),
                  validator: (v) => v?.isEmpty == true ? 'Wajib' : null),
              const SizedBox(height: 12),
              TextFormField(controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Kategori')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  await FirebaseDbService.addCounterExpense({
                    'expense_date': Timestamp.fromDate(_selectedDate),
                    'description': descCtrl.text,
                    'amount': double.tryParse(amountCtrl.text) ?? 0,
                    'category': categoryCtrl.text,
                    'created_by': FirebaseDbService.currentUser?.uid,
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Pengeluaran ditambahkan')));
                  }
                },
                child: const Text('Simpan'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter / PPOB'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Transaksi'),
            Tab(text: 'Pengeluaran'),
          ],
        ),
      ),
      drawer: const AppDrawer(isAdmin: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 2) {
            _showAddExpenseDialog(context);
          } else {
            _showAddTransactionDialog(context);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: InkWell(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text(dateFormat.format(_selectedDate)),
                const Spacer(),
                const Icon(Icons.arrow_drop_down),
              ]),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSummaryTab(),
              _buildTransactionsTab(),
              _buildExpensesTab(),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildSummaryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseDbService.counterTransactionsStream(date: _selectedDate),
      builder: (context, snap1) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseDbService.counterExpensesStream(date: _selectedDate),
          builder: (context, snap2) {
            final txDocs = snap1.data?.docs ?? [];
            final exDocs = snap2.data?.docs ?? [];
            double totalIncome = 0, totalModal = 0, totalProfit = 0;
            for (final d in txDocs) {
              final data = d.data() as Map<String, dynamic>;
              totalIncome += (data['selling_price'] as num? ?? 0).toDouble();
              totalModal += (data['modal_price'] as num? ?? 0).toDouble();
              totalProfit += (data['profit'] as num? ?? 0).toDouble();
            }
            double totalExpenses = 0;
            for (final d in exDocs) {
              final data = d.data() as Map<String, dynamic>;
              totalExpenses += (data['amount'] as num? ?? 0).toDouble();
            }
            final netProfit = totalProfit - totalExpenses;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _SummaryCard('Total Pemasukan', currencyFormat.format(totalIncome),
                    Icons.trending_up, AppTheme.successColor),
                _SummaryCard('Total Modal', currencyFormat.format(totalModal),
                    Icons.money_off, AppTheme.warningColor),
                _SummaryCard('Total Profit', currencyFormat.format(totalProfit),
                    Icons.attach_money, AppTheme.infoColor),
                _SummaryCard('Total Pengeluaran', currencyFormat.format(totalExpenses),
                    Icons.shopping_cart, AppTheme.dangerColor),
                const Divider(height: 32),
                Card(
                  color: netProfit >= 0
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : AppTheme.dangerColor.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Profit Bersih',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(currencyFormat.format(netProfit),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: netProfit >= 0
                                    ? AppTheme.successColor
                                    : AppTheme.dangerColor)),
                      ],
                    ),
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseDbService.counterTransactionsStream(date: _selectedDate),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
              child: Text('Tidak ada transaksi', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.receipt, color: AppTheme.primaryColor, size: 20),
                ),
                title: Text(data['product_name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('${data["category_name"] ?? ""} | ${data["customer_info"] ?? ""}',
                    style: const TextStyle(fontSize: 12)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currencyFormat.format((data['selling_price'] as num? ?? 0).toDouble()),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('+${currencyFormat.format((data["profit"] as num? ?? 0).toDouble())}',
                        style: const TextStyle(color: AppTheme.successColor, fontSize: 11)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExpensesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseDbService.counterExpensesStream(date: _selectedDate),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
              child: Text('Tidak ada pengeluaran', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.dangerColor.withValues(alpha: 0.15),
                  child: const Icon(Icons.money_off, color: AppTheme.dangerColor, size: 20),
                ),
                title: Text(data['description'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(data['category'] ?? '',
                    style: const TextStyle(fontSize: 12)),
                trailing: Text(
                  currencyFormat.format((data['amount'] as num? ?? 0).toDouble()),
                  style: const TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold),
                ),
                onLongPress: () => FirebaseDbService.deleteCounterExpense(doc.id),
              ),
            );
          },
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 22)),
        title: Text(title, style: const TextStyle(fontSize: 13)),
        trailing: Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ),
    );
  }
}