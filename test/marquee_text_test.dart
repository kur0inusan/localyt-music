import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localyt_music/widgets/marquee_text.dart';

void main() {
  Widget host(String text) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: 200,
        child: MarqueeText(text, style: const TextStyle(fontSize: 20)),
      ),
    ),
  );

  double heightOf(WidgetTester tester) =>
      tester.getSize(find.byType(MarqueeText)).height;

  testWidgets('収まる文字は流さず1行で出す', (tester) async {
    await tester.pumpWidget(host('短い曲名'));
    expect(find.byType(Transform), findsNothing);
    expect(find.text('短い曲名'), findsOneWidget);
  });

  testWidgets('長い文字も高さは1行のまま、止まってから流れる', (tester) async {
    await tester.pumpWidget(host('短い曲名'));
    final double oneLine = heightOf(tester);

    const String long = 'とても長い曲名のテストとても長い曲名のテストとても長い曲名のテスト';
    await tester.pumpWidget(host(long));
    await tester.pump();
    expect(heightOf(tester), oneLine);

    double dx() => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(MarqueeText),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .getTranslation()
        .x;

    await tester.pump(const Duration(seconds: 1));
    expect(dx(), 0);
    await tester.pump(const Duration(seconds: 2));
    expect(dx(), lessThan(0));
  });
}
