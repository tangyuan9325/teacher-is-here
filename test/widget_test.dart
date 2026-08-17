import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_is_here/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const TeacherIsHereApp());
    expect(find.text('老师来了'), findsOneWidget);
  });
}
