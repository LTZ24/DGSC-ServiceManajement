import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../config/theme.dart';
import '../../l10n/app_text.dart';
import '../../services/app_lock_service.dart';
import '../../services/backend_service.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  bool _enabled = false;
  bool _biometricEnabled = false;
  bool _biometricSupported = false;
  bool _hasFaceId = false;
  bool _hasFingerprint = false;
  bool _isLoading = true;

  String _selectedMethod = 'password';
  String? _currentPin;
  String? _currentPattern;
  int _timeoutSeconds = AppLockService.defaultTimeoutSeconds;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait<dynamic>([
      AppLockService.isEnabled(),
      AppLockService.isBiometricEnabled(),
      AppLockService.isBiometricSupported(),
      AppLockService.getAvailableBiometrics(),
      AppLockService.getUnlockMethod(),
      AppLockService.getPin(),
      AppLockService.getPattern(),
      AppLockService.getLockTimeoutSeconds(),
    ]);

    final available = (results[3] as List).cast<BiometricType>();

    if (!mounted) return;
    setState(() {
      _enabled = results[0] as bool;
      _biometricEnabled = results[1] as bool;
      _biometricSupported = results[2] as bool;
      _hasFaceId = available.contains(BiometricType.face);
      _hasFingerprint = available.contains(BiometricType.fingerprint);
      _selectedMethod = results[4] as String;
      _currentPin = results[5] as String?;
      _currentPattern = results[6] as String?;
      _timeoutSeconds = results[7] as int;
      _isLoading = false;
    });
  }

  Future<String?> _confirmPassword(String title, String subtitle) async {
    final password = await _showPasswordDialog(title, subtitle);
    if (password == null || password.isEmpty) return null;

    try {
      await BackendService.verifyCurrentPassword(password);
      return password;
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Password akun salah', 'Incorrect account password')),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return null;
    }
  }

  Future<void> _toggleLock(bool enabled) async {
    if (enabled) {
      final ok = await _confirmPassword(
        context.tr('Konfirmasi Password Akun', 'Confirm Account Password'),
        context.tr(
          'Masukkan password akun untuk mengaktifkan App Lock.',
          'Enter your account password to enable App Lock.',
        ),
      );
      if (ok == null) return;
      await AppLockService.setEnabled(true);
      await AppLockService.clearActiveTime();
      await _loadData();
      return;
    }

    await AppLockService.setEnabled(false);
    await _loadData();
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (!_enabled || !_biometricSupported) return;

    final ok = await _confirmPassword(
      context.tr('Verifikasi Password', 'Verify Password'),
      context.tr(
        'Masukkan password akun untuk mengubah pengaturan biometrik.',
        'Enter your account password to change biometric settings.',
      ),
    );
    if (ok == null) return;

    if (enabled) {
      FocusManager.instance.primaryFocus?.unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final authenticated = await AppLockService.authenticateBiometric();
      if (!authenticated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Autentikasi biometrik gagal atau dibatalkan.',
                'Biometric authentication failed or was canceled.',
              ),
            ),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
        return;
      }
    }

    await AppLockService.setBiometricEnabled(enabled);
    await _loadData();
  }

  Future<void> _createOrChangePin() async {
    final hasPin = (_currentPin ?? '').isNotEmpty;
    final dialogTitle =
        hasPin ? context.tr('Reset PIN', 'Reset PIN') : context.tr('Setel PIN', 'Set PIN');
    final successText =
        context.tr('PIN berhasil diperbarui', 'PIN updated successfully');
    final ok = await _confirmPassword(
      hasPin
          ? context.tr('Verifikasi Password untuk Reset PIN',
              'Verify Password to Reset PIN')
          : context.tr(
              'Verifikasi Password untuk Setel PIN',
              'Verify Password to Set PIN',
            ),
      context.tr(
        'Masukkan password akun untuk melanjutkan.',
        'Enter your account password to continue.',
      ),
    );
    if (ok == null) return;

    final newPin = await _showPinDialog(dialogTitle);
    if (newPin == null || newPin.length < 4) return;

    await AppLockService.setPin(newPin);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successText),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _createOrChangePattern() async {
    final hasPattern = (_currentPattern ?? '').isNotEmpty;
    final dialogTitle = hasPattern
        ? context.tr('Reset Pola', 'Reset Pattern')
        : context.tr('Setel Pola', 'Set Pattern');
    final dialogSubtitle = context.tr(
      'Hubungkan minimal 4 titik.',
      'Connect at least 4 dots.',
    );
    final successText = context.tr(
      'Pola berhasil diperbarui',
      'Pattern updated successfully',
    );
    final ok = await _confirmPassword(
      hasPattern
          ? context.tr('Verifikasi Password untuk Reset Pola',
              'Verify Password to Reset Pattern')
          : context.tr(
              'Verifikasi Password untuk Setel Pola',
              'Verify Password to Set Pattern',
            ),
      context.tr(
        'Masukkan password akun untuk melanjutkan.',
        'Enter your account password to continue.',
      ),
    );
    if (ok == null) return;

    final newPattern = await _showPatternDialog(
      title: dialogTitle,
      subtitle: dialogSubtitle,
    );
    if (newPattern == null) return;

    await AppLockService.setPattern(newPattern);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successText),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _changeMethod(String? method) async {
    if (!_enabled || method == null || method == _selectedMethod) return;

    if (method == 'pin' && (_currentPin ?? '').isEmpty) {
      await _createOrChangePin();
      if ((_currentPin ?? '').isEmpty) return;
    }

    if (method == 'pattern' && (_currentPattern ?? '').isEmpty) {
      await _createOrChangePattern();
      if ((_currentPattern ?? '').isEmpty) return;
    }

    await AppLockService.setUnlockMethod(method);
    await _loadData();
  }

  Future<void> _changeTimeout(int? seconds) async {
    if (!_enabled || seconds == null || seconds == _timeoutSeconds) return;
    await AppLockService.setLockTimeoutSeconds(seconds);
    await _loadData();
  }

  Future<String?> _showPinDialog(String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: context.tr('Minimal 4 digit', 'Minimum 4 digits'),
            counterText: '',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(context.tr('Simpan', 'Save')),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPatternDialog({
    required String title,
    required String subtitle,
  }) async {
    final selected = <int>[];

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'Titik terpilih: ${selected.length}',
                    'Selected dots: ${selected.length}',
                  ),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                _SlidePatternPad(
                  size: 250,
                  selected: selected,
                  onChanged: (updated) {
                    setDialogState(() {
                      selected
                        ..clear()
                        ..addAll(updated);
                    });
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: selected.isEmpty
                        ? null
                        : () => setDialogState(() => selected.clear()),
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr('Ulangi', 'Reset')),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('Batal', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: selected.length < 4
                  ? null
                  : () => Navigator.pop(ctx, selected.join('-')),
              child: Text(context.tr('Simpan', 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showPasswordDialog(String title, String subtitle) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.tr('Password akun', 'Account password'),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(context.tr('Konfirmasi', 'Confirm')),
          ),
        ],
      ),
    );
  }

  String _unlockMethodLabel(String method) {
    switch (method) {
      case 'pin':
        return context.tr('PIN', 'PIN');
      case 'pattern':
        return context.tr('Pola', 'Pattern');
      default:
        return context.tr('Password', 'Password');
    }
  }

  String _timeoutLabel(int seconds) {
    switch (seconds) {
      case 30:
        return '30s';
      case 60:
        return '1m';
      case 120:
        return '2m';
      case 300:
        return '5m';
      case 600:
        return '10m';
      case 1800:
        return '30m';
      default:
        return '${seconds}s';
    }
  }

  String _biometricSubtitle() {
    if (!_biometricSupported) {
      return context.tr(
        'Perangkat tidak mendukung biometrik.',
        'This device does not support biometrics.',
      );
    }

    if (_hasFaceId && _hasFingerprint) {
      return context.tr(
        'Gunakan Face ID atau fingerprint untuk membuka App Lock.',
        'Use Face ID or fingerprint to unlock App Lock.',
      );
    }

    if (_hasFingerprint) {
      return context.tr(
        'Gunakan fingerprint untuk membuka App Lock.',
        'Use fingerprint to unlock App Lock.',
      );
    }

    if (_hasFaceId) {
      return context.tr(
        'Gunakan Face ID untuk membuka App Lock.',
        'Use Face ID to unlock App Lock.',
      );
    }

    return context.tr(
      'Perangkat tidak memiliki biometrik yang aktif.',
      'No active biometrics are enrolled on this device.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasPin = (_currentPin ?? '').isNotEmpty;
    final hasPattern = (_currentPattern ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Pengaturan App Lock', 'App Lock Settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              secondary: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
              title: Text(context.tr('Gunakan App Lock', 'Use App Lock')),
              subtitle: Text(
                context.tr(
                  'Kunci aplikasi setelah beberapa saat tidak digunakan.',
                  'Lock the app after a period of inactivity.',
                ),
              ),
              value: _enabled,
              onChanged: _toggleLock,
            ),
          ),
          if (_enabled) ...[
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Metode Lock', 'Lock Method'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedMethod),
                      initialValue: _selectedMethod,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.password_rounded),
                        labelText: context.tr(
                          'Pilih metode lock',
                          'Choose lock method',
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'password', child: Text('Password')),
                        DropdownMenuItem(value: 'pin', child: Text('PIN')),
                        DropdownMenuItem(value: 'pattern', child: Text('Pola / Pattern')),
                      ],
                      onChanged: _changeMethod,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Timeout App Lock', 'App Lock Timeout'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      key: ValueKey(_timeoutSeconds),
                      initialValue: _timeoutSeconds,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.timer_outlined),
                        labelText: context.tr(
                          'Kunci ulang setelah',
                          'Relock after',
                        ),
                      ),
                      items: AppLockService.supportedTimeoutSeconds
                          .map(
                            (seconds) => DropdownMenuItem<int>(
                              value: seconds,
                              child: Text(_timeoutLabel(seconds)),
                            ),
                          )
                          .toList(),
                      onChanged: _changeTimeout,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                secondary:
                    const Icon(Icons.fingerprint, color: AppTheme.primaryColor),
                title: Text(context.tr('Gunakan Biometrik', 'Use Biometrics')),
                subtitle: Text(_biometricSubtitle()),
                value: _biometricEnabled,
                onChanged: _biometricSupported ? _toggleBiometric : null,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.pin, color: AppTheme.primaryColor),
                title: Text(
                  hasPin
                      ? context.tr('Reset PIN', 'Reset PIN')
                      : context.tr('Setel PIN', 'Set PIN'),
                ),
                subtitle: Text(
                  hasPin
                      ? context.tr('PIN sudah aktif.', 'PIN is already active.')
                      : context.tr('PIN belum dibuat.', 'PIN has not been created yet.'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _createOrChangePin,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.pattern, color: AppTheme.primaryColor),
                title: Text(
                  hasPattern
                      ? context.tr('Reset Pola', 'Reset Pattern')
                      : context.tr('Setel Pola', 'Set Pattern'),
                ),
                subtitle: Text(
                  hasPattern
                      ? context.tr('Pola sudah aktif.', 'Pattern is already active.')
                      : context.tr('Pola belum dibuat.', 'Pattern has not been created yet.'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _createOrChangePattern,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                title: Text(context.tr('Metode Aktif', 'Active Method')),
                subtitle: Text(_unlockMethodLabel(_selectedMethod)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlidePatternPad extends StatefulWidget {
  const _SlidePatternPad({
    required this.selected,
    required this.onChanged,
    this.size = 250,
  });

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;
  final double size;

  @override
  State<_SlidePatternPad> createState() => _SlidePatternPadState();
}

class _SlidePatternPadState extends State<_SlidePatternPad> {
  Offset? _dragPosition;

  List<Offset> _centers(Size size) {
    const grid = 3;
    final gapX = size.width / (grid + 1);
    final gapY = size.height / (grid + 1);
    final points = <Offset>[];
    for (var row = 1; row <= grid; row++) {
      for (var col = 1; col <= grid; col++) {
        points.add(Offset(gapX * col, gapY * row));
      }
    }
    return points;
  }

  int? _hitTest(Offset point, Size size) {
    final points = _centers(size);
    final radius = size.width / 12;
    for (var i = 0; i < points.length; i++) {
      if ((point - points[i]).distance <= radius * 1.4) {
        return i + 1;
      }
    }
    return null;
  }

  void _appendPoint(int value) {
    if (widget.selected.contains(value)) return;
    final updated = List<int>.from(widget.selected)..add(value);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final points = _centers(size);
          return GestureDetector(
            onPanStart: (details) {
              setState(() => _dragPosition = details.localPosition);
              final hit = _hitTest(details.localPosition, size);
              if (hit != null) _appendPoint(hit);
            },
            onPanUpdate: (details) {
              setState(() => _dragPosition = details.localPosition);
              final hit = _hitTest(details.localPosition, size);
              if (hit != null) _appendPoint(hit);
            },
            onPanEnd: (_) => setState(() => _dragPosition = null),
            child: CustomPaint(
              painter: _PatternPainter(
                centers: points,
                selected: widget.selected,
                dragPosition: _dragPosition,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.centers,
    required this.selected,
    required this.dragPosition,
  });

  final List<Offset> centers;
  final List<int> selected;
  final Offset? dragPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final inactivePaint = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.40);
    final activePaint = Paint()..color = AppTheme.primaryColor;
    final linePaint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < selected.length - 1; i++) {
      final from = centers[selected[i] - 1];
      final to = centers[selected[i + 1] - 1];
      canvas.drawLine(from, to, linePaint);
    }

    if (selected.isNotEmpty && dragPosition != null) {
      canvas.drawLine(centers[selected.last - 1], dragPosition!, linePaint);
    }

    final radius = size.width / 12;
    for (var i = 0; i < centers.length; i++) {
      final value = i + 1;
      final isSelected = selected.contains(value);
      canvas.drawCircle(
        centers[i],
        radius * 0.20,
        isSelected ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.dragPosition != dragPosition;
  }
}
