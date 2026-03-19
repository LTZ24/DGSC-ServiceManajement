import 'dart:io';

void main() {
  var file = File('lib/screens/customer/settings_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceAll(RegExp(r'  bool _biometricSupported = false;\r?\n'), '');
  content = content.replaceAll(RegExp(r'  bool _securityEnabled = false;\r?\n'), '');
  content = content.replaceAll(RegExp(r'    _loadSecurityState\(\);\r?\n'), '');

  content = content.replaceAll(RegExp(r'  Future<void> _loadSecurityState\(\) async \{.*?\r?\n  \}\r?\n', dotAll: true), '');
  content = content.replaceAll(RegExp(r'  Future<void> _toggleSecurity\(bool enable\) async \{.*?\r?\n  \}\r?\n', dotAll: true), '');
  content = content.replaceAll(RegExp(r'  Future<String\?> _showPasswordConfirmationDialog\(\) async \{.*?\r?\n    \);\r?\n  \}\r?\n', dotAll: true), '');
  content = content.replaceAll(RegExp(r'          if \(_biometricSupported\) \.\.\.\[.*?\r?\n          \],\r?\n', dotAll: true), '');

  file.writeAsStringSync(content);
}
