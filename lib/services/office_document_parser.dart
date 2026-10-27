import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

enum OfficeFileType {
  word,
  powerpoint,
  excel,
  csv,
  unknown,
}

// ==========================================
// WORD DOCUMENT MODELS
// ==========================================
class DocParagraph {
  final String text;
  final bool isHeading;
  final int headingLevel;
  final bool isBullet;
  final bool isBold;
  final bool isItalic;
  final List<List<String>>? tableData;

  const DocParagraph({
    required this.text,
    this.isHeading = false,
    this.headingLevel = 0,
    this.isBullet = false,
    this.isBold = false,
    this.isItalic = false,
    this.tableData,
  });

  bool get isTable => tableData != null && tableData!.isNotEmpty;
}

class DocPage {
  final int pageNumber;
  final List<DocParagraph> paragraphs;

  const DocPage({
    required this.pageNumber,
    required this.paragraphs,
  });
}

class ParsedWordDoc {
  final String title;
  final List<DocParagraph> paragraphs;
  final List<DocPage> pages;
  final int wordCount;
  final bool isParsedSuccessfully;
  final String? error;

  const ParsedWordDoc({
    required this.title,
    required this.paragraphs,
    required this.pages,
    required this.wordCount,
    this.isParsedSuccessfully = true,
    this.error,
  });
}

// ==========================================
// POWERPOINT PRESENTATION MODELS
// ==========================================
class PptSlide {
  final int slideNumber;
  final String title;
  final List<String> bullets;
  final List<String> textBlocks;
  final List<List<String>>? table;
  final List<Uint8List> images;

  const PptSlide({
    required this.slideNumber,
    required this.title,
    required this.bullets,
    required this.textBlocks,
    this.table,
    this.images = const [],
  });

  bool get isEmpty =>
      title.isEmpty && bullets.isEmpty && textBlocks.isEmpty && images.isEmpty && table == null;
}

class ParsedPptDoc {
  final String title;
  final List<PptSlide> slides;
  final bool isParsedSuccessfully;
  final String? error;

  const ParsedPptDoc({
    required this.title,
    required this.slides,
    this.isParsedSuccessfully = true,
    this.error,
  });

  int get totalSlides => slides.length;
}

// ==========================================
// EXCEL SPREADSHEET MODELS
// ==========================================
class ExcelSheetData {
  final String name;
  final List<List<String>> rows;
  final int totalRows;
  final int totalColumns;

  const ExcelSheetData({
    required this.name,
    required this.rows,
    required this.totalRows,
    required this.totalColumns,
  });
}

class ParsedExcelDoc {
  final String title;
  final List<ExcelSheetData> sheets;
  final bool isParsedSuccessfully;
  final String? error;

  const ParsedExcelDoc({
    required this.title,
    required this.sheets,
    this.isParsedSuccessfully = true,
    this.error,
  });
}

// ==========================================
// PARSER ENGINE
// ==========================================
class OfficeDocumentParser {
  /// Extensions the in-app Office viewer can open.
  static const Set<String> supportedExtensions = {
    '.docx', '.doc', '.rtf', '.odt', '.pptx', '.ppt', '.xlsx', '.xls', '.csv', '.tsv',
  };

  static OfficeFileType detectFileType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.docx':
      case '.doc':
      case '.rtf':
      case '.odt':
      case '.txt':
        return OfficeFileType.word;
      case '.pptx':
      case '.ppt':
        return OfficeFileType.powerpoint;
      case '.xlsx':
      case '.xls':
        return OfficeFileType.excel;
      case '.csv':
      case '.tsv':
        return OfficeFileType.csv;
      default:
        return OfficeFileType.unknown;
    }
  }

  // -------------------------------------------------------------
  // 1. PARSE WORD (.docx, .doc)
  // -------------------------------------------------------------
  static Future<ParsedWordDoc> parseWord(String filePath) async {
    final fileName = p.basenameWithoutExtension(filePath);
    final ext = p.extension(filePath).toLowerCase();

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ParsedWordDoc(
          title: fileName,
          paragraphs: const [],
          pages: const [],
          wordCount: 0,
          isParsedSuccessfully: false,
          error: 'File does not exist on device.',
        );
      }

      switch (ext) {
        case '.docx':
          return await _parseDocx(file, fileName);
        case '.odt':
          return await _parseOdt(file, fileName);
        case '.rtf':
          return _buildWordDoc(fileName, _rtfToPlainText(await file.readAsString(encoding: latin1)));
        case '.txt':
          return _buildWordDoc(fileName, utf8.decode(await file.readAsBytes(), allowMalformed: true));
        default:
          // Fallback for legacy .doc binary files
          return await _parseBinaryDoc(file, fileName);
      }
    } catch (e, stack) {
      debugPrint('Error parsing Word doc $filePath: $e\n$stack');
      return ParsedWordDoc(
        title: fileName,
        paragraphs: [
          DocParagraph(text: 'Unable to parse document layout: $e'),
        ],
        pages: [
          DocPage(
            pageNumber: 1,
            paragraphs: [DocParagraph(text: 'Error reading file: $e')],
          ),
        ],
        wordCount: 0,
        isParsedSuccessfully: false,
        error: e.toString(),
      );
    }
  }

  static Future<ParsedWordDoc> _parseDocx(File file, String fileName) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) {
      return await _parseBinaryDoc(file, fileName);
    }

    final xmlString = utf8.decode(docFile.content as List<int>);
    final document = XmlDocument.parse(xmlString);

    final List<DocParagraph> parsedParagraphs = [];
    int totalWords = 0;

    void visit(XmlElement container) {
      for (final child in container.childElements) {
        switch (child.name.local) {
          case 'p':
            final pStyle = child.findAllElements('w:pStyle').firstOrNull?.getAttribute('w:val') ?? '';
            final isTitle = pStyle.toLowerCase().contains('title');
            final isHeading1 = pStyle.toLowerCase().contains('heading1');
            final isHeading2 = pStyle.toLowerCase().contains('heading2') || pStyle.toLowerCase().contains('heading3');
            final isBullet = child.findAllElements('w:numPr').isNotEmpty;

            bool isBold = false;
            bool isItalic = false;
            for (final run in child.findAllElements('w:r')) {
              if (_isToggleOn(run.findAllElements('w:b').firstOrNull)) isBold = true;
              if (_isToggleOn(run.findAllElements('w:i').firstOrNull)) isItalic = true;
            }

            final text = _docxText(child).trim();
            if (text.isNotEmpty) {
              totalWords += _countWords(text);
              parsedParagraphs.add(
                DocParagraph(
                  text: text,
                  isHeading: isTitle || isHeading1 || isHeading2,
                  headingLevel: isTitle ? 1 : (isHeading1 ? 2 : (isHeading2 ? 3 : 0)),
                  isBullet: isBullet,
                  isBold: isBold,
                  isItalic: isItalic,
                ),
              );
            }
            break;
          case 'tbl':
            final List<List<String>> tableData = [];
            for (final row in child.findAllElements('w:tr')) {
              final List<String> rowData = [];
              for (final cell in row.findAllElements('w:tc')) {
                final cellText = cell
                    .findAllElements('w:p')
                    .map((para) => _docxText(para).trim())
                    .where((t) => t.isNotEmpty)
                    .join(' ');
                rowData.add(cellText);
              }
              if (rowData.isNotEmpty) {
                tableData.add(rowData);
              }
            }

            if (tableData.isNotEmpty) {
              parsedParagraphs.add(
                DocParagraph(
                  text: 'Table with ${tableData.length} rows',
                  tableData: _padRows(tableData),
                ),
              );
            }
            break;
          case 'sdt':
          case 'sdtContent':
          case 'customXml':
          case 'ins':
            // Content controls (cover pages, TOCs) and tracked insertions wrap regular paragraphs
            visit(child);
            break;
        }
      }
    }

    final body = document.findAllElements('w:body').firstOrNull;
    if (body != null) visit(body);

    if (parsedParagraphs.isEmpty) {
      parsedParagraphs.add(const DocParagraph(text: 'This document contains no readable text.'));
    }

    // Partition paragraphs into readable pages (approx. 4-6 paragraphs or ~250 words per page)
    final List<DocPage> pages = _paginateParagraphs(parsedParagraphs);

    return ParsedWordDoc(
      title: fileName,
      paragraphs: parsedParagraphs,
      pages: pages,
      wordCount: totalWords,
    );
  }

  static Future<ParsedWordDoc> _parseOdt(File file, String fileName) async {
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final contentFile = archive.findFile('content.xml');
    if (contentFile == null) {
      return _buildWordDoc(fileName, '');
    }

    final document = XmlDocument.parse(utf8.decode(contentFile.content as List<int>));
    final List<DocParagraph> paragraphs = [];
    int totalWords = 0;

    for (final el in document.descendantElements) {
      final isHeading = el.name.qualified == 'text:h';
      if (!isHeading && el.name.qualified != 'text:p') continue;
      // Skip paragraphs nested inside another paragraph (e.g. notes); the parent already includes them
      if (el.ancestorElements.any((a) => a.name.qualified == 'text:p' || a.name.qualified == 'text:h')) continue;

      final text = _odtText(el).trim();
      if (text.isEmpty) continue;
      totalWords += _countWords(text);

      final level = int.tryParse(el.getAttribute('text:outline-level') ?? '') ?? 1;
      paragraphs.add(
        DocParagraph(
          text: text,
          isHeading: isHeading,
          headingLevel: isHeading ? level.clamp(1, 3) : 0,
          isBullet: el.ancestorElements.any((a) => a.name.qualified == 'text:list-item'),
        ),
      );
    }

    if (paragraphs.isEmpty) {
      paragraphs.add(const DocParagraph(text: 'This document contains no readable text.'));
    }

    return ParsedWordDoc(
      title: fileName,
      paragraphs: paragraphs,
      pages: _paginateParagraphs(paragraphs),
      wordCount: totalWords,
    );
  }

  static Future<ParsedWordDoc> _parseBinaryDoc(File file, String fileName) async {
    final bytes = await file.readAsBytes();
    return _buildWordDoc(
      fileName,
      _extractStringsFromBinary(bytes),
      emptyMessage: 'No readable text could be extracted from this binary file.',
    );
  }

  /// Builds a document from plain text, one paragraph per non-empty line.
  static ParsedWordDoc _buildWordDoc(
    String fileName,
    String content, {
    String emptyMessage = 'This document contains no readable text.',
  }) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final List<DocParagraph> paragraphs = [];
    int totalWords = 0;

    for (final line in lines) {
      totalWords += _countWords(line);
      paragraphs.add(DocParagraph(text: line));
    }

    if (paragraphs.isEmpty) {
      paragraphs.add(DocParagraph(text: emptyMessage));
    }

    return ParsedWordDoc(
      title: fileName,
      paragraphs: paragraphs,
      pages: _paginateParagraphs(paragraphs),
      wordCount: totalWords,
    );
  }

  static int _countWords(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  /// `<w:b/>` means on; `<w:b w:val="0"/>` or `"false"` explicitly turns it off.
  static bool _isToggleOn(XmlElement? el) {
    if (el == null) return false;
    final val = el.getAttribute('w:val');
    return val == null || !(val == '0' || val == 'false' || val == 'off');
  }

  static String _docxText(XmlElement paragraph) {
    final sb = StringBuffer();
    for (final el in paragraph.descendantElements) {
      switch (el.name.qualified) {
        case 'w:t':
          sb.write(el.innerText);
          break;
        case 'w:tab':
          // w:tab inside w:pPr/w:tabs is a tab-stop definition, not a character
          if (el.parentElement?.name.local == 'r') sb.write('\t');
          break;
        case 'w:br':
        case 'w:cr':
          sb.write('\n');
          break;
      }
    }
    return sb.toString();
  }

  static String _odtText(XmlElement el) {
    final sb = StringBuffer();
    for (final node in el.children) {
      if (node is XmlText) {
        sb.write(node.value);
      } else if (node is XmlElement) {
        switch (node.name.qualified) {
          case 'text:s':
            sb.write(' ' * (int.tryParse(node.getAttribute('text:c') ?? '') ?? 1));
            break;
          case 'text:tab':
            sb.write('\t');
            break;
          case 'text:line-break':
            sb.write('\n');
            break;
          case 'text:note':
          case 'office:annotation':
            break;
          default:
            sb.write(_odtText(node));
        }
      }
    }
    return sb.toString();
  }

  /// Strips RTF control words and groups, keeping the visible text.
  static String _rtfToPlainText(String rtf) {
    const skipDestinations = {
      'fonttbl', 'colortbl', 'stylesheet', 'info', 'pict', 'header', 'footer',
      'headerl', 'headerr', 'footerl', 'footerr', 'listtable', 'listoverridetable',
      'rsidtbl', 'generator', 'xmlnstbl', 'themedata', 'colorschememapping',
      'latentstyles', 'datastore', 'object', 'fldinst', 'filetbl', 'revtbl',
    };
    final sb = StringBuffer();
    // Per group: whether its content is hidden
    final skipStack = <bool>[false];
    int i = 0;

    while (i < rtf.length) {
      final ch = rtf[i];
      final skipping = skipStack.last;
      if (ch == '{') {
        skipStack.add(skipping);
        i++;
      } else if (ch == '}') {
        if (skipStack.length > 1) skipStack.removeLast();
        i++;
      } else if (ch == '\\') {
        i++;
        if (i >= rtf.length) break;
        final next = rtf[i];
        if (next == '\\' || next == '{' || next == '}') {
          if (!skipping) sb.write(next);
          i++;
        } else if (next == '*') {
          skipStack[skipStack.length - 1] = true;
          i++;
        } else if (next == "'") {
          final hex = i + 2 < rtf.length ? rtf.substring(i + 1, i + 3) : '';
          final code = int.tryParse(hex, radix: 16);
          if (!skipping && code != null) sb.writeCharCode(code);
          i += 3;
        } else if (RegExp(r'[a-zA-Z]').hasMatch(next)) {
          final match = RegExp(r'([a-zA-Z]+)(-?\d+)? ?').matchAsPrefix(rtf, i)!;
          final word = match.group(1)!;
          final param = int.tryParse(match.group(2) ?? '');
          i = match.end;
          if (skipDestinations.contains(word)) {
            skipStack[skipStack.length - 1] = true;
          } else if (!skipping) {
            switch (word) {
              case 'par':
              case 'line':
              case 'row':
                sb.write('\n');
                break;
              case 'tab':
              case 'cell':
                sb.write('\t');
                break;
              case 'u':
                if (param != null) sb.writeCharCode(param < 0 ? param + 65536 : param);
                // Skip the ANSI fallback character that follows \uN
                if (i < rtf.length && rtf[i] != '\\' && rtf[i] != '{' && rtf[i] != '}') i++;
                break;
            }
          }
        } else {
          // Control symbols such as \~ (non-breaking space) or \- (optional hyphen)
          if (!skipping && next == '~') sb.write(' ');
          i++;
        }
      } else {
        if (!skipping && ch != '\r' && ch != '\n') sb.write(ch);
        i++;
      }
    }

    return sb.toString();
  }

  static List<DocPage> _paginateParagraphs(List<DocParagraph> paragraphs) {
    final List<DocPage> pages = [];
    List<DocParagraph> current = [];
    int currentWords = 0;

    for (final p in paragraphs) {
      final words = p.text.split(RegExp(r'\s+')).length;
      if (current.isNotEmpty && (currentWords + words > 280 || current.length >= 6 || p.isHeading)) {
        pages.add(DocPage(pageNumber: pages.length + 1, paragraphs: List.from(current)));
        current.clear();
        currentWords = 0;
      }
      current.add(p);
      currentWords += words;
    }

    if (current.isNotEmpty || pages.isEmpty) {
      pages.add(DocPage(pageNumber: pages.length + 1, paragraphs: current));
    }

    return pages;
  }

  // -------------------------------------------------------------
  // 2. PARSE POWERPOINT (.pptx, .ppt)
  // -------------------------------------------------------------
  static Future<ParsedPptDoc> parsePowerPoint(String filePath) async {
    final fileName = p.basenameWithoutExtension(filePath);
    final ext = p.extension(filePath).toLowerCase();

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ParsedPptDoc(
          title: fileName,
          slides: const [],
          isParsedSuccessfully: false,
          error: 'File does not exist.',
        );
      }

      if (ext == '.pptx') {
        return await _parsePptx(file, fileName);
      } else {
        return await _parseBinaryPpt(file, fileName);
      }
    } catch (e, stack) {
      debugPrint('Error parsing PowerPoint $filePath: $e\n$stack');
      return ParsedPptDoc(
        title: fileName,
        slides: [
          PptSlide(
            slideNumber: 1,
            title: fileName,
            bullets: ['Error reading presentation: $e'],
            textBlocks: const [],
          ),
        ],
        isParsedSuccessfully: false,
        error: e.toString(),
      );
    }
  }

  static Future<ParsedPptDoc> _parsePptx(File file, String fileName) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find all slide XML files
    final slideFiles = archive.files
        .where((f) => RegExp(r'ppt/slides/slide\d+\.xml$').hasMatch(f.name))
        .toList();

    // Sort slide files numerically
    slideFiles.sort((a, b) {
      final numA = int.tryParse(RegExp(r'\d+').stringMatch(a.name) ?? '0') ?? 0;
      final numB = int.tryParse(RegExp(r'\d+').stringMatch(b.name) ?? '0') ?? 0;
      return numA.compareTo(numB);
    });

    final List<PptSlide> parsedSlides = [];

    for (int i = 0; i < slideFiles.length; i++) {
      final slideFile = slideFiles[i];
      final xmlString = utf8.decode(slideFile.content as List<int>);
      final doc = XmlDocument.parse(xmlString);

      String slideTitle = '';
      final List<String> bullets = [];
      final List<String> textBlocks = [];
      List<List<String>>? table;

      // Extract shapes
      for (final sp in doc.findAllElements('p:sp')) {
        final ph = sp.findAllElements('p:ph').firstOrNull;
        final phType = ph?.getAttribute('type') ?? '';
        final isTitleShape = phType == 'title' || phType == 'ctrTitle';
        // Body placeholders are bulleted by the slide layout unless a paragraph turns it off
        final isBodyShape = ph != null && (phType.isEmpty || phType == 'body' || phType == 'obj');

        final paragraphs = sp.findAllElements('a:p');
        for (final p in paragraphs) {
          final text = p.findAllElements('a:t').map((e) => e.innerText).join('').trim();
          if (text.isEmpty) continue;

          final pPr = p.getElement('a:pPr');
          final hasBulletMarker = pPr != null &&
              (pPr.getAttribute('lvl') != null ||
                  pPr.getElement('a:buChar') != null ||
                  pPr.getElement('a:buAutoNum') != null);
          final bulletsOff = pPr?.getElement('a:buNone') != null;

          if (isTitleShape && slideTitle.isEmpty) {
            slideTitle = text;
          } else if (!bulletsOff && (hasBulletMarker || isBodyShape)) {
            bullets.add(text);
          } else {
            textBlocks.add(text);
          }
        }
      }

      // If no title was explicitly marked as title placeholder, pick the first text block
      if (slideTitle.isEmpty && textBlocks.isNotEmpty) {
        slideTitle = textBlocks.removeAt(0);
      }

      // Extract tables
      final tblElement = doc.findAllElements('a:tbl').firstOrNull;
      if (tblElement != null) {
        final List<List<String>> rows = [];
        for (final tr in tblElement.findAllElements('a:tr')) {
          final List<String> row = [];
          for (final tc in tr.findAllElements('a:tc')) {
            final cellText = tc.findAllElements('a:t').map((e) => e.innerText).join(' ').trim();
            row.add(cellText);
          }
          if (row.isNotEmpty) rows.add(row);
        }
        if (rows.isNotEmpty) table = _padRows(rows);
      }

      parsedSlides.add(
        PptSlide(
          slideNumber: i + 1,
          title: slideTitle.isNotEmpty ? slideTitle : 'Slide ${i + 1}',
          bullets: bullets,
          textBlocks: textBlocks,
          table: table,
        ),
      );
    }

    if (parsedSlides.isEmpty) {
      parsedSlides.add(
        PptSlide(
          slideNumber: 1,
          title: fileName,
          bullets: const ['Empty or unsupported presentation'],
          textBlocks: const [],
        ),
      );
    }

    return ParsedPptDoc(title: fileName, slides: parsedSlides);
  }

  static Future<ParsedPptDoc> _parseBinaryPpt(File file, String fileName) async {
    final bytes = await file.readAsBytes();
    final rawStrings = _extractStringsFromBinary(bytes);

    final lines = rawStrings
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.length > 3)
        .toList();

    final List<PptSlide> slides = [];
    List<String> currentBullets = [];
    String currentTitle = '';
    int slideIndex = 1;

    for (final line in lines) {
      if (currentTitle.isEmpty) {
        currentTitle = line;
      } else if (currentBullets.length < 5) {
        currentBullets.add(line);
      } else {
        slides.add(
          PptSlide(
            slideNumber: slideIndex++,
            title: currentTitle,
            bullets: List.from(currentBullets),
            textBlocks: const [],
          ),
        );
        currentTitle = line;
        currentBullets.clear();
      }
    }

    if (currentTitle.isNotEmpty || slides.isEmpty) {
      slides.add(
        PptSlide(
          slideNumber: slideIndex,
          title: currentTitle.isNotEmpty ? currentTitle : fileName,
          bullets: currentBullets,
          textBlocks: const [],
        ),
      );
    }

    return ParsedPptDoc(title: fileName, slides: slides);
  }

  // -------------------------------------------------------------
  // 3. PARSE EXCEL & SPREADSHEETS (.xlsx, .xls, .csv, .tsv)
  // -------------------------------------------------------------
  static Future<ParsedExcelDoc> parseExcel(String filePath) async {
    final fileName = p.basenameWithoutExtension(filePath);
    final ext = p.extension(filePath).toLowerCase();

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ParsedExcelDoc(
          title: fileName,
          sheets: const [],
          isParsedSuccessfully: false,
          error: 'File does not exist.',
        );
      }

      if (ext == '.csv' || ext == '.tsv') {
        return await _parseCsv(file, fileName, ext == '.tsv');
      } else if (ext == '.xlsx') {
        return await _parseXlsx(file, fileName);
      } else {
        // Fallback for .xls
        return await _parseBinaryXls(file, fileName);
      }
    } catch (e, stack) {
      debugPrint('Error parsing spreadsheet $filePath: $e\n$stack');
      return ParsedExcelDoc(
        title: fileName,
        sheets: [
          ExcelSheetData(
            name: 'Error',
            rows: [
              ['Could not read spreadsheet', e.toString()],
            ],
            totalRows: 1,
            totalColumns: 2,
          ),
        ],
        isParsedSuccessfully: false,
        error: e.toString(),
      );
    }
  }

  static Future<ParsedExcelDoc> _parseXlsx(File file, String fileName) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Parse Shared Strings
    final List<String> sharedStrings = [];
    final sstFile = archive.findFile('xl/sharedStrings.xml');
    if (sstFile != null) {
      final sstXml = utf8.decode(sstFile.content as List<int>);
      final doc = XmlDocument.parse(sstXml);
      for (final si in doc.findAllElements('si')) {
        // Skip phonetic guides (rPh), which also contain <t> elements
        final text = si
            .findAllElements('t')
            .where((t) => !t.ancestorElements.any((a) => a.name.local == 'rPh'))
            .map((e) => e.innerText)
            .join('');
        sharedStrings.add(text);
      }
    }

    // 2. Parse Workbook Sheets (in tab order) and resolve their worksheet files
    final Map<String, String> relTargets = {};
    final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
    if (relsFile != null) {
      final doc = XmlDocument.parse(utf8.decode(relsFile.content as List<int>));
      for (final rel in doc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id == null || target == null) continue;
        relTargets[id] = target.startsWith('/') ? target.substring(1) : p.posix.normalize('xl/$target');
      }
    }

    final List<(String, ArchiveFile)> sheetEntries = [];
    final wbFile = archive.findFile('xl/workbook.xml');
    if (wbFile != null) {
      final wbXml = utf8.decode(wbFile.content as List<int>);
      final doc = XmlDocument.parse(wbXml);
      final sheets = doc.findAllElements('sheet').toList();
      for (int i = 0; i < sheets.length; i++) {
        final s = sheets[i];
        final name = s.getAttribute('name') ?? 'Sheet ${i + 1}';
        final relId = s.attributes.where((a) => a.name.local == 'id').firstOrNull?.value;
        final target = relTargets[relId];
        final sheetFile = archive.findFile(target ?? 'xl/worksheets/sheet${i + 1}.xml');
        if (sheetFile != null) sheetEntries.add((name, sheetFile));
      }
    }

    if (sheetEntries.isEmpty) {
      // No usable workbook.xml: fall back to the worksheet files in numeric order
      final sheetFiles = archive.files
          .where((f) => RegExp(r'xl/worksheets/sheet\d+\.xml$').hasMatch(f.name))
          .toList();
      sheetFiles.sort((a, b) {
        final numA = int.tryParse(RegExp(r'\d+').stringMatch(a.name) ?? '0') ?? 0;
        final numB = int.tryParse(RegExp(r'\d+').stringMatch(b.name) ?? '0') ?? 0;
        return numA.compareTo(numB);
      });
      for (int i = 0; i < sheetFiles.length; i++) {
        sheetEntries.add(('Sheet ${i + 1}', sheetFiles[i]));
      }
    }

    // 3. Parse Worksheet Data
    final List<ExcelSheetData> parsedSheets = [];

    for (final (sheetTitle, sheetFile) in sheetEntries) {
      final sheetXml = utf8.decode(sheetFile.content as List<int>);
      final doc = XmlDocument.parse(sheetXml);

      final List<List<String>> rows = [];
      int maxCols = 0;

      for (final rowElem in doc.findAllElements('row')) {
        final List<String> rowCells = [];
        for (final c in rowElem.findAllElements('c')) {
          // Empty cells are omitted from the XML, so place each cell by its reference (e.g. "C2")
          final col = _columnIndex(c.getAttribute('r'));
          if (col != null) {
            while (rowCells.length < col) {
              rowCells.add('');
            }
          }

          final type = c.getAttribute('t') ?? '';
          final vElem = c.findAllElements('v').firstOrNull;
          String val = '';

          if (type == 's' && vElem != null) {
            final idx = int.tryParse(vElem.innerText) ?? -1;
            if (idx >= 0 && idx < sharedStrings.length) {
              val = sharedStrings[idx];
            }
          } else if (type == 'inlineStr') {
            val = c.findAllElements('t').map((e) => e.innerText).join('');
          } else if (type == 'b' && vElem != null) {
            val = vElem.innerText == '1' ? 'TRUE' : 'FALSE';
          } else if (vElem != null) {
            val = vElem.innerText;
          }

          rowCells.add(val);
        }

        while (rowCells.isNotEmpty && rowCells.last.isEmpty) {
          rowCells.removeLast();
        }
        if (rowCells.isNotEmpty) {
          if (rowCells.length > maxCols) maxCols = rowCells.length;
          rows.add(rowCells);
        }
      }

      parsedSheets.add(
        ExcelSheetData(
          name: sheetTitle,
          rows: _padRows(rows),
          totalRows: rows.length,
          totalColumns: maxCols,
        ),
      );
    }

    if (parsedSheets.isEmpty) {
      parsedSheets.add(
        const ExcelSheetData(
          name: 'Sheet1',
          rows: [
            ['Empty Sheet'],
          ],
          totalRows: 1,
          totalColumns: 1,
        ),
      );
    }

    return ParsedExcelDoc(title: fileName, sheets: parsedSheets);
  }

  static Future<ParsedExcelDoc> _parseCsv(File file, String fileName, bool isTsv) async {
    var content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    if (content.startsWith('﻿')) content = content.substring(1);
    final rows = _parseDelimited(content, isTsv ? '\t' : ',');
    int maxCols = 0;
    for (final row in rows) {
      if (row.length > maxCols) maxCols = row.length;
    }

    return ParsedExcelDoc(
      title: fileName,
      sheets: [
        ExcelSheetData(
          name: fileName,
          rows: _padRows(rows),
          totalRows: rows.length,
          totalColumns: maxCols,
        ),
      ],
    );
  }

  static Future<ParsedExcelDoc> _parseBinaryXls(File file, String fileName) async {
    final bytes = await file.readAsBytes();
    final extracted = _extractStringsFromBinary(bytes);
    final lines = extracted.split('\n').where((l) => l.trim().isNotEmpty).toList();

    final List<List<String>> rows = [];
    for (int i = 0; i < lines.length; i += 4) {
      final chunk = lines.sublist(i, (i + 4 < lines.length) ? i + 4 : lines.length);
      rows.add(chunk);
    }

    return ParsedExcelDoc(
      title: fileName,
      sheets: [
        ExcelSheetData(
          name: 'Extracted Data',
          rows: _padRows(rows),
          totalRows: rows.length,
          totalColumns: 4,
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // HELPER: CONVERT DOCX TO HIGH-RES PDF
  // -------------------------------------------------------------
  static Future<File> convertWordDocToPdf(ParsedWordDoc doc) async {
    final pdf = pw.Document(
      title: doc.title,
      author: 'File Explore by yjtechnosoft',
    );

    final paraStyle = pw.TextStyle(fontSize: 10.5, lineSpacing: 2.5);

    // MultiPage lets long paragraphs and tables flow onto following pages instead of being cut off
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  doc.title,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                ),
              ],
            ),
            pw.Divider(thickness: 0.8, color: PdfColors.grey300),
            pw.SizedBox(height: 12),
          ],
        ),
        // Text and Table only split across pages when they are direct MultiPage children
        // (not wrapped in Padding or Row), so spacing is added with separate SizedBoxes.
        build: (pw.Context context) => doc.paragraphs.expand<pw.Widget>((p) {
          if (p.isTable && p.tableData != null) {
            return [
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                data: p.tableData!,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.all(4),
              ),
              pw.SizedBox(height: 8),
            ];
          }

          if (p.isHeading) {
            return [
              pw.SizedBox(height: 6),
              pw.Text(
                p.text,
                style: pw.TextStyle(
                  fontSize: p.headingLevel == 1 ? 18 : 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 6),
            ];
          }

          final style = paraStyle.copyWith(
            fontWeight: p.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: p.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
          );

          return [
            pw.SizedBox(height: 3),
            pw.Text(
              p.isBullet ? '•  ${p.text}' : p.text,
              style: style,
              overflow: pw.TextOverflow.span,
            ),
            pw.SizedBox(height: 3),
          ];
        }).toList(),
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final cleanTitle = doc.title.replaceAll(RegExp(r'[^\w\-_.]'), '_');
    final outPath = p.join(tempDir.path, '${cleanTitle}_doc.pdf');
    final pdfFile = File(outPath);
    await pdfFile.writeAsBytes(await pdf.save());
    return pdfFile;
  }

  // -------------------------------------------------------------
  // HELPER: CONVERT PPTX TO SLIDE-BASED PDF
  // -------------------------------------------------------------
  static Future<File> convertPptToPdf(ParsedPptDoc ppt) async {
    final pdf = pw.Document(
      title: ppt.title,
      author: 'File Explore Presentation Engine',
    );

    // Presentation format: Landscape 16:9 or A4 Landscape
    const format = PdfPageFormat(297 * PdfPageFormat.mm, 210 * PdfPageFormat.mm, marginAll: 24);

    for (final slide in ppt.slides) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColors.white,
              ),
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Slide Title Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          slide.title,
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.deepOrange800,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'Slide ${slide.slideNumber} / ${ppt.slides.length}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 1.5, color: PdfColors.deepOrange600),
                  pw.SizedBox(height: 16),

                  // Bullets
                  ...slide.bullets.map((b) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('• ', style: pw.TextStyle(fontSize: 16, color: PdfColors.deepOrange)),
                            pw.Expanded(
                              child: pw.Text(
                                b,
                                style: const pw.TextStyle(fontSize: 14, lineSpacing: 2),
                              ),
                            ),
                          ],
                        ),
                      )),

                  // Text Blocks
                  ...slide.textBlocks.map((t) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(t, style: const pw.TextStyle(fontSize: 13, lineSpacing: 2)),
                      )),

                  // Table if present
                  if (slide.table != null)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 12),
                      child: pw.TableHelper.fromTextArray(
                        data: slide.table!,
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        headerDecoration: const pw.BoxDecoration(color: PdfColors.deepOrange800),
                        cellStyle: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    final tempDir = await getTemporaryDirectory();
    final cleanTitle = ppt.title.replaceAll(RegExp(r'[^\w\-_.]'), '_');
    final outPath = p.join(tempDir.path, '${cleanTitle}_slides.pdf');
    final pdfFile = File(outPath);
    await pdfFile.writeAsBytes(await pdf.save());
    return pdfFile;
  }

  // -------------------------------------------------------------
  // HELPER: CONVERT SPREADSHEET TO PDF TABLE
  // -------------------------------------------------------------
  static Future<File> convertSpreadsheetToPdf(ExcelSheetData sheet, String title) async {
    final pdf = pw.Document(
      title: title,
      author: 'File Explore Spreadsheet Engine',
    );

    // One MultiPage table: rows flow onto as many pages as needed and the header row repeats
    // on each page (splitting into fixed pages used to turn every page's first data row into a header)
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$title - ${sheet.name}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount} (${sheet.totalRows} total rows)',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.green700),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (pw.Context context) => [
          if (sheet.rows.isEmpty)
            pw.Text('This sheet is empty.', style: const pw.TextStyle(color: PdfColors.grey700))
          else
            pw.TableHelper.fromTextArray(
              data: sheet.rows,
              headerCount: 1,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellPadding: const pw.EdgeInsets.all(3),
            ),
        ],
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final cleanTitle = title.replaceAll(RegExp(r'[^\w\-_.]'), '_');
    final outPath = p.join(tempDir.path, '${cleanTitle}_sheet.pdf');
    final pdfFile = File(outPath);
    await pdfFile.writeAsBytes(await pdf.save());
    return pdfFile;
  }

  // -------------------------------------------------------------
  // INTERNAL UTILITIES
  // -------------------------------------------------------------
  static String _extractStringsFromBinary(Uint8List bytes) {
    final buffer = StringBuffer();
    final len = bytes.length;
    int i = 0;

    bool isPrintable(int b) => b >= 32 && b <= 126;

    while (i < len) {
      // Legacy Office files (Word 97+, PowerPoint, Excel BIFF8) store most text as UTF-16LE,
      // i.e. a printable byte followed by 0x00, which the plain ASCII scan below would miss.
      if (i + 1 < len && isPrintable(bytes[i]) && bytes[i + 1] == 0) {
        final start = i;
        final codes = <int>[];
        while (i + 1 < len && bytes[i + 1] == 0 && (isPrintable(bytes[i]) || bytes[i] == 13 || bytes[i] == 9)) {
          codes.add(bytes[i] == 13 ? 10 : bytes[i]);
          i += 2;
        }
        if (codes.length >= 4) {
          buffer.writeln(String.fromCharCodes(codes));
          continue;
        }
        i = start;
      }

      if (isPrintable(bytes[i])) {
        int start = i;
        while (i < len && bytes[i] >= 32 && bytes[i] <= 126) {
          i++;
        }
        if (i - start >= 4) {
          final s = String.fromCharCodes(bytes.sublist(start, i));
          buffer.writeln(s);
        }
      } else {
        i++;
      }
    }

    return buffer.toString();
  }

  /// RFC 4180 parsing: quoted fields may contain delimiters, newlines and doubled quotes ("").
  static List<List<String>> _parseDelimited(String content, String delimiter) {
    final List<List<String>> rows = [];
    List<String> row = [];
    final StringBuffer sb = StringBuffer();
    bool insideQuotes = false;

    void endRow() {
      row.add(sb.toString().trim());
      sb.clear();
      if (row.any((c) => c.isNotEmpty)) rows.add(row);
      row = [];
    }

    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (insideQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            sb.write('"');
            i++;
          } else {
            insideQuotes = false;
          }
        } else {
          sb.write(char);
        }
      } else if (char == '"') {
        insideQuotes = true;
      } else if (char == delimiter) {
        row.add(sb.toString().trim());
        sb.clear();
      } else if (char == '\n') {
        endRow();
      } else if (char != '\r') {
        sb.write(char);
      }
    }
    if (sb.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  /// Pads every row to the widest row's length. Flutter's Table and the PDF table both need
  /// rectangular data, while merged cells, sparse sheets and CSV files produce ragged rows.
  static List<List<String>> _padRows(List<List<String>> rows) {
    int width = 0;
    for (final row in rows) {
      if (row.length > width) width = row.length;
    }
    return [
      for (final row in rows)
        row.length == width ? row : [...row, ...List.filled(width - row.length, '')],
    ];
  }

  /// Converts a cell reference like "C2" or "AA10" to a zero-based column index.
  static int? _columnIndex(String? cellRef) {
    if (cellRef == null) return null;
    final letters = RegExp(r'^[A-Za-z]+').stringMatch(cellRef);
    if (letters == null) return null;
    int index = 0;
    for (final code in letters.toUpperCase().codeUnits) {
      index = index * 26 + (code - 64);
    }
    return index - 1;
  }
}
