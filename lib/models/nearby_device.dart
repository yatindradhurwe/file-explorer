import 'package:flutter/material.dart';

class NearbyDevice {
  final String id;
  final String name;
  final String model;
  final String ip;
  final int tcpPort;
  final int httpPort;
  DateTime lastSeen;

  NearbyDevice({
    required this.id,
    required this.name,
    required this.model,
    required this.ip,
    required this.tcpPort,
    required this.httpPort,
    required this.lastSeen,
  });

  factory NearbyDevice.fromJson(Map<String, dynamic> json, String ip) {
    return NearbyDevice(
      id: json['id'] as String? ?? ip,
      name: json['name'] as String? ?? 'Nearby Device',
      model: json['model'] as String? ?? 'Mobile Phone',
      ip: ip,
      tcpPort: json['tcpPort'] as int? ?? 53318,
      httpPort: json['httpPort'] as int? ?? 53319,
      lastSeen: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'model': model,
    'tcpPort': tcpPort,
    'httpPort': httpPort,
  };

  IconData get icon {
    final lower = model.toLowerCase();
    if (lower.contains('mac') || lower.contains('pc') || lower.contains('windows') || lower.contains('laptop')) {
      return Icons.laptop_mac_rounded;
    }
    if (lower.contains('tablet') || lower.contains('ipad')) {
      return Icons.tablet_mac_rounded;
    }
    return Icons.phone_android_rounded;
  }
}
