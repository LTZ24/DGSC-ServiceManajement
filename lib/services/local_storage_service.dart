/// local_storage_service.dart
///
/// Handles all photo/file operations using device local storage.
/// No cloud needed — photos & receipts are stored in app's private directory.
/// Stored path (relative) is saved to Firestore as a string field.

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class LocalStorageService {
  static final ImagePicker _picker = ImagePicker();

  // ─── Pick & Save Image ───────────────────────────────────────────

  /// Pick a profile photo from gallery, save to appDir/profiles/<uid>.jpg
  /// Returns the saved absolute path, or null if cancelled.
  static Future<String?> pickAndSaveProfilePhoto(String uid) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) return null;
      return await _saveFile(picked.path, 'profiles', 'profile_$uid.jpg');
    } catch (_) {
      return null;
    }
  }

  /// Pick a receipt/bukti photo from camera or gallery.
  /// Saves to appDir/receipts/<bookingId>_<timestamp>.jpg
  static Future<String?> pickAndSaveReceiptPhoto(
      String bookingId, {
      ImageSource source = ImageSource.camera,
    }) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (picked == null) return null;
      final fileName =
          'receipt_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return await _saveFile(picked.path, 'receipts', fileName);
    } catch (_) {
      return null;
    }
  }

  /// Pick a device photo for booking (kondisi perangkat).
  static Future<String?> pickAndSaveDevicePhoto(
      String bookingId, {
      ImageSource source = ImageSource.camera,
    }) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (picked == null) return null;
      final fileName =
          'device_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return await _saveFile(picked.path, 'devices', fileName);
    } catch (_) {
      return null;
    }
  }

  // ─── Get Image ───────────────────────────────────────────────────

  /// Get a File object from a stored absolute path.
  /// Returns null if file doesn't exist.
  static File? getFile(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  // ─── Delete ──────────────────────────────────────────────────────

  /// Delete a stored file by its absolute path.
  static Future<void> deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  // ─── Storage info ────────────────────────────────────────────────

  /// Get total size of all locally stored photos in bytes.
  static Future<int> getTotalStorageUsed() async {
    try {
      final dir = await _getAppDir();
      int total = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Human-readable storage size string.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ─── Internal ────────────────────────────────────────────────────

  static Future<Directory> _getAppDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return appDir;
  }

  /// Copy picked file to app directory under [subFolder]/[fileName].
  static Future<String> _saveFile(
    String sourcePath,
    String subFolder,
    String fileName,
  ) async {
    final appDir = await _getAppDir();
    final targetDir = Directory(p.join(appDir.path, subFolder));
    if (!await targetDir.exists()) await targetDir.create(recursive: true);

    final targetPath = p.join(targetDir.path, fileName);
    await File(sourcePath).copy(targetPath);
    return targetPath;
  }
}
