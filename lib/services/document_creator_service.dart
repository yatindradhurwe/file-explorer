import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DocumentCreatorService {
  /// Resolves the default save folder in Documents/
  static Future<Directory> _getDocumentsDir() async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory(p.join(ext.parent.parent.parent.parent.path, 'Documents'));
        await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}

    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'Documents'));
    await dir.create(recursive: true);
    return dir;
  }

  static String _sanitizeFileName(String name) {
    return name.trim().replaceAll(RegExp(r'[^\w\s\-_.]'), '_');
  }

  // =============================================================
  // 1. CREATE NEW PDF DOCUMENT (.pdf)
  // =============================================================
  static Future<File> createNewPdf({
    required String title,
    String initialContent = '',
  }) async {
    final pdf = pw.Document(
      title: title,
      author: 'File Explore by yjtechnosoft',
    );

    final cleanTitle = _sanitizeFileName(title.isEmpty ? 'Untitled Document' : title);
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    cleanTitle,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.Text(dateStr, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 11)),
                ],
              ),
              pw.Divider(thickness: 1.2, color: PdfColors.blue800),
              pw.SizedBox(height: 16),
              pw.Text(
                initialContent.isNotEmpty
                    ? initialContent
                    : 'This document was created with File Explore.\n\nYou can share, export, or print this PDF document anytime.',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 3),
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('Created by: File Explore • Instant Storage Suite', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final dir = await _getDocumentsDir();
    final outPath = p.join(dir.path, '$cleanTitle.pdf');
    final file = File(outPath);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // =============================================================
  // 2. CREATE NEW WORD DOCUMENT (.docx)
  // =============================================================
  static Future<File> createNewWordDoc({
    required String title,
    String initialContent = '',
  }) async {
    final cleanTitle = _sanitizeFileName(title.isEmpty ? 'New Document' : title);
    final text = initialContent.isNotEmpty
        ? initialContent
        : 'Welcome to your new document! Start editing or writing notes here.';

    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    // 3. word/document.xml
    final docXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:pStyle w:val="Title"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="44"/></w:rPr><w:t>$cleanTitle</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>$text</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>Section 1: Overview</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>Created with File Explore on Android. View in-app or export as PDF.</w:t></w:r>
    </w:p>
  </w:body>
</w:document>''';
    archive.addFile(ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml)));

    final zipData = ZipEncoder().encode(archive);
    final dir = await _getDocumentsDir();
    final outPath = p.join(dir.path, '$cleanTitle.docx');
    final file = File(outPath);
    await file.writeAsBytes(zipData);
    return file;
  }

  // =============================================================
  // 3. CREATE NEW POWERPOINT PRESENTATION (.pptx)
  // =============================================================
  static Future<File> createNewPowerPoint({
    required String title,
    String subtitle = 'Created with File Explore',
  }) async {
    final cleanTitle = _sanitizeFileName(title.isEmpty ? 'New Presentation' : title);
    final cleanSubtitle = subtitle.isEmpty ? 'File Explore Presentation Engine' : subtitle;

    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/slides/slide2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    // 3. ppt/presentation.xml
    const presXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId1"/>
    <p:sldId id="257" r:id="rId2"/>
  </p:sldIdLst>
</p:presentation>''';
    archive.addFile(ArchiveFile('ppt/presentation.xml', presXml.length, utf8.encode(presXml)));

    // 4. Slide 1 (Title slide)
    final slide1Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
        <p:txBody>
          <a:p><a:r><a:t>$cleanTitle</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:txBody>
          <a:p><a:r><a:t>$cleanSubtitle</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
    archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slide1Xml.length, utf8.encode(slide1Xml)));

    // 5. Slide 2 (Key points slide)
    const slide2Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
        <p:txBody>
          <a:p><a:r><a:t>Agenda &amp; Highlights</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:txBody>
          <a:p lvl="0"><a:r><a:t>Introduction and Objectives</a:t></a:r></a:p>
          <a:p lvl="0"><a:r><a:t>Key Project Milestones</a:t></a:r></a:p>
          <a:p lvl="0"><a:r><a:t>Next Steps &amp; Action Items</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
    archive.addFile(ArchiveFile('ppt/slides/slide2.xml', slide2Xml.length, utf8.encode(slide2Xml)));

    final zipData = ZipEncoder().encode(archive);
    final dir = await _getDocumentsDir();
    final outPath = p.join(dir.path, '$cleanTitle.pptx');
    final file = File(outPath);
    await file.writeAsBytes(zipData);
    return file;
  }

  // =============================================================
  // 4. CREATE NEW EXCEL SPREADSHEET (.xlsx)
  // =============================================================
  static Future<File> createNewExcel({
    required String title,
    List<String> headers = const ['ID', 'Item Description', 'Category', 'Amount (\$)'],
  }) async {
    final cleanTitle = _sanitizeFileName(title.isEmpty ? 'New Spreadsheet' : title);

    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    // 3. xl/workbook.xml
    const wbXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
    archive.addFile(ArchiveFile('xl/workbook.xml', wbXml.length, utf8.encode(wbXml)));

    // 4. xl/sharedStrings.xml
    final strings = [
      ...headers,
      '1', 'Office Supplies', 'Operations', '150.00',
      '2', 'Cloud Hosting', 'Technology', '420.50',
      '3', 'Marketing & Ads', 'Growth', '280.00',
    ];

    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${strings.length}" uniqueCount="${strings.length}">');
    for (final s in strings) {
      sb.writeln('  <si><t>$s</t></si>');
    }
    sb.writeln('</sst>');
    final sstXml = sb.toString();
    archive.addFile(ArchiveFile('xl/sharedStrings.xml', sstXml.length, utf8.encode(sstXml)));

    // 5. xl/worksheets/sheet1.xml
    final sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="s"><v>1</v></c>
      <c r="C1" t="s"><v>2</v></c>
      <c r="D1" t="s"><v>3</v></c>
    </row>
    <row r="2">
      <c r="A2" t="s"><v>4</v></c>
      <c r="B2" t="s"><v>5</v></c>
      <c r="C2" t="s"><v>6</v></c>
      <c r="D2" t="s"><v>7</v></c>
    </row>
    <row r="3">
      <c r="A3" t="s"><v>8</v></c>
      <c r="B3" t="s"><v>9</v></c>
      <c r="C3" t="s"><v>10</v></c>
      <c r="D3" t="s"><v>11</v></c>
    </row>
    <row r="4">
      <c r="A4" t="s"><v>12</v></c>
      <c r="B4" t="s"><v>13</v></c>
      <c r="C4" t="s"><v>14</v></c>
      <c r="D4" t="s"><v>15</v></c>
    </row>
  </sheetData>
</worksheet>''';
    archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));

    final zipData = ZipEncoder().encode(archive);
    final dir = await _getDocumentsDir();
    final outPath = p.join(dir.path, '$cleanTitle.xlsx');
    final file = File(outPath);
    await file.writeAsBytes(zipData);
    return file;
  }
}
