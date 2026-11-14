import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_mobile/src/models/booking.dart';
import 'package:ticketing_mobile/src/models/event_summary.dart';

void main() {
  test('event listing reads image and merchandising fields', () {
    final event = EventSummary.fromJson({
      'id': 7,
      'name': 'Sami Yusuf Live',
      'category': 'Music',
      'imageUrl': 'https://example.test/poster.jpg',
      'tagline': 'An evening of music',
      'featured': true,
      'tags': ['Live', 'Concert'],
      'status': 'PUBLISHED',
      'hallName': 'Arena',
      'hallAddress': 'Amman',
      'seated': true,
    });
    expect(event.imageUrl, endsWith('poster.jpg'));
    expect(event.featured, isTrue);
    expect(event.tags, ['Live', 'Concert']);
  });

  test('mixed booking reads seated and general admission lines', () {
    final booking = Booking.fromJson({
      'id': 12,
      'eventName': 'Concert',
      'status': 'PENDING_PAYMENT',
      'quantity': 3,
      'totalAmount': 80,
      'seats': [
        {'label': 'A1', 'sectionName': 'VIP', 'price': 40, 'currency': 'JOD'}
      ],
      'generalAdmission': [
        {'sectionName': 'Standing', 'quantity': 2, 'totalAmount': 40, 'currency': 'JOD'}
      ],
    });
    expect(booking.isPending, isTrue);
    expect(booking.seats.single.sectionName, 'VIP');
    expect(booking.generalAdmission.single.quantity, 2);
    expect(booking.currency, 'JOD');
  });
}
