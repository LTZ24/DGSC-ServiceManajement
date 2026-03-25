import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../l10n/app_text.dart';
import '../../services/app_lock_service.dart';
import '../../services/backend_service.dart';

enum _UnlockMode { password, pin, pattern }

class AppLockWrapper extends StatefulWidget {
  const AppLockWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper>
    with WidgetsBindingObserver {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final List<int> _patternInput = [];

  bool _isLocked = false;
  bool _hasCheckedInitial = false;
  bool _checkingBiometric = false;

  bool _hasFaceId = false;
  bool _hasFingerprint = false;
  bool _hasAnyBiometric = false;

  String? _errorText;
  _UnlockMode _mode = _UnlockMode.password;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (BackendService.currentUser == null) {
      _hasCheckedInitial = true;
      return;
    }

    unawaited(_checkLockState(isColdStart: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkLockState({required bool isColdStart}) async {
    final currentUser = BackendService.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLocked = false;
        _hasCheckedInitial = true;
      });
      return;
    }

    final shouldLock = await AppLockService.shouldLock(isColdStart: isColdStart);
    if (!mounted) return;

    if (!shouldLock) {
      setState(() {
        _isLocked = false;
        _hasCheckedInitial = true;
      });
      return;
    }

    await _prepareLockOptions();
    if (!mounted) return;

    setState(() {
      _isLocked = true;
      _hasCheckedInitial = true;
    });

    unawaited(_promptBiometricAutomatically());
  }

  Future<void> _prepareLockOptions() async {
    final results = await Future.wait<dynamic>([
      AppLockService.getAvailableBiometrics(),
      AppLockService.isBiometricEnabled(),
      AppLockService.getUnlockMethod(),
      AppLockService.getPin(),
      AppLockService.getPattern(),
    ]);

    final available = (results[0] as List).cast<BiometricType>();
    final biometricEnabled = results[1] as bool;
    final selectedMethod = results[2] as String;
    final hasPin = (results[3] as String?)?.isNotEmpty == true;
    final hasPattern = (results[4] as String?)?.isNotEmpty == true;

    var mode = _UnlockMode.password;
    if (selectedMethod == 'pin' && hasPin) {
      mode = _UnlockMode.pin;
    } else if (selectedMethod == 'pattern' && hasPattern) {
      mode = _UnlockMode.pattern;
    }

    if (!mounted) return;
    setState(() {
      _hasFaceId = available.contains(BiometricType.face);
      _hasFingerprint = available.contains(BiometricType.fingerprint);
      _hasAnyBiometric = biometricEnabled && available.isNotEmpty;
      _mode = mode;
    });
  }

  Future<void> _promptBiometricAutomatically() async {
    if (!_hasAnyBiometric || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted || !_isLocked) return;
    await _runBiometricCheck();
  }

  Future<void> _runBiometricCheck() async {
    if (_checkingBiometric) return;
    setState(() => _checkingBiometric = true);

    final success = await AppLockService.authenticateBiometric();
    if (!mounted) return;

    if (success) {
      _unlockApp();
      return;
    }

    setState(() => _checkingBiometric = false);
  }

  Future<void> _unlockWithPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _errorText =
            context.tr('Password wajib diisi', 'Password is required');
      });
      return;
    }

    setState(() => _errorText = null);

    try {
      await BackendService.verifyCurrentPassword(password);
      _unlockApp();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = context.tr('Password akun salah', 'Incorrect account password');
      });
    }
  }

  Future<void> _unlockWithPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorText = context.tr('PIN wajib diisi', 'PIN is required'));
      return;
    }

    final storedPin = await AppLockService.getPin();
    if (!mounted) return;

    if (storedPin != null && storedPin == pin) {
      _unlockApp();
      return;
    }

    setState(() => _errorText = context.tr('PIN salah', 'Incorrect PIN'));
  }

  Future<void> _unlockWithPattern() async {
    if (_patternInput.length < 4) {
      setState(() {
        _errorText =
            context.tr('Pola minimal 4 titik', 'Pattern must contain at least 4 dots');
      });
      return;
    }

    final storedPattern = await AppLockService.getPattern();
    if (!mounted) return;

    final current = _patternInput.join('-');
    if (storedPattern != null &&
        storedPattern.isNotEmpty &&
        current == storedPattern) {
      _unlockApp();
      return;
    }

    setState(() {
      _errorText = context.tr('Pola salah', 'Incorrect pattern');
      _patternInput.clear();
    });
  }

  Future<void> _sendResetPassword() async {
    final email = BackendService.currentUser?.email;
    if (email == null || email.isEmpty) return;

    try {
      await BackendService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Email reset password berhasil dikirim',
              'Reset password email sent successfully',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Gagal mengirim reset password',
              'Failed to send reset password email',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _unlockApp() {
    unawaited(AppLockService.markForeground());
    unawaited(AppLockService.recordActiveTime());
    setState(() {
      _isLocked = false;
      _checkingBiometric = false;
      _passwordController.clear();
      _pinController.clear();
      _patternInput.clear();
      _errorText = null;
    });
  }

  Future<void> _handleResume() async {
    await AppLockService.markForeground();
    if (_isLocked || !mounted) return;
    await _checkLockState(isColdStart: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_isLocked) {
        unawaited(AppLockService.markBackground());
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_handleResume());
    }
  }

  String _headerText() {
    final suffix = _hasAnyBiometric
        ? context.tr(' atau biometrik', ' or biometric')
        : '';
    switch (_mode) {
      case _UnlockMode.pin:
        return context.tr('Buka dengan PIN', 'Unlock with PIN') + suffix;
      case _UnlockMode.pattern:
        return context.tr('Buka dengan pola', 'Unlock with pattern') + suffix;
      case _UnlockMode.password:
        return context.tr('Buka dengan password', 'Unlock with password') + suffix;
    }
  }

  Widget _buildPinPad() {
    Widget key(String text, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F4),
            borderRadius: BorderRadius.circular(44),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(fontSize: 25, color: Color(0xFF2E3A3B)),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < row.length; i++) ...[
                key(row[i], () {
                  if (_pinController.text.length >= 6) return;
                  setState(() {
                    _pinController.text += row[i];
                    _errorText = null;
                  });
                }),
                if (i != row.length - 1) const SizedBox(width: 18),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: () {
                if (_pinController.text.isEmpty) return;
                setState(() {
                  _pinController.text = _pinController.text.substring(
                    0,
                    _pinController.text.length - 1,
                  );
                });
              },
              borderRadius: BorderRadius.circular(44),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFCFECEC),
                  borderRadius: BorderRadius.circular(44),
                ),
                child: const Icon(Icons.backspace_outlined, size: 30),
              ),
            ),
            const SizedBox(width: 18),
            key('0', () {
              if (_pinController.text.length >= 6) return;
              setState(() {
                _pinController.text += '0';
                _errorText = null;
              });
            }),
            const SizedBox(width: 18),
            InkWell(
              onTap: _unlockWithPin,
              borderRadius: BorderRadius.circular(44),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFCFECEC),
                  borderRadius: BorderRadius.circular(44),
                ),
                child: const Icon(Icons.login, size: 30),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _passwordController,
        obscureText: true,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22),
        decoration: const InputDecoration(
          border: UnderlineInputBorder(),
          focusedBorder: UnderlineInputBorder(),
        ),
        onSubmitted: (_) => _unlockWithPassword(),
      ),
    );
  }

  Widget _buildPatternPad() {
    return _SlidePatternPad(
      size: 280,
      selected: _patternInput,
      onChanged: (updated) {
        setState(() {
          _patternInput
            ..clear()
            ..addAll(updated);
          _errorText = null;
        });
      },
      onEnd: _unlockWithPattern,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCheckedInitial) {
      return const Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (!_isLocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            children: [
              const SizedBox(height: 50),
              Text(
                _headerText(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2B2D),
                ),
              ),
              const SizedBox(height: 120),
              if (_mode == _UnlockMode.pin)
                _buildPinPad()
              else if (_mode == _UnlockMode.password)
                _buildPasswordField()
              else
                _buildPatternPad(),
              if (_errorText != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 22),
              Container(
                width: 210,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFCFECEC),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: TextButton(
                  onPressed: _sendResetPassword,
                  child: Text(
                    context.tr('Reset Password', 'Reset Password'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2E3A3B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_hasAnyBiometric)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_hasFingerprint)
                      IconButton.filledTonal(
                        onPressed: _checkingBiometric ? null : _runBiometricCheck,
                        icon: const Icon(Icons.fingerprint, size: 26),
                      ),
                    if (_hasFingerprint && _hasFaceId) const SizedBox(width: 12),
                    if (_hasFaceId)
                      IconButton.filledTonal(
                        onPressed: _checkingBiometric ? null : _runBiometricCheck,
                        icon: const Icon(Icons.face),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlidePatternPad extends StatefulWidget {
  const _SlidePatternPad({
    required this.selected,
    required this.onChanged,
    required this.onEnd,
    this.size = 260,
  });

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;
  final Future<void> Function() onEnd;
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
            onPanEnd: (_) async {
              setState(() => _dragPosition = null);
              await widget.onEnd();
            },
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
    final inactivePaint = Paint()..color = const Color(0xFF2E3A3B);
    final activePaint = Paint()..color = const Color(0xFF2E3A3B);
    final linePaint = Paint()
      ..color = const Color(0xFF2E3A3B)
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

    final radius = size.width / 26;
    for (var i = 0; i < centers.length; i++) {
      final value = i + 1;
      final isSelected = selected.contains(value);
      canvas.drawCircle(
        centers[i],
        radius,
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
