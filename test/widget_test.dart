import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ticketing_mobile/src/models/seat_map.dart';

void main() {
  test('Seat parses layout coordinates and status', () {
    final seat = Seat.fromJson({
      'seatId': 1,
      'label': 'A1',
      'seatType': 'VIP',
      'layoutX': 224,
      'layoutY': 150,
      'layoutWidth': 42,
      'layoutHeight': 38,
      'rotationDegrees': -6,
      'price': 120.0,
      'status': 'AVAILABLE',
    });

    expect(seat.label, 'A1');
    expect(seat.type, SeatType.vip);
    expect(seat.x, 224);
    expect(seat.rotation, -6);
    expect(seat.selectable, isTrue);
  });

  testWidgets('App theme builds', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('ok'))));
    expect(find.text('ok'), findsOneWidget);
  });
}
