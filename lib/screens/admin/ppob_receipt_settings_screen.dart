import 'dart:convert';
import 'dart:typed_data';

import 'package:blue_thermal_helper/blue_thermal_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/backend_service.dart';
import '../../services/ppob_print_service.dart';

class PpobReceiptSettingsScreen extends StatefulWidget {
  const PpobReceiptSettingsScreen({super.key});

  @override
  State<PpobReceiptSettingsScreen> createState() =>
      _PpobReceiptSettingsScreenState();
}

class _PpobReceiptSettingsScreenState extends State<PpobReceiptSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _headerCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  bool _loading = true;
  String _headerImageBase64 = '';
  Map<String, dynamic> _printerSettings = const {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _addressCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final receiptSettings = await BackendService.getPpobReceiptSettings();
    final printerSettings = await BackendService.getPpobPrinterSettings();
    final storeSettings = await BackendService.getStoreSettings() ?? {};
    _headerCtrl.text = (receiptSettings['header_text'] ?? '').toString();
    _addressCtrl.text = (receiptSettings['address'] ?? '').toString().isEmpty
        ? (storeSettings['store_address'] ?? '').toString()
        : (receiptSettings['address'] ?? '').toString();
    _footerCtrl.text = (receiptSettings['footer_text'] ?? '').toString();
    _headerImageBase64 =
        (receiptSettings['header_image_base64'] ?? '').toString();
    if (mounted) {
      setState(() {
        _printerSettings = printerSettings;
        _loading = false;
      });
    }
  }

  Future<void> _pickHeaderImage() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _headerImageBase64 = base64Encode(bytes));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await BackendService.savePpobReceiptSettings({
      'header_image_base64': _headerImageBase64,
      'header_text': _headerCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'footer_text': _footerCtrl.text.trim(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr('Pengaturan struk disimpan', 'Receipt settings saved'),
        ),
      ),
    );
  }

  Future<void> _showPrinterDialog() async {
    final paperSizes = ['58', '80'];
    String selectedPaper = (_printerSettings['paper_size'] ?? '58').toString();
    String selectedName = (_printerSettings['printer_name'] ?? '').toString();
    String selectedAddress =
        (_printerSettings['printer_address'] ?? '').toString();
    List<BluetoothPrinter> devices = const [];
    bool scanning = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> scanDevices() async {
              setStateDialog(() => scanning = true);
              try {
                devices = await PpobPrintService.scanDevices();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              } finally {
                if (ctx.mounted) {
                  setStateDialog(() => scanning = false);
                }
              }
            }

            Future<void> savePrinter() async {
              await BackendService.savePpobPrinterSettings({
                'printer_name': selectedName,
                'printer_address': selectedAddress,
                'paper_size': selectedPaper,
                'auto_print': false,
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              await _loadData();
            }

            Future<void> connectPrinter() async {
              if (selectedAddress.isEmpty) return;
              try {
                final connected = await PpobPrintService.connect(
                  selectedAddress,
                  paperSize: selectedPaper,
                );
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      connected
                          ? ctx.tr('Printer terhubung', 'Printer connected')
                          : ctx.tr('Gagal menghubungkan printer',
                              'Failed to connect printer'),
                    ),
                  ),
                );
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            }

            return AlertDialog(
              title:
                  Text(context.tr('Koneksi Bluetooth', 'Bluetooth Connection')),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedPaper,
                            decoration: InputDecoration(
                              labelText:
                                  context.tr('Ukuran Kertas', 'Paper Size'),
                            ),
                            items: paperSizes
                                .map((size) => DropdownMenuItem<String>(
                                      value: size,
                                      child: Text('${size}mm'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setStateDialog(() => selectedPaper = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: scanning ? null : scanDevices,
                          icon: const Icon(Icons.bluetooth_searching),
                          label: Text(context.tr('Scan', 'Scan')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: devices.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                context.tr(
                                  'Belum ada device. Tekan scan untuk mencari printer Bluetooth.',
                                  'No device yet. Tap scan to discover Bluetooth printers.',
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemBuilder: (ctx2, index) {
                                final device = devices[index];
                                final selected =
                                    device.address == selectedAddress;
                                return ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: selected
                                          ? AppTheme.primaryColor
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  leading: Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: selected
                                        ? AppTheme.primaryColor
                                        : Colors.grey,
                                  ),
                                  title: Text(device.name),
                                  subtitle: Text(device.address),
                                  onTap: () {
                                    setStateDialog(() {
                                      selectedName = device.name;
                                      selectedAddress = device.address;
                                    });
                                  },
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemCount: devices.length,
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.tr('Tutup', 'Close')),
                ),
                OutlinedButton.icon(
                  onPressed: selectedAddress.isEmpty ? null : connectPrinter,
                  icon: const Icon(Icons.bluetooth_connected),
                  label: Text(context.tr('Hubungkan', 'Connect')),
                ),
                ElevatedButton.icon(
                  onPressed: savePrinter,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(context.tr('Simpan', 'Save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _printTest() async {
    try {
      final storeSettings = await BackendService.getStoreSettings() ?? {};
      await PpobPrintService.printTestReceipt(
        receiptSettings: {
          'header_image_base64': _headerImageBase64,
          'header_text': _headerCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'footer_text': _footerCtrl.text.trim(),
        },
        storeSettings: storeSettings,
        paperSize: (_printerSettings['paper_size'] ?? '58').toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr('Test print dikirim', 'Test print sent'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Pengaturan Struk', 'Receipt Settings')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final previewBytes = _headerImageBase64.isEmpty
        ? null
        : Uint8List.fromList(base64Decode(_headerImageBase64));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Pengaturan Struk', 'Receipt Settings')),
        actions: [
          IconButton(
            onPressed: _showPrinterDialog,
            icon: const Icon(Icons.bluetooth_rounded),
            tooltip: context.tr('Koneksi Bluetooth', 'Bluetooth Connection'),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Header Struk', 'Receipt Header'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (previewBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(previewBytes,
                              height: 120, fit: BoxFit.cover),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickHeaderImage,
                            icon: const Icon(Icons.image_outlined),
                            label:
                                Text(context.tr('Pilih Gambar', 'Pick Image')),
                          ),
                          if (_headerImageBase64.isNotEmpty)
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _headerImageBase64 = ''),
                              icon: const Icon(Icons.delete_outline),
                              label: Text(context.tr('Hapus', 'Remove')),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _headerCtrl,
                        decoration: InputDecoration(
                          labelText: context.tr(
                              'Header text info', 'Header text info'),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? context.tr('Wajib diisi', 'Required')
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: context.tr('Alamat', 'Address'),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? context.tr('Wajib diisi', 'Required')
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _footerCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: context.tr(
                              'Footer text info', 'Footer text info'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Printer Bluetooth', 'Bluetooth Printer'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _infoRow(
                        context,
                        context.tr('Device', 'Device'),
                        (_printerSettings['printer_name'] ?? '')
                                .toString()
                                .isEmpty
                            ? context.tr('Belum dipilih', 'Not selected yet')
                            : (_printerSettings['printer_name'] ?? '')
                                .toString(),
                      ),
                      _infoRow(
                        context,
                        context.tr('Address', 'Address'),
                        (_printerSettings['printer_address'] ?? '')
                                .toString()
                                .isEmpty
                            ? '-'
                            : (_printerSettings['printer_address'] ?? '')
                                .toString(),
                      ),
                      _infoRow(
                        context,
                        context.tr('Ukuran', 'Paper size'),
                        '${(_printerSettings['paper_size'] ?? '58')}mm',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _showPrinterDialog,
                            icon: const Icon(Icons.settings_bluetooth),
                            label: Text(context.tr(
                                'Atur Printer', 'Configure Printer')),
                          ),
                          OutlinedButton.icon(
                            onPressed: _printTest,
                            icon: const Icon(Icons.print_outlined),
                            label: Text(context.tr('Test Print', 'Test Print')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label:
                      Text(context.tr('Simpan Pengaturan', 'Save Settings')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
