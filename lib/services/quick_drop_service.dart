import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/file_item.dart';
import '../models/nearby_device.dart';
import 'storage_service.dart';

class TransferProgress {
  final String fileName;
  final int totalBytes;
  final int sentBytes;
  final double speedMBps;
  final bool isCompleted;
  final bool isError;
  final String? errorMessage;
  final String? savedPath;

  TransferProgress({
    required this.fileName,
    required this.totalBytes,
    required this.sentBytes,
    required this.speedMBps,
    this.isCompleted = false,
    this.isError = false,
    this.errorMessage,
    this.savedPath,
  });

  double get progress => totalBytes > 0 ? (sentBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  int get percentage => (progress * 100).toInt();
}

class IncomingFilePrompt {
  final String fileName;
  final int fileSize;
  final String senderName;
  final Completer<bool> responseCompleter;

  IncomingFilePrompt({
    required this.fileName,
    required this.fileSize,
    required this.senderName,
    required this.responseCompleter,
  });
}

class QuickDropService {
  static final QuickDropService instance = QuickDropService._internal();
  factory QuickDropService() => instance;
  QuickDropService._internal();

  static const int udpPort = 53317;
  static const int tcpPort = 53318;
  static const int httpPort = 53319;

  String? _myIp;
  String _deviceId = '';
  String _deviceName = '';

  RawDatagramSocket? _udpSocket;
  Timer? _beaconTimer;
  Timer? _cleanupTimer;

  ServerSocket? _tcpServer;
  HttpServer? _httpServer;

  final Map<String, NearbyDevice> _discoveredDevices = {};
  final StreamController<List<NearbyDevice>> _devicesStreamController =
      StreamController<List<NearbyDevice>>.broadcast();
  final StreamController<TransferProgress> _transferStreamController =
      StreamController<TransferProgress>.broadcast();
  final StreamController<IncomingFilePrompt> _incomingPromptController =
      StreamController<IncomingFilePrompt>.broadcast();

  Stream<List<NearbyDevice>> get devicesStream => _devicesStreamController.stream;
  Stream<TransferProgress> get transferStream => _transferStreamController.stream;
  Stream<IncomingFilePrompt> get incomingPromptStream => _incomingPromptController.stream;
  List<NearbyDevice> get discoveredList => _discoveredDevices.values.toList();
  String? get myIp => _myIp;
  String get deviceName => _deviceName;

  List<FileItem> _activeShareFiles = [];
  List<FileItem> get activeShareFiles => _activeShareFiles;

  Future<void> initialize({List<FileItem>? filesToShare}) async {
    if (filesToShare != null) {
      _activeShareFiles = filesToShare;
    }

    _deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch % 100000}';
    _deviceName = Platform.isAndroid ? 'Android Phone' : Platform.localHostname;

    await _findLocalIp();
    await _startTcpServer();
    await _startHttpServer();
    await _startDiscovery();
  }

  Future<void> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback &&
              (addr.address.startsWith('192.168.') ||
                  addr.address.startsWith('10.') ||
                  addr.address.startsWith('172.'))) {
            _myIp = addr.address;
            return;
          }
        }
      }

      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        _myIp = interfaces.first.addresses.first.address;
      }
    } catch (e) {
      debugPrint('Error finding local IP: $e');
    }
  }

  // --- UDP Discovery Protocol ---

  Future<void> _startDiscovery() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpPort,
        reuseAddress: true,
        reusePort: false,
      );
      _udpSocket?.broadcastEnabled = true;

      _udpSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      // Periodic broadcast beacon every 1.2 seconds for instant detection
      _beaconTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
        _sendBeacon();
      });

      // Cleanup devices inactive for more than 5 seconds
      _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        final now = DateTime.now();
        _discoveredDevices.removeWhere((key, device) {
          return now.difference(device.lastSeen).inSeconds > 5;
        });
        _devicesStreamController.add(discoveredList);
      });

      // Send initial beacon immediately
      _sendBeacon();
    } catch (e) {
      debugPrint('Error starting UDP discovery: $e');
    }
  }

  void _sendBeacon() {
    if (_udpSocket == null || _myIp == null) return;
    try {
      final payload = jsonEncode({
        'type': 'QUICK_DROP_BEACON',
        'id': _deviceId,
        'name': _deviceName,
        'model': Platform.operatingSystem,
        'tcpPort': tcpPort,
        'httpPort': httpPort,
      });

      final bytes = utf8.encode(payload);
      _udpSocket?.send(bytes, InternetAddress('255.255.255.255'), udpPort);
    } catch (_) {}
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;

      if (json['type'] == 'QUICK_DROP_BEACON') {
        final senderId = json['id'] as String?;
        final senderIp = datagram.address.address;

        // Skip self
        if (senderId == _deviceId || senderIp == _myIp) return;

        final device = NearbyDevice.fromJson(json, senderIp);
        _discoveredDevices[device.id] = device;
        _devicesStreamController.add(discoveredList);
      }
    } catch (_) {}
  }

  // --- High-Speed TCP Server for Receiving Files ---

  Future<void> _startTcpServer() async {
    try {
      _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);
      _tcpServer?.listen((Socket socket) {
        _handleIncomingSocket(socket);
      });
    } catch (e) {
      debugPrint('Error starting TCP server: $e');
    }
  }

  Future<void> _handleIncomingSocket(Socket socket) async {
    final Completer<void> transferCompleter = Completer<void>();
    IOSink? fileSink;
    String? savingPath;
    int receivedBytes = 0;
    int totalBytes = 0;
    String fileName = '';
    String senderName = 'Nearby Device';
    final stopwatch = Stopwatch()..start();

    // Protocol: First 4 bytes indicate JSON header length
    bool headerReceived = false;
    int expectedHeaderLength = 0;
    final List<int> headerBuffer = [];

    socket.listen(
      (List<int> chunk) async {
        try {
          if (!headerReceived) {
            headerBuffer.addAll(chunk);
            if (headerBuffer.length >= 4 && expectedHeaderLength == 0) {
              final bd = ByteData.sublistView(Uint8List.fromList(headerBuffer.sublist(0, 4)));
              expectedHeaderLength = bd.getUint32(0);
            }

            if (expectedHeaderLength > 0 && headerBuffer.length >= 4 + expectedHeaderLength) {
              final headerBytes = headerBuffer.sublist(4, 4 + expectedHeaderLength);
              final headerStr = utf8.decode(headerBytes);
              final header = jsonDecode(headerStr) as Map<String, dynamic>;

              fileName = header['fileName'] as String? ?? 'file_${DateTime.now().millisecondsSinceEpoch}';
              totalBytes = header['fileSize'] as int? ?? 0;
              senderName = header['senderName'] as String? ?? 'Nearby Device';
              debugPrint('Receiving $fileName from $senderName');

              // Prepare save directory in Download/FileDrop
              final root = await StorageService.getRootPath();
              final dropDir = Directory(p.join(root, 'Download', 'FileDrop'));
              if (!await dropDir.exists()) {
                await dropDir.create(recursive: true);
              }

              savingPath = p.join(dropDir.path, fileName);
              final file = File(savingPath!);
              fileSink = file.openWrite();
              headerReceived = true;

              // Remaining data in chunk belongs to file bytes
              final remainingData = headerBuffer.sublist(4 + expectedHeaderLength);
              if (remainingData.isNotEmpty) {
                fileSink?.add(remainingData);
                receivedBytes += remainingData.length;
              }
            }
          } else {
            // Streaming file bytes directly to disk
            fileSink?.add(chunk);
            receivedBytes += chunk.length;

            final speed = (receivedBytes / (stopwatch.elapsedMilliseconds / 1000 + 0.001)) / (1024 * 1024);

            _transferStreamController.add(
              TransferProgress(
                fileName: fileName,
                totalBytes: totalBytes,
                sentBytes: receivedBytes,
                speedMBps: speed,
              ),
            );
          }
        } catch (e) {
          debugPrint('Socket write error: $e');
        }
      },
      onDone: () async {
        await fileSink?.flush();
        await fileSink?.close();
        stopwatch.stop();

        _transferStreamController.add(
          TransferProgress(
            fileName: fileName,
            totalBytes: totalBytes,
            sentBytes: receivedBytes,
            speedMBps: 0,
            isCompleted: true,
            savedPath: savingPath,
          ),
        );
        transferCompleter.complete();
      },
      onError: (e) {
        fileSink?.close();
        _transferStreamController.add(
          TransferProgress(
            fileName: fileName,
            totalBytes: totalBytes,
            sentBytes: receivedBytes,
            speedMBps: 0,
            isError: true,
            errorMessage: e.toString(),
          ),
        );
      },
    );
  }

  // --- Send File over High-Speed Direct TCP Socket ---

  Future<void> sendFileDirect({
    required NearbyDevice target,
    required FileItem item,
  }) async {
    final file = File(item.path);
    if (!await file.exists()) {
      throw Exception('File does not exist: ${item.path}');
    }

    final fileSize = await file.length();
    final socket = await Socket.connect(target.ip, target.tcpPort, timeout: const Duration(seconds: 4));

    // Prepare JSON Header
    final headerMap = {
      'fileName': item.name,
      'fileSize': fileSize,
      'senderName': _deviceName,
    };
    final headerBytes = utf8.encode(jsonEncode(headerMap));

    // Write 4 bytes length + header
    final lengthData = ByteData(4)..setUint32(0, headerBytes.length);
    socket.add(lengthData.buffer.asUint8List());
    socket.add(headerBytes);
    await socket.flush();

    // Stream file chunks
    final stopwatch = Stopwatch()..start();
    int sentBytes = 0;

    final stream = file.openRead();
    await for (final chunk in stream) {
      socket.add(chunk);
      sentBytes += chunk.length;

      final speed = (sentBytes / (stopwatch.elapsedMilliseconds / 1000 + 0.001)) / (1024 * 1024);

      _transferStreamController.add(
        TransferProgress(
          fileName: item.name,
          totalBytes: fileSize,
          sentBytes: sentBytes,
          speedMBps: speed,
        ),
      );
    }

    await socket.flush();
    await socket.close();
    stopwatch.stop();

    _transferStreamController.add(
      TransferProgress(
        fileName: item.name,
        totalBytes: fileSize,
        sentBytes: sentBytes,
        speedMBps: 0,
        isCompleted: true,
      ),
    );
  }

  // --- Universal WebDrop Browser AirDrop Server ---

  Future<void> _startHttpServer() async {
    try {
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, httpPort);
      _httpServer?.listen((HttpRequest request) {
        _handleHttpRequest(request);
      });
    } catch (e) {
      debugPrint('Error starting WebDrop server: $e');
    }
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    final response = request.response;
    final path = request.uri.path;

    if (request.method == 'GET') {
      if (path == '/' || path == '/index.html') {
        response.headers.contentType = ContentType.html;
        response.write(_buildWebDropHtml());
        await response.close();
      } else if (path.startsWith('/download/')) {
        // Download a file
        final indexStr = path.replaceFirst('/download/', '');
        final index = int.tryParse(indexStr) ?? 0;
        if (index >= 0 && index < _activeShareFiles.length) {
          final fileItem = _activeShareFiles[index];
          final file = File(fileItem.path);
          if (await file.exists()) {
            response.headers.set('Content-Disposition', 'attachment; filename="${fileItem.name}"');
            response.headers.contentType = ContentType.binary;
            response.headers.contentLength = fileItem.size;
            await file.openRead().pipe(response);
            return;
          }
        }
        response.statusCode = HttpStatus.notFound;
        response.write('File not found');
        await response.close();
      } else {
        response.statusCode = HttpStatus.notFound;
        await response.close();
      }
    } else if (request.method == 'POST' && path == '/upload') {
      // Browser upload directly into Phone's Download/FileDrop
      try {
        final root = await StorageService.getRootPath();
        final dropDir = Directory(p.join(root, 'Download', 'FileDrop'));
        if (!await dropDir.exists()) {
          await dropDir.create(recursive: true);
        }

        final filename = request.headers.value('x-filename') ?? 'web_file_${DateTime.now().millisecondsSinceEpoch}';
        final targetPath = p.join(dropDir.path, Uri.decodeComponent(filename));
        final file = File(targetPath);
        final sink = file.openWrite();
        await sink.addStream(request);
        await sink.close();

        response.statusCode = HttpStatus.ok;
        response.write('File uploaded successfully!');
        await response.close();

        _transferStreamController.add(
          TransferProgress(
            fileName: filename,
            totalBytes: 100,
            sentBytes: 100,
            speedMBps: 0,
            isCompleted: true,
            savedPath: targetPath,
          ),
        );
      } catch (e) {
        response.statusCode = HttpStatus.internalServerError;
        response.write('Upload failed: $e');
        await response.close();
      }
    }
  }

  String _buildWebDropHtml() {
    final filesHtml = _activeShareFiles.asMap().entries.map((entry) {
      final i = entry.key;
      final f = entry.value;
      return '''
        <div class="file-card">
          <div class="file-info">
            <span class="file-name">${f.name}</span>
            <span class="file-size">${(f.size / (1024 * 1024)).toStringAsFixed(1)} MB</span>
          </div>
          <a class="download-btn" href="/download/$i" download="${f.name}">Download</a>
        </div>
      ''';
    }).join('');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>QuickDrop - File Transfer</title>
  <style>
    * { box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    body { background: #0f172a; color: #f8fafc; margin: 0; padding: 24px; display: flex; flex-direction: column; align-items: center; }
    .container { width: 100%; max-width: 480px; }
    .header { text-align: center; margin-bottom: 24px; }
    .header h1 { font-size: 26px; margin: 0; color: #38bdf8; display: flex; align-items: center; justify-content: center; gap: 8px; }
    .header p { color: #94a3b8; font-size: 14px; margin-top: 6px; }
    .section-title { font-size: 14px; font-weight: 700; text-transform: uppercase; color: #64748b; margin-bottom: 12px; }
    .file-card { background: #1e293b; border-radius: 14px; padding: 16px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; border: 1px solid #334155; }
    .file-name { font-weight: 600; font-size: 15px; display: block; max-width: 240px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .file-size { font-size: 12px; color: #94a3b8; }
    .download-btn { background: #0284c7; color: white; padding: 10px 18px; border-radius: 10px; text-decoration: none; font-weight: 600; font-size: 13px; }
    .upload-zone { border: 2px dashed #38bdf8; border-radius: 16px; padding: 32px 20px; text-align: center; background: rgba(56, 189, 248, 0.05); margin-top: 24px; cursor: pointer; }
    .upload-zone:hover { background: rgba(56, 189, 248, 0.1); }
    #status { margin-top: 14px; font-weight: 600; font-size: 14px; color: #4ade80; text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>⚡ QuickDrop</h1>
      <p>Instant file drop between phone, PC, and iPhone</p>
    </div>

    ${_activeShareFiles.isNotEmpty ? '<div class="section-title">Files available from phone</div>$filesHtml' : '<p style="text-align:center; color:#64748b;">No files queued to download.</p>'}

    <div class="section-title" style="margin-top: 24px;">Send file to phone</div>
    <div class="upload-zone" onclick="document.getElementById('fileInput').click()">
      <p style="margin: 0; font-weight: 600;">Tap or Drag file here to send to phone</p>
      <span style="font-size: 12px; color: #94a3b8;">High-speed local Wi-Fi transfer</span>
      <input type="file" id="fileInput" style="display:none" onchange="uploadFile(this.files[0])">
    </div>
    <div id="status"></div>
  </div>

  <script>
    function uploadFile(file) {
      if (!file) return;
      var status = document.getElementById('status');
      status.innerText = 'Sending ' + file.name + '...';
      fetch('/upload', {
        method: 'POST',
        headers: { 'x-filename': encodeURIComponent(file.name) },
        body: file
      }).then(function(res) {
        if (res.ok) {
          status.innerText = '✓ ' + file.name + ' dropped successfully into phone!';
        } else {
          status.innerText = 'Upload failed.';
        }
      }).catch(function(err) {
        status.innerText = 'Error: ' + err;
      });
    }
  </script>
</body>
</html>
''';
  }

  void dispose() {
    _beaconTimer?.cancel();
    _cleanupTimer?.cancel();
    _udpSocket?.close();
    _tcpServer?.close();
    _httpServer?.close();
  }
}
