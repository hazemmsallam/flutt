import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_mobile/src/models/booking.dart';
import 'package:ticketing_mobile/src/screens/booking_screen.dart';
import 'package:ticketing_mobile/src/theme/app_theme.dart';
import 'package:ticketing_mobile/src/widgets/event_countdown_banner.dart';

void main() {
  testWidgets('mixed booking shows issued tickets and grouped payment details',
      (tester) async {
    final booking = Booking.fromJson({
      'id': 42,
      'eventName': 'Live Concert',
      'eventStartAt':
          DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      'hallName': 'Grand Theatre',
      'status': 'CONFIRMED',
      'quantity': 3,
      'totalAmount': '233.00',
      'serviceFee': '3.00',
      'seats': [
        {'label': 'A13', 'sectionId': 1, 'sectionName': 'Prime', 'price': 100},
        {'label': 'A14', 'sectionId': 1, 'sectionName': 'Prime', 'price': 100},
      ],
      'generalAdmission': [
        {
          'sectionId': 2,
          'sectionName': 'Standing',
          'quantity': 1,
          'totalAmount': 30
        },
      ],
      'tickets': [
        {'ticketNumber': 'TK-42-1', 'seatLabel': 'A13', 'sectionName': 'Prime'},
        {'ticketNumber': 'TK-42-2', 'seatLabel': 'A14', 'sectionName': 'Prime'},
        {'ticketNumber': 'TK-42-3', 'sectionName': 'Standing'},
      ],
    });

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: BookingScreen(bookingId: booking.id, initial: booking),
    ));
    expect(find.text('Live Concert'), findsOneWidget);
    expect(find.textContaining('Grand Theatre', findRichText: true),
        findsOneWidget);
    expect(find.byType(EventCountdownBanner), findsOneWidget);
    expect(find.text('A13 - #TK-42-1'), findsOneWidget);
    expect(find.text('A14 - #TK-42-2'), findsOneWidget);
    expect(find.text('#TK-42-3'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('233.00 JOD'), 250);
    expect(find.text('Prime  ·  ×2'), findsOneWidget);
    expect(find.text('200.00 JOD'), findsOneWidget);
    expect(find.text('Standing  ·  ×1'), findsOneWidget);
    expect(find.text('30.00 JOD'), findsOneWidget);
    expect(find.text('3.00 JOD'), findsOneWidget);
    expect(find.text('233.00 JOD'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('#TK-42-3'), -220);
    await tester.tap(find.text('#TK-42-3'));
    await tester.pumpAndSettle();
    expect(find.text('Ticket ID'), findsOneWidget);
    expect(find.text('Grand Theatre'), findsOneWidget);
    expect(find.text('Section'), findsOneWidget);
  });
}
