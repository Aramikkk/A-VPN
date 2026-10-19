import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/widget/network_indicator.dart';

void main() {
  for (final mobile in [true, false]) {
    testWidgets('network icon and ${mobile ? 'LTE' : 'Wi-Fi'} label are centred', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 92,
              height: 92,
              child: Center(
                child: HomeNetworkIndicator(mobile: mobile, iconSize: 32, color: Colors.lime),
              ),
            ),
          ),
        ),
      );
      final label = find.text(mobile ? 'LTE' : 'Wi-Fi');
      expect(label, findsOneWidget);
      final indicator = find.byType(HomeNetworkIndicator);
      expect(tester.getCenter(label).dx, closeTo(tester.getCenter(indicator).dx, .01));
      final icon = find.byKey(const Key('network-symbol'));
      expect(tester.getCenter(icon).dx, closeTo(tester.getCenter(indicator).dx, .01));
      expect(tester.getBottomLeft(icon).dy, lessThan(tester.getTopLeft(label).dy));
    });
  }
}
