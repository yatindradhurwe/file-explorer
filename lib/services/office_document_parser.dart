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
  static OfficeFileType detectFileType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.docx':
      case '.doc':
      case '.rtf':
      case '.odt':
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

      if (ext == '.docx') {
        return await _parseDocx(file, fileName);
      } else {
        // Fallback for legacy .doc / .rtf binary files
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

    final body = document.findAllElements('w:body').firstOrNull;
    if (body != null) {
      for (final child in body.children) {
        if (child is! XmlElement) continue;

        if (child.name.local == 'p') {
          // Paragraph
          final pStyle = child.findAllElements('w:pStyle').firstOrNull?.getAttribute('w:val') ?? '';
          final isTitle = pStyle.toLowerCase().contains('title');
          final isHeading1 = pStyle.toLowerCase().contains('heading1');
          final isHeading2 = pStyle.toLowerCase().contains('heading2') || pStyle.toLowerCase().contains('heading3');
          final isBullet = child.findAllElements('w:numPr').isNotEmpty;

          final StringBuffer sb = StringBuffer();
          bool isBold = false;
          bool isItalic = false;

          for (final run in child.findAllElements('w:r')) {
            if (run.findAllElements('w:b').isNotEmpty) isBold = true;
            if (run.findAllElements('w:i').isNotEmpty) isItalic = true;

            for (final t in run.findAllElements('w:t')) {
              sb.write(t.innerText);
            }
          }

          final text = sb.toString().trim();
          if (text.isNotEmpty) {
            final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
            totalWords += words;

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
        } else if (child.name.local == 'tbl') {
          // Table
          final List<List<String>> tableData = [];
          for (final row in child.findAllElements('w:tr')) {
            final List<String> rowData = [];
            for (final cell in row.findAllElements('w:tc')) {
              final cellText = cell
                  .findAllElements('w:t')
                  .map((e) => e.innerText)
                  .join(' ')
                  .trim();
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
                tableData: tableData,
              ),
            );
          }
        }
      }
    }

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

  static Future<ParsedWordDoc> _parseBinaryDoc(File file, String fileName) async {
    final bytes = await file.readAsBytes();
    final content = _extractStringsFromBinary(bytes);

    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length > 2)
        .toList();

    final List<DocParagraph> paragraphs = [];
    int totalWords = 0;

    for (final line in lines) {
      final words = line.split(RegExp(r'\s+')).length;
      totalWords += words;
      paragraphs.add(DocParagraph(text: line));
    }

    if (paragraphs.isEmpty) {
      paragraphs.add(const DocParagraph(text: 'No readable text could be extracted from this binary file.'));
    }

    final pages = _paginateParagraphs(paragraphs);

    return ParsedWordDoc(
      title: fileName,
      paragraphs: paragraphs,
      pages: pages,
      wordCount: totalWords,
    );
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

        final paragraphs = sp.findAllElements('a:p');
        for (final p in paragraphs) {
          final text = p.findAllElements('a:t').map((e) => e.innerText).join('').trim();
          if (text.isEmpty) continue;

          if (isTitleShape && slideTitle.isEmpty) {
            slideTitle = text;
          } else if (p.getAttribute('lvl') != null || p.findAllElements('a:buChar').isNotEmpty) {
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
        if (rows.isNotEmpty) table = rows;
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
        final text = si.findAllElements('t').map((e) => e.innerText).join('');
        sharedStrings.add(text);
      }
    }

    // 2. Parse Workbook Sheet Names
    final List<String> sheetNames = [];
    final wbFile = archive.findFile('xl/workbook.xml');
    if (wbFile != null) {
      final wbXml = utf8.decode(wbFile.content as List<int>);
      final doc = XmlDocument.parse(wbXml);
      for (final s in doc.findAllElements('sheet')) {
        final name = s.getAttribute('name') ?? 'Sheet ${sheetNames.length + 1}';
        sheetNames.add(name);
      }
    }

    // 3. Parse Worksheet Data
    final sheetFiles = archive.files
        .where((f) => RegExp(r'xl/worksheets/sheet\d+\.xml$').hasMatch(f.name))
        .toList();

    sheetFiles.sort((a, b) {
      final numA = int.tryParse(RegExp(r'\d+').stringMatch(a.name) ?? '0') ?? 0;
      final numB = int.tryParse(RegExp(r'\d+').stringMatch(b.name) ?? '0') ?? 0;
      return numA.compareTo(numB);
    });

    final List<ExcelSheetData> parsedSheets = [];

    for (int i = 0; i < sheetFiles.length; i++) {
      final sheetFile = sheetFiles[i];
      final sheetXml = utf8.decode(sheetFile.content as List<int>);
      final doc = XmlDocument.parse(sheetXml);

      final List<List<String>> rows = [];
      int maxCols = 0;

      for (final rowElem in doc.findAllElements('row')) {
        final List<String> rowCells = [];
        for (final c in rowElem.findAllElements('c')) {
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

        if (rowCells.isNotEmpty) {
          if (rowCells.length > maxCols) maxCols = rowCells.length;
          rows.add(rowCells);
        }
      }

      final sheetTitle = (i < sheetNames.length) ? sheetNames[i] : 'Sheet ${i + 1}';
      parsedSheets.add(
        ExcelSheetData(
          name: sheetTitle,
          rows: rows,
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
    final lines = await file.readAsLines(encoding: utf8);
    final delimiter = isTsv ? '\t' : ',';
    final List<List<String>> rows = [];
    int maxCols = 0;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final cells = _splitCsvLine(line, delimiter);
      if (cells.length > maxCols) maxCols = cells.length;
      rows.add(cells);
    }

    return ParsedExcelDoc(
      title: fileName,
      sheets: [
        ExcelSheetData(
          name: fileName,
          rows: rows,
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
          rows: rows,
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

    for (final page in doc.pages) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
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
                      'Page ${page.pageNumber} of ${doc.pages.length}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                    ),
                  ],
                ),
                pw.Divider(thickness: 0.8, color: PdfColors.grey300),
                pw.SizedBox(height: 12),
                ...page.paragraphs.map((p) {
                  if (p.isTable && p.tableData != null) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8),
                      child: pw.TableHelper.fromTextArray(
                        data: p.tableData!,
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                        cellStyle: const pw.TextStyle(fontSize: 9),
                        cellPadding: const pw.EdgeInsets.all(4),
                      ),
                    );
                  }

                  if (p.isHeading) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text(
                        p.text,
                        style: pw.TextStyle(
                          fontSize: p.headingLevel == 1 ? 18 : 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    );
                  }

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (p.isBullet)
                          pw.Container(
                            margin: const pw.EdgeInsets.only(top: 4, right: 6),
                            width: 4,
                            height: 4,
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.black,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                        pw.Expanded(
                          child: pw.Text(
                            p.text,
                            style: pw.TextStyle(
                              fontSize: 10.5,
                              lineSpacing: 2.5,
                              fontWeight: p.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                              fontStyle: p.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      );
    }

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

    const rowsPerPage = 25;
    final totalPages = (sheet.rows.length / rowsPerPage).ceil();

    for (int p = 0; p < totalPages; p++) {
      final start = p * rowsPerPage;
      final end = (start + rowsPerPage < sheet.rows.length) ? start + rowsPerPage : sheet.rows.length;
      final pageRows = sheet.rows.sublist(start, end);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
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
                      'Page ${p + 1} of $totalPages (${sheet.totalRows} total rows)',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1, color: PdfColors.green700),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  data: pageRows,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  cellPadding: const pw.EdgeInsets.all(3),
                ),
              ],
            );
          },
        ),
      );
    }

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

    while (i < len) {
      if (bytes[i] >= 32 && bytes[i] <= 126) {
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

  static List<String> _splitCsvLine(String line, String delimiter) {
    final List<String> cells = [];
    final StringBuffer sb = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        insideQuotes = !insideQuotes;
      } else if (char == delimiter && !insideQuotes) {
        cells.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    cells.add(sb.toString().trim());
    return cells;
  }
}
