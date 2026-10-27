import 'package:flutter/material.dart';

class StorageInfo {
  final String name;
  final String path;
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final IconData icon;

  const StorageInfo({
    required this.name,
    required this.path,
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
    this.icon = Icons.phone_android_rounded,
  });

  double get usedPercentage {
    if (totalBytes <= 0) return 0.0;
    return (usedBytes / totalBytes).clamp(0.0, 1.0);
  }
}
