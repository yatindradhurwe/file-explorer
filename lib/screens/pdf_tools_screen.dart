import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import '../models/file_item.dart';
import '../services/media_tools_service.dart';
import '../services/storage_service.dart';
import '../utils/file_utils.dart';
import 'pdf_viewer_screen.dart';

enum PdfTool { compress, resize }

class _CompressLevel {
  final String label;
  final String description;
  final double dpi;
  final int quality;

  const _CompressLevel(this.label, this.description, this.dpi, this.quality);
}

const _levels = [
  _CompressLevel('Low', 'Best quality, smaller savings', 150, 80),
  _CompressLevel('Recommended', 'Good quality, good compression', 110, 65),
  _CompressLevel('Extreme', 'Smallest file, lower quality', 72, 45),
];

const _paperSizes = <String, PdfPageFormat>{
  'A4': PdfPageFormat.a4,
  'A5': PdfPageFormat.a5,
  'A3': PdfPageFormat.a3,
  'Letter': PdfPageFormat.letter,
  'Legal': PdfPageFormat.legal,
};

class PdfToolsScreen extends StatefulWidget {
  final PdfTool tool;

  const PdfToolsScreen({super.key, required this.tool});

  @override
  State<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends State<PdfToolsScreen> {
  List<FileItem> _pdfs = [];
  bool _loading = true;
  String _query = '';

  FileItem? _selected;
  int _levelIndex = 1;
  String _paper = 'A4';
  bool _grayscale = false;

  bool _busy = false;
  int _pagesDone = 0;
  PdfToolResult? _result;

  String get _title => widget.tool == PdfTool.compress ? 'PDF Compressor' : 'PDF Resize';
  Color get _color => widget.tool == PdfTool.compress ? Colors.red : Colors.blueGrey;

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    setState(() => _loading = true);
    try {
      final docs = await StorageService.getCategoryFiles(category: FileCategory.document);
      final pdfs = docs.where((f) => f.extension.toLowerCase() == '.pdf' || f.extension.toLowerCase() == 'pdf').toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));
      if (mounted) setState(() => _pdfs = pdfs);
    } catch (_) {
      if (mounted) setState(() => _pdfs = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _process() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _busy = true;
      _pagesDone = 0;
      _result = null;
    });
    try {
      final level = _levels[_levelIndex];
      final result = await MediaToolsService.rebuildPdf(
        source: File(selected.path),
        // Resizing keeps good quality; compression level drives dpi/quality.
        dpi: widget.tool == PdfTool.compress ? level.dpi : 150,
        quality: widget.tool == PdfTool.compress ? level.quality : 85,
        pageFormat: widget.tool == PdfTool.resize ? _paperSizes[_paper] : null,
        grayscale: _grayscale,
        suffix: widget.tool == PdfTool.compress ? 'compressed' : _paper.toLowerCase(),
        onProgress: (done) {
          if (mounted) setState(() => _pagesDone = done);
        },
      );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _busy ? null : _loadPdfs,
          ),
        ],
      ),
      body: _selected == null ? _pdfList() : _workspace(),
    );
  }

  Widget _pdfList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final filtered = _query.isEmpty
        ? _pdfs
        : _pdfs.where((f) => f.name.toLowerCase().contains(_query.toLowerCase())).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search PDFs',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No PDF files found on this device'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final f = filtered[i];
                    return ListTile(
                      leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                      title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${FileUtils.formatBytes(f.size)}  •  ${FileUtils.formatDate(f.modified)}'),
                      onTap: () => setState(() {
                        _selected = f;
                        _result = null;
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _workspace() {
    final selected = _selected!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 36),
            title: Text(selected.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(FileUtils.formatBytes(selected.size)),
            trailing: TextButton(
              onPressed: _busy ? null : () => setState(() => _selected = null),
              child: const Text('Change'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.tool == PdfTool.compress) ...[
                  const Text('Compression level', style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioGroup<int>(
                    groupValue: _levelIndex,
                    onChanged: (v) => setState(() => _levelIndex = v ?? _levelIndex),
                    child: Column(
                      children: [
                        for (var i = 0; i < _levels.length; i++)
                          RadioListTile<int>(
                            value: i,
                            contentPadding: EdgeInsets.zero,
                            title: Text(_levels[i].label),
                            subtitle: Text(_levels[i].description),
                          ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text('Target page size', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _paperSizes.keys
                        .map((name) => ChoiceChip(
                              label: Text(name),
                              selected: _paper == name,
                              onSelected: (_) => setState(() => _paper = name),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Each page is scaled to fit the new paper size, keeping its orientation.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Convert to black & white'),
                  value: _grayscale,
                  onChanged: (v) => setState(() => _grayscale = v),
                ),
                const Text(
                  'Pages are re-rendered as images on your device, so text will no longer be selectable.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _color,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _busy ? null : _process,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(widget.tool == PdfTool.compress ? Icons.compress_rounded : Icons.aspect_ratio_rounded),
          label: Text(_busy ? 'Processing page ${_pagesDone + 1}...' : _title),
        ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          _resultCard(_result!),
        ],
      ],
    );
  }

  Widget _resultCard(PdfToolResult r) {
    final saved = r.originalBytes - r.outputBytes;
    final pct = r.originalBytes == 0 ? 0 : (saved * 100 / r.originalBytes).round();
    final smaller = saved > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${r.pageCount} page${r.pageCount == 1 ? '' : 's'}  •  ${FileUtils.formatBytes(r.outputBytes)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              smaller
                  ? '${FileUtils.formatBytes(r.originalBytes)} → ${FileUtils.formatBytes(r.outputBytes)} ($pct% smaller)'
                  : '${FileUtils.formatBytes(r.originalBytes)} → ${FileUtils.formatBytes(r.outputBytes)}'
                      '${widget.tool == PdfTool.compress ? ' (already well optimised; try Extreme)' : ''}',
              style: TextStyle(color: smaller ? Colors.green : Colors.orange),
            ),
            const SizedBox(height: 4),
            Text(r.file.path, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(filePath: r.file.path, title: p.basename(r.file.path)),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 12),
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
    );
  }
}
