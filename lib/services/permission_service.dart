import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> hasStoragePermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Desktop platforms don't need runtime permissions
      return true;
    }

    if (Platform.isAndroid) {
      // Try manageExternalStorage first (Android 11+)
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;

      // Check standard storage permission (Android 10 and below)
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;

      return false;
    }

    if (Platform.isIOS) {
      final photosStatus = await Permission.photos.status;
      return photosStatus.isGranted;
    }

    return true;
  }

  static Future<bool> requestStoragePermission() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return true;
    }

    if (Platform.isAndroid) {
      // Request manageExternalStorage for Android 11+ (Scoped Storage bypass)
      var manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) {
        return true;
      }

      // If not granted, try standard storage permission
      var storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) {
        return true;
      }

      // Also request media permissions for Android 13+
      await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();

      // Check status again
      return await hasStoragePermission();
    }

    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }

    return true;
  }

  static Future<void> openAppSettingsPage() async {
    await openAppSettings();
  }
}
