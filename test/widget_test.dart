import 'package:flutter_test/flutter_test.dart';
import 'package:file_explorer/main.dart';

void main() {
  testWidgets('FileExplorerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FileExplorerApp());
    expect(find.byType(FileExplorerApp), findsOneWidget);
  });
}
