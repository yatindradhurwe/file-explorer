import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/file_item.dart';
import '../models/nearby_device.dart';
import '../services/file_operations_service.dart';
import '../services/quick_drop_service.dart';
import '../utils/file_utils.dart';
import '../widgets/radar_view.dart';

class QuickDropScreen extends StatefulWidget {
  final List<FileItem>? filesToSend;

  const QuickDropScreen({
    super.key,
    this.filesToSend,
  });

  @override
  State<QuickDropScreen> createState() => _QuickDropScreenState();
}

class _QuickDropScreenState extends State<QuickDropScreen> with SingleTickerProviderStateMixin {
  final quickDrop = QuickDropService.instance;
  late TabController _tabController;
  StreamSubscription? _deviceSub;
  StreamSubscription? _transferSub;

  List<NearbyDevice> _devices = [];
  TransferProgress? _currentTransfer;
  bool _isTransferring = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initQuickDrop();
  }

  Future<void> _initQuickDrop() async {
    await quickDrop.initialize(filesToShare: widget.filesToSend);

    _deviceSub = quickDrop.devicesStream.listen((devs) {
      if (mounted) {
        setState(() => _devices = devs);
      }
    });

    _transferSub = quickDrop.transferStream.listen((prog) {
      if (mounted) {
        setState(() {
          _currentTransfer = prog;
          _isTransferring = !prog.isCompleted && !prog.isError;
        });

        if (prog.isCompleted && prog.savedPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Received: ${prog.fileName}'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  FileOperationsService.openFile(prog.savedPath!);
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _transferSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sendToDevice(NearbyDevice target) async {
    final files = widget.filesToSend;
    if (files == null || files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files selected to send')),
      );
      return;
    }

    for (var file in files) {
      try {
        await quickDrop.sendFileDirect(target: target, item: file);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transfer failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final webUrl = quickDrop.myIp != null ? 'http://${quickDrop.myIp}:${QuickDropService.httpPort}' : null;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Colors.amber, size: 26),
            SizedBox(width: 8),
            Text('QuickDrop', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.radar_rounded), text: 'Radar Drop'),
            Tab(icon: Icon(Icons.qr_code_2_rounded), text: 'Web & PC Drop'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Radar View (AirDrop style)
          _buildRadarTab(theme, isDark),

          // Tab 2: WebDrop View (QR & Browser Transfer for PC, Mac, iPhone)
          _buildWebDropTab(theme, isDark, webUrl),
        ],
      ),
      bottomSheet: _buildTransferBottomSheet(theme, isDark),
    );
  }

  Widget _buildRadarTab(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Files Queue Banner (if files were chosen to send)
        if (widget.filesToSend != null && widget.filesToSend!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.blue.shade100,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.send_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ready to drop ${widget.filesToSend!.length} ${widget.filesToSend!.length == 1 ? 'file' : 'files'}: tap a device below',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // Animated Radar
        Expanded(
          child: RadarView(
            devices: _devices,
            centerDeviceName: quickDrop.deviceName,
            onDeviceSelected: (device) {
              _sendToDevice(device);
            },
          ),
        ),

        // Hint bar at bottom
        Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: Text(
            _devices.isEmpty
                ? 'Searching nearby phones... Ensure both devices are on the same Wi-Fi or hotspot.'
                : 'Found ${_devices.length} nearby ${_devices.length == 1 ? 'device' : 'devices'}. Tap to drop files in milliseconds!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebDropTab(ThemeData theme, bool isDark, String? webUrl) {
    if (webUrl == null) {
      return const Center(
        child: Text('Connecting to local Wi-Fi...'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Drop to PC, Mac, or iPhone',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'No app required! Scan this QR code or enter the URL from any browser on the same Wi-Fi network.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 24),

          // QR Code Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: webUrl,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 24),

          // URL Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_rounded, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                SelectableText(
                  webUrl,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy URL',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: webUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildTransferBottomSheet(ThemeData theme, bool isDark) {
    final transfer = _currentTransfer;
    if (transfer == null || (!transfer.isCompleted && !_isTransferring && !transfer.isError)) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                transfer.isCompleted
                    ? Icons.check_circle_rounded
                    : (transfer.isError ? Icons.error_rounded : Icons.sync_rounded),
                color: transfer.isCompleted
                    ? Colors.green
                    : (transfer.isError ? Colors.red : Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transfer.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      transfer.isCompleted
                          ? 'Transferred successfully in milliseconds!'
                          : (transfer.isError
                              ? 'Transfer failed: ${transfer.errorMessage}'
                              : '${FileUtils.formatBytes(transfer.sentBytes)} of ${FileUtils.formatBytes(transfer.totalBytes)} • ${transfer.speedMBps.toStringAsFixed(1)} MB/s'),
                      style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              if (transfer.isCompleted)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _currentTransfer = null),
                ),
            ],
          ),
          if (_isTransferring) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: transfer.progress,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ],
      ),
    );
  }
}
