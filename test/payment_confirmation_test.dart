import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_mobile/src/models/booking.dart';
import 'package:ticketing_mobile/src/screens/payment_confirmation_screen.dart';

void main() {
  testWidgets('confirmation shows issued seat and general admission tickets',
      (tester) async {
    final booking = Booking.fromJson({
      'id': 42,
      'eventName': 'Live Concert',
      'status': 'CONFIRMED',
      'quantity': 2,
      'tickets': [
        {
          'ticketNumber': 'TK-42-1',
          'seatLabel': 'A13',
          'sectionName': 'Prime 1'
        },
        {'ticketNumber': 'TK-42-2', 'sectionName': 'Standing'},
      ],
    });
    await tester.pumpWidget(MaterialApp(
      home: PaymentConfirmationScreen(booking: booking),
    ));
    expect(find.text('A13 - #TK-42-1'), findsOneWidget);
    expect(find.text('Prime 1'), findsOneWidget);
    expect(find.text('#TK-42-2'), findsOneWidget);
    expect(find.text('Standing'), findsOneWidget);
    await tester.tap(find.text('A13 - #TK-42-1'));
    await tester.pumpAndSettle();
    expect(find.text('Live Concert'), findsOneWidget);
    expect(find.text('Prime 1 - A13'), findsNWidgets(2));
    expect(find.text('#TK-42-1'), findsOneWidget);
    expect(tester.widget<BarcodeWidget>(find.byType(BarcodeWidget)).data,
        'TK-42-1'.codeUnits);
    await tester.scrollUntilVisible(find.text('Share'), 180);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });
}
