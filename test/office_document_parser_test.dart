import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_explorer/services/office_document_parser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

late Directory tempDir;

String writeZip(String name, Map<String, String> entries) {
  final archive = Archive();
  entries.forEach((path, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  });
  final file = File(p.join(tempDir.path, name));
  file.writeAsBytesSync(ZipEncoder().encode(archive));
  return file.path;
}

String writeText(String name, String content) {
  final file = File(p.join(tempDir.path, name));
  file.writeAsStringSync(content);
  return file.path;
}

int pdfPageCount(File pdf) {
  final text = latin1.decode(pdf.readAsBytesSync());
  return RegExp(r'/Type\s*/Page(?![s\w])').allMatches(text).length;
}

const _w ='xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('office_parser_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
  });

  tearDownAll(() => tempDir.deleteSync(recursive: true));

  group('Word', () {
    test('parses .docx headings, bullets, formatting and tables', () async {
      final path = writeZip('sample.docx', {
        'word/document.xml': '''<?xml version="1.0" encoding="UTF-8"?>
<w:document $_w><w:body>
  <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Quarterly Report</w:t></w:r></w:p>
  <w:p><w:r><w:rPr><w:b w:val="0"/></w:rPr><w:t>Plain</w:t></w:r><w:r><w:tab/><w:t>text</w:t></w:r></w:p>
  <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Bold line</w:t></w:r></w:p>
  <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/></w:numPr></w:pPr><w:r><w:t>First bullet</w:t></w:r></w:p>
  <w:tbl>
    <w:tr><w:tc><w:p><w:r><w:t>Name</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Value</w:t></w:r></w:p></w:tc></w:tr>
    <w:tr><w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr>
  </w:tbl>
</w:body></w:document>''',
      });

      final doc = await OfficeDocumentParser.parseWord(path);
      expect(doc.isParsedSuccessfully, isTrue);
      final paras = doc.paragraphs;
      expect(paras[0].text, 'Quarterly Report');
      expect(paras[0].isHeading, isTrue);
      expect(paras[1].text, 'Plain\ttext');
      expect(paras[1].isBold, isFalse, reason: 'w:b w:val="0" means not bold');
      expect(paras[2].isBold, isTrue);
      expect(paras[3].isBullet, isTrue);
      expect(paras[4].tableData, [
        ['Name', 'Value'],
        ['A', ''],
      ], reason: 'ragged rows are padded so the Flutter Table does not assert');

      final pdf = await OfficeDocumentParser.convertWordDocToPdf(doc);
      expect(utf8.decode(pdf.readAsBytesSync().sublist(0, 5), allowMalformed: true), '%PDF-');
    });

    test('parses .odt content', () async {
      final path = writeZip('sample.odt', {
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'content.xml': '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">
<office:body><office:text>
  <text:h text:outline-level="1">Open Title</text:h>
  <text:p>Hello <text:span>world</text:span></text:p>
  <text:list><text:list-item><text:p>Item one</text:p></text:list-item></text:list>
</office:text></office:body></office:document-content>''',
      });

      final doc = await OfficeDocumentParser.parseWord(path);
      expect(doc.paragraphs.map((p) => p.text), ['Open Title', 'Hello world', 'Item one']);
      expect(doc.paragraphs[0].isHeading, isTrue);
      expect(doc.paragraphs[2].isBullet, isTrue);
    });

    test('parses .rtf without control words', () async {
      final path = writeText(
        'sample.rtf',
        r'{\rtf1\ansi\deff0{\fonttbl{\f0 Times New Roman;}}\f0\fs24 Hello RTF world.\par Second \b bold\b0  line.\par}',
      );

      final doc = await OfficeDocumentParser.parseWord(path);
      expect(doc.paragraphs.map((p) => p.text), ['Hello RTF world.', 'Second bold line.']);
    });

    test('parses .txt files', () async {
      final path = writeText('notes.txt', 'Line one\n\nLine two\n');
      final doc = await OfficeDocumentParser.parseWord(path);
      expect(doc.isParsedSuccessfully, isTrue);
      expect(doc.paragraphs.map((p) => p.text), ['Line one', 'Line two']);
    });

    test('long document converts to PDF without overflowing a page', () async {
      final body = List.generate(
        40,
        (i) => '<w:p><w:r><w:t>${List.filled(60, 'word$i').join(' ')}</w:t></w:r></w:p>',
      ).join();
      final path = writeZip('long.docx', {
        'word/document.xml': '<w:document $_w><w:body>$body</w:body></w:document>',
      });
      final doc = await OfficeDocumentParser.parseWord(path);
      final pdf = await OfficeDocumentParser.convertWordDocToPdf(doc);
      expect(pdf.lengthSync(), greaterThan(0));
    });

    test('a single huge paragraph and table flow onto several PDF pages', () async {
      final rows = List.generate(
        150,
        (i) => '<w:tr><w:tc><w:p><w:r><w:t>row $i</w:t></w:r></w:p></w:tc></w:tr>',
      ).join();
      final path = writeZip('huge.docx', {
        'word/document.xml': '<w:document $_w><w:body>'
            '<w:p><w:r><w:t>${List.filled(3000, 'lorem').join(' ')}</w:t></w:r></w:p>'
            '<w:tbl>$rows</w:tbl></w:body></w:document>',
      });
      final doc = await OfficeDocumentParser.parseWord(path);
      final pdf = await OfficeDocumentParser.convertWordDocToPdf(doc);
      expect(pdfPageCount(pdf), greaterThan(4), reason: 'content must not be clipped to one page');
    });

    test('extracts UTF-16 text from legacy binary .doc files', () async {
      final bytes = <int>[0xD0, 0xCF, 0x11, 0xE0, 0, 0, 1, 2];
      for (final c in 'Legacy Word text'.codeUnits) {
        bytes.addAll([c, 0]);
      }
      bytes.addAll([13, 0, 0, 0, 0xFF]);
      final file = File(p.join(tempDir.path, 'old.doc'))..writeAsBytesSync(bytes);
      final doc = await OfficeDocumentParser.parseWord(file.path);
      expect(doc.paragraphs.map((p) => p.text), contains('Legacy Word text'));
    });
  });

  group('PowerPoint', () {
    test('parses .pptx slides in numeric order and converts to PDF', () async {
      String slide(String title, String body) => '''<?xml version="1.0" encoding="UTF-8"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
<p:cSld><p:spTree>
  <p:sp><p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr><p:txBody><a:p><a:r><a:t>$title</a:t></a:r></a:p></p:txBody></p:sp>
  <p:sp><p:txBody><a:p><a:pPr lvl="1"/><a:r><a:t>$body</a:t></a:r></a:p></p:txBody></p:sp>
</p:spTree></p:cSld></p:sld>''';

      final path = writeZip('deck.pptx', {
        'ppt/slides/slide10.xml': slide('Ten', 'b10'),
        'ppt/slides/slide2.xml': slide('Two', 'b2'),
        'ppt/slides/slide1.xml': slide('One', 'b1'),
      });

      final ppt = await OfficeDocumentParser.parsePowerPoint(path);
      expect(ppt.slides.map((s) => s.title), ['One', 'Two', 'Ten']);
      expect(ppt.slides.first.bullets, ['b1']);

      final pdf = await OfficeDocumentParser.convertPptToPdf(ppt);
      expect(pdf.lengthSync(), greaterThan(0));
    });
  });

  group('Spreadsheets', () {
    test('keeps sparse .xlsx cells in their columns', () async {
      final path = writeZip('book.xlsx', {
        'xl/workbook.xml': '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets><sheet name="Data" sheetId="1" r:id="rId7"/></sheets></workbook>',
        'xl/_rels/workbook.xml.rels':
            '<Relationships><Relationship Id="rId7" Target="worksheets/sheet1.xml"/></Relationships>',
        'xl/sharedStrings.xml': '<sst><si><t>Name</t></si><si><t>Score</t></si><si><t>Bob</t></si></sst>',
        'xl/worksheets/sheet1.xml': '''<worksheet><sheetData>
  <row r="1"><c r="A1" t="s"><v>0</v></c><c r="C1" t="s"><v>1</v></c></row>
  <row r="2"><c r="A2" t="s"><v>2</v></c><c r="C2"><v>42</v></c></row>
</sheetData></worksheet>''',
      });

      final xls = await OfficeDocumentParser.parseExcel(path);
      final sheet = xls.sheets.single;
      expect(sheet.name, 'Data');
      expect(sheet.rows, [
        ['Name', '', 'Score'],
        ['Bob', '', '42'],
      ]);
      expect(sheet.totalColumns, 3);

      final pdf = await OfficeDocumentParser.convertSpreadsheetToPdf(sheet, 'book.xlsx');
      expect(pdf.lengthSync(), greaterThan(0));
    });

    test('parses quoted CSV and converts ragged rows to PDF', () async {
      final path = writeText('data.csv', '﻿a,"b, c",d\r\n1,"say ""hi"""\n2,"multi\nline"\n');
      final xls = await OfficeDocumentParser.parseExcel(path);
      final sheet = xls.sheets.single;
      expect(sheet.rows, [
        ['a', 'b, c', 'd'],
        ['1', 'say "hi"', ''],
        ['2', 'multi\nline', ''],
      ]);

      final pdf = await OfficeDocumentParser.convertSpreadsheetToPdf(sheet, 'data.csv');
      expect(pdf.lengthSync(), greaterThan(0));
    });

    test('large sheet spans several PDF pages', () async {
      final csv = ['id,name', for (var i = 0; i < 300; i++) '$i,item $i'].join('\n');
      final xls = await OfficeDocumentParser.parseExcel(writeText('big.csv', csv));
      final pdf = await OfficeDocumentParser.convertSpreadsheetToPdf(xls.sheets.single, 'big.csv');
      expect(pdfPageCount(pdf), greaterThan(3));
    });

    test('empty CSV still produces a valid PDF', () async {
      final path = writeText('empty.csv', '');
      final xls = await OfficeDocumentParser.parseExcel(path);
      final pdf = await OfficeDocumentParser.convertSpreadsheetToPdf(xls.sheets.single, 'empty.csv');
      expect(pdfPageCount(pdf), 1, reason: 'a zero-page PDF fails to open in the viewer');
    });
  });
}
