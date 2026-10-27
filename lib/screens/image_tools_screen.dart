import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/media_tools_service.dart';
import '../utils/file_utils.dart';

enum ImageTool { removeBackground, resize, compress }

extension ImageToolInfo on ImageTool {
  String get title {
    switch (this) {
      case ImageTool.removeBackground:
        return 'Remove Background';
      case ImageTool.resize:
        return 'Image Resizer';
      case ImageTool.compress:
        return 'Image Compressor';
    }
  }

  IconData get icon {
    switch (this) {
      case ImageTool.removeBackground:
        return Icons.auto_fix_high_rounded;
      case ImageTool.resize:
        return Icons.photo_size_select_large_rounded;
      case ImageTool.compress:
        return Icons.compress_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ImageTool.removeBackground:
        return Colors.deepPurple;
      case ImageTool.resize:
        return Colors.indigo;
      case ImageTool.compress:
        return Colors.orange;
    }
  }
}

class ImageToolsScreen extends StatefulWidget {
  final ImageTool tool;

  const ImageToolsScreen({super.key, required this.tool});

  @override
  State<ImageToolsScreen> createState() => _ImageToolsScreenState();
}

class _ImageToolsScreenState extends State<ImageToolsScreen> {
  final ImagePicker _picker = ImagePicker();

  File? _source;
  int? _sourceBytes;
  int? _sourceWidth;
  int? _sourceHeight;

  bool _busy = false;
  ImageToolResult? _result;
  bool? _usedAi;

  // Resize options
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  bool _keepAspect = true;
  bool _resizeAsPng = false;

  // Compress options
  double _quality = 70;
  int? _maxSide;
  final _targetKbController = TextEditingController();
  bool _useTargetSize = false;

  // Background removal options
  BackgroundRemovalMode _bgMode = BackgroundRemovalMode.ai;
  double _tolerance = 40;

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _targetKbController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, requestFullMetadata: false);
      if (picked == null) return;
      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      final oriented = decoded == null ? null : img.bakeOrientation(decoded);
      if (!mounted) return;
      setState(() {
        _source = file;
        _sourceBytes = bytes.length;
        _sourceWidth = oriented?.width;
        _sourceHeight = oriented?.height;
        _result = null;
        _usedAi = null;
        _widthController.text = oriented?.width.toString() ?? '';
        _heightController.text = oriented?.height.toString() ?? '';
      });
    } catch (e) {
      _snack('Could not open image: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onWidthChanged(String v) {
    if (!_keepAspect || _sourceWidth == null || _sourceHeight == null) return;
    final w = int.tryParse(v);
    if (w == null || w <= 0) return;
    _heightController.text = (w * _sourceHeight! / _sourceWidth!).round().toString();
  }

  void _onHeightChanged(String v) {
    if (!_keepAspect || _sourceWidth == null || _sourceHeight == null) return;
    final h = int.tryParse(v);
    if (h == null || h <= 0) return;
    _widthController.text = (h * _sourceWidth! / _sourceHeight!).round().toString();
  }

  void _applyPercent(int percent) {
    if (_sourceWidth == null || _sourceHeight == null) return;
    setState(() {
      _widthController.text = (_sourceWidth! * percent / 100).round().toString();
      _heightController.text = (_sourceHeight! * percent / 100).round().toString();
    });
  }

  Future<void> _process() async {
    final source = _source;
    if (source == null) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      switch (widget.tool) {
        case ImageTool.removeBackground:
          final r = await MediaToolsService.removeBackground(
            source: source,
            mode: _bgMode,
            tolerance: _tolerance.round(),
          );
          _result = r.result;
          _usedAi = r.usedAi;
          if (_bgMode == BackgroundRemovalMode.ai && !r.usedAi) {
            _snack('AI model unavailable. Used offline plain-background mode instead.');
          }
          break;
        case ImageTool.resize:
          final w = int.tryParse(_widthController.text.trim());
          final h = int.tryParse(_heightController.text.trim());
          if ((w == null || w <= 0) && (h == null || h <= 0)) {
            _snack('Enter a width or height');
            break;
          }
          _result = await MediaToolsService.resizeImage(
            source: source,
            width: (w != null && w > 0) ? w : null,
            height: (h != null && h > 0) ? h : null,
            keepAspect: _keepAspect,
            format: _resizeAsPng ? ImageOutputFormat.png : ImageOutputFormat.jpg,
          );
          break;
        case ImageTool.compress:
          final target = int.tryParse(_targetKbController.text.trim());
          if (_useTargetSize && (target == null || target <= 0)) {
            _snack('Enter a target size in KB');
            break;
          }
          _result = await MediaToolsService.compressImage(
            source: source,
            quality: _quality.round(),
            maxSide: _maxSide,
            targetKb: _useTargetSize ? target : null,
          );
          break;
      }
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    return Scaffold(
      appBar: AppBar(
        title: Text(tool.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _pickerCard(),
          if (_source != null) ...[
            const SizedBox(height: 16),
            _optionsCard(),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: tool.color,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _busy ? null : _process,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(tool.icon),
              label: Text(_busy ? 'Processing...' : tool.title),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            _resultCard(_result!),
          ],
        ],
      ),
    );
  }

  Widget _pickerCard() {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_source != null)
            Container(
              height: 220,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Image.file(_source!, fit: BoxFit.contain),
            )
          else
            Container(
              height: 160,
              color: widget.tool.color.withAlpha(20),
              child: Icon(widget.tool.icon, size: 64, color: widget.tool.color),
            ),
          if (_source != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                '${_sourceWidth ?? '?'} × ${_sourceHeight ?? '?'} px  •  ${FileUtils.formatBytes(_sourceBytes ?? 0)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: Text(_source == null ? 'Choose Image' : 'Change'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionsCard() {
    switch (widget.tool) {
      case ImageTool.removeBackground:
        return _section('Method', [
          RadioGroup<BackgroundRemovalMode>(
            groupValue: _bgMode,
            onChanged: (v) => setState(() => _bgMode = v ?? _bgMode),
            child: const Column(
              children: [
                RadioListTile(
                  value: BackgroundRemovalMode.ai,
                  title: Text('AI subject detection'),
                  subtitle: Text('People, pets, objects. Runs on-device (model downloads once).'),
                ),
                RadioListTile(
                  value: BackgroundRemovalMode.plainColor,
                  title: Text('Plain background (fully offline)'),
                  subtitle: Text('Best for products or logos on a solid backdrop.'),
                ),
              ],
            ),
          ),
          if (_bgMode == BackgroundRemovalMode.plainColor) ...[
            Text('Tolerance: ${_tolerance.round()}'),
            Slider(
              value: _tolerance,
              min: 10,
              max: 120,
              divisions: 22,
              label: _tolerance.round().toString(),
              onChanged: (v) => setState(() => _tolerance = v),
            ),
          ],
        ]);
      case ImageTool.resize:
        return _section('New size (pixels)', [
          Wrap(
            spacing: 8,
            children: [25, 50, 75]
                .map((pct) => ActionChip(label: Text('$pct%'), onPressed: () => _applyPercent(pct)))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _widthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Width', border: OutlineInputBorder()),
                  onChanged: _onWidthChanged,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×'),
              ),
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height', border: OutlineInputBorder()),
                  onChanged: _onHeightChanged,
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep aspect ratio'),
            value: _keepAspect,
            onChanged: (v) => setState(() => _keepAspect = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Save as PNG'),
            subtitle: const Text('Keeps transparency; larger file than JPG'),
            value: _resizeAsPng,
            onChanged: (v) => setState(() => _resizeAsPng = v),
          ),
        ]);
      case ImageTool.compress:
        return _section('Compression', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Target file size'),
            subtitle: const Text('Find the best quality under a size limit'),
            value: _useTargetSize,
            onChanged: (v) => setState(() => _useTargetSize = v),
          ),
          if (_useTargetSize)
            TextField(
              controller: _targetKbController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max size',
                suffixText: 'KB',
                border: OutlineInputBorder(),
              ),
            )
          else ...[
            Text('Quality: ${_quality.round()}%'),
            Slider(
              value: _quality,
              min: 10,
              max: 95,
              divisions: 17,
              label: '${_quality.round()}%',
              onChanged: (v) => setState(() => _quality = v),
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _maxSide,
            decoration: const InputDecoration(labelText: 'Max dimension', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: null, child: Text('Keep original')),
              DropdownMenuItem(value: 3840, child: Text('3840 px (4K)')),
              DropdownMenuItem(value: 1920, child: Text('1920 px (Full HD)')),
              DropdownMenuItem(value: 1280, child: Text('1280 px (HD)')),
              DropdownMenuItem(value: 800, child: Text('800 px (Web)')),
            ],
            onChanged: (v) => setState(() => _maxSide = v),
          ),
        ]);
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _resultCard(ImageToolResult r) {
    final saved = r.originalBytes - r.outputBytes;
    final pct = r.originalBytes == 0 ? 0 : (saved * 100 / r.originalBytes).round();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 240,
            decoration: widget.tool == ImageTool.removeBackground
                ? const BoxDecoration(
                    // Checkerboard-ish backdrop so transparency is visible.
                    gradient: LinearGradient(
                      colors: [Color(0xFFE5E7EB), Color(0xFFF9FAFB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  )
                : null,
            child: Image.file(r.file, fit: BoxFit.contain, key: ValueKey(r.file.path)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saved ${r.width} × ${r.height} px  •  ${FileUtils.formatBytes(r.outputBytes)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (widget.tool == ImageTool.compress)
                  Text(
                    saved > 0
                        ? '${FileUtils.formatBytes(r.originalBytes)} → ${FileUtils.formatBytes(r.outputBytes)} ($pct% smaller)'
                        : 'Output is not smaller than the original; try a lower quality.',
                    style: TextStyle(color: saved > 0 ? Colors.green : Colors.orange),
                  ),
                if (_usedAi != null && widget.tool == ImageTool.removeBackground)
                  Text(_usedAi! ? 'Method: AI subject detection' : 'Method: plain background (offline)',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(r.file.path, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => OpenFilex.open(r.file.path),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(r.file.path)])),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
