import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/app_lock_service.dart';
import '../../config/theme.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _hasCheckedInitial = false;

  final TextEditingController _pinController = TextEditingController();
  String? _errorText;
  bool _checkingBiometric = false;
  
  bool _hasFaceId = false;
  bool _hasAnyBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLockState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialLockState() async {
    final shouldLock = await AppLockService.shouldLock();
    if (shouldLock) {
      await _loadBiometricCapabilities();
      if (mounted) {
        setState(() {
          _isLocked = true;
          _hasCheckedInitial = true;
        });
        _promptBiometricAutomatically();
      }
    } else {
      if (mounted) {
        setState(() {
          _isLocked = false;
          _hasCheckedInitial = true;
        });
      }
    }
  }

  Future<void> _loadBiometricCapabilities() async {
    final available = await AppLockService.getAvailableBiometrics();
    if (mounted) {
      setState(() {
        _hasFaceId = available.contains(BiometricType.face);
        _hasAnyBiometric = available.isNotEmpty;
      });
    }
  }

  Future<void> _promptBiometricAutomatically() async {
    if (!_hasAnyBiometric) return;
    _runBiometricCheck();
  }

  Future<void> _runBiometricCheck() async {
    if (_checkingBiometric) return;
    setState(() => _checkingBiometric = true);
    
    final success = await AppLockService.authenticateBiometric();
    if (!mounted) return;
    
    if (success) {
      _unlockApp();
    }
    setState(() => _checkingBiometric = false);
  }

  void _unlockApp() {
    AppLockService.recordActiveTime();
    setState(() {
      _isLocked = false;
      _pinController.clear();
      _errorText = null;
    });
  }

  Future<void> _verifyPin() async {
    final storedPin = await AppLockService.getPin();
    if (storedPin != null && storedPin.isNotEmpty) {
      if (_pinController.text == storedPin) {
        _unlockApp();
      } else {
        setState(() => _errorText = 'PIN salah!');
      }
    } else {
      // If PIN is not setup but it's locked...? Should fallback to password?
      // For now, if no PIN is setup, we just say invalid or allow password bypass?
      // "jika applock sudah diaktifkan input applock dapat diubah dengan membuat pin..."
      // Best to require a PIN setup when enabling AppLock.
      setState(() => _errorText = 'PIN belum diatur');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_isLocked) {
        AppLockService.recordActiveTime();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_isLocked) {
        _checkInitialLockState();
      }
    }
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

    // App Lock Screen UI (Modern M-Banking Style)
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_rounded, size: 60, color: AppTheme.primaryColor),
                    const SizedBox(height: 24),
                    Text(
                      'Masukkan PIN',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aplikasi terkunci untuk keamanan',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Input PIN
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, letterSpacing: 16, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              errorText: _errorText,
                            ),
                            onChanged: (val) {
                              if (val.length >= 4) { // auto trigger check? 
                                _errorText = null;
                              }
                            },
                            onSubmitted: (_) => _verifyPin(),
                          ),
                        ),
                        if (_hasAnyBiometric) ...[
                          const SizedBox(width: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: IconButton(
                              iconSize: 32,
                              color: AppTheme.primaryColor,
                              onPressed: _checkingBiometric ? null : _runBiometricCheck,
                              icon: Icon(_hasFaceId ? Icons.face : Icons.fingerprint),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _verifyPin,
                        child: const Text('Buka Kunci', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
