import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focr/features/review/zoomable_image.dart';
import 'package:image/image.dart' as img;

final _png = Uint8List.fromList(img.encodePng(img.Image(width: 300, height: 600)));

double _scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value
    .getMaxScaleOnAxis();

Future<void> _pinch(WidgetTester tester, {required double from, required double to}) async {
  final center = tester.getCenter(find.byType(InteractiveViewer));
  final a = await tester.startGesture(center - Offset(0, from), pointer: 1);
  final b = await tester.startGesture(center + Offset(0, from), pointer: 2);
  // Move in small steps, vertically: the direction a scroll view would have stolen.
  for (var i = 1; i <= 10; i++) {
    final d = from + (to - from) * i / 10;
    await a.moveTo(center - Offset(0, d));
    await b.moveTo(center + Offset(0, d));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await a.up();
  await b.up();
  await tester.pumpAndSettle();
}

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          const Expanded(child: SizedBox.shrink()),
          SizedBox(height: 500, child: ZoomableImage(bytes: _png)),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('vertical pinch zooms in, then out again, repeatedly', (tester) async {
    await pump(tester);
    expect(_scale(tester), closeTo(1, 0.01));

    for (var round = 0; round < 3; round++) {
      await _pinch(tester, from: 40, to: 120);
      expect(_scale(tester), greaterThan(1.8), reason: 'zoom in, round $round');
      expect(find.byTooltip('Reset zoom'), findsOneWidget);

      await _pinch(tester, from: 120, to: 40);
      expect(_scale(tester), lessThan(1.2), reason: 'zoom out, round $round');
    }
  });

  testWidgets('double-tap zooms in, double-tap again resets', (tester) async {
    await pump(tester);
    final center = tester.getCenter(find.byType(InteractiveViewer));

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(3, 0.01));

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(1, 0.01));
  });

  testWidgets('reset button restores the original view', (tester) async {
    await pump(tester);
    await _pinch(tester, from: 40, to: 140);
    expect(_scale(tester), greaterThan(1.8));
    await tester.tap(find.byTooltip('Reset zoom'));
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(1, 0.01));
    expect(find.byTooltip('Reset zoom'), findsNothing);
  });

  testWidgets('full-screen button opens a zoomable full-screen view', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pumpAndSettle();
    expect(find.text('Image'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
