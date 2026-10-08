import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localyt_music/screens/song_player_screen.dart';
import 'package:localyt_music/theme/app_palette.dart';
import 'package:localyt_music/theme/app_theme.dart';

void main() {
  Future<void> openPlayer(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppPalette.modernDark),
        home: Builder(
          builder: (context) => TextButton(
            // 曲がなければ再生はせず、画面だけ開く
            onPressed: () => SongPlayerScreen.open(context, const [], 0),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SongPlayerScreen), findsOneWidget);
  }

  double top(WidgetTester tester) =>
      tester.getTopLeft(find.byType(SongPlayerScreen)).dy;

  testWidgets('引いている間は指について下がる', (tester) async {
    await openPlayer(tester);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(SongPlayerScreen)),
    );
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    final double afterFirst = top(tester);
    expect(afterFirst, greaterThan(100));
    await gesture.moveBy(const Offset(0, 50));
    await tester.pump();
    expect(top(tester), moreOrLessEquals(afterFirst + 50, epsilon: 0.5));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('少しだけゆっくり引いて離すと元に戻る', (tester) async {
    await openPlayer(tester);
    await tester.timedDrag(
      find.byType(SongPlayerScreen),
      const Offset(0, 60),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SongPlayerScreen), findsOneWidget);
    expect(top(tester), 0);
  });

  testWidgets('勢いよく下へ払うと閉じる', (tester) async {
    await openPlayer(tester);
    await tester.fling(
      find.byType(SongPlayerScreen),
      const Offset(0, 200),
      2000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(SongPlayerScreen), findsNothing);
  });

  testWidgets('上へ引くと再生キューが開く', (tester) async {
    await openPlayer(tester);
    await tester.drag(find.byType(SongPlayerScreen), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.text('次に再生'), findsOneWidget);
    expect(top(tester), 0);
  });

  testWidgets('閉じるときは離した勢いのまま減速せずに下がる', (tester) async {
    await openPlayer(tester);
    await tester.fling(
      find.byType(SongPlayerScreen),
      const Offset(0, 200),
      2000,
    );
    final List<double> positions = [];
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byType(SongPlayerScreen).evaluate().isEmpty) break;
      positions.add(top(tester));
    }
    expect(positions.length, greaterThanOrEqualTo(4));
    final List<double> steps = [
      for (int i = 1; i < positions.length; i++)
        positions[i] - positions[i - 1],
    ];
    for (int i = 1; i < steps.length; i++) {
      expect(steps[i], greaterThanOrEqualTo(steps[i - 1] - 0.5));
    }
    await tester.pumpAndSettle();
  });
}
