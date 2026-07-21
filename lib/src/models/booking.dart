/// A hold/booking (BookingResponse) and its seats.
class Booking {
  Booking({
    required this.id,
    required this.eventName,
    required this.status,
    required this.quantity,
    required this.totalAmount,
    required this.expiresAt,
    required this.paymentRef,
    required this.seats,
  });

  final int id;
  final String eventName;
  final String status; // PENDING | CONFIRMED | CANCELLED | EXPIRED
  final int quantity;
  final double totalAmount;
  final DateTime? expiresAt;
  final String? paymentRef;
  final List<BookingSeat> seats;

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as int,
        eventName: (j['eventName'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        quantity: (j['quantity'] ?? 0) as int,
        totalAmount: _d(j['totalAmount'], 0),
        expiresAt: _date(j['expiresAt']),
        paymentRef: j['paymentRef'] as String?,
        seats: ((j['seats'] as List?) ?? const [])
            .map((e) => BookingSeat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class BookingSeat {
  BookingSeat({required this.label, required this.seatType, required this.price});

  final String label;
  final String seatType;
  final double price;

  factory BookingSeat.fromJson(Map<String, dynamic> j) => BookingSeat(
        label: (j['label'] ?? '') as String,
        seatType: (j['seatType'] ?? 'REGULAR') as String,
        price: _d(j['price'], 0),
      );
}

/// Result of POST /api/bookings/{id}/payment.
class PaymentResult {
  PaymentResult({required this.success, required this.status, required this.message});

  final bool success;
  final String status;
  final String? message;

  factory PaymentResult.fromJson(Map<String, dynamic> j) => PaymentResult(
        success: (j['success'] ?? false) as bool,
        status: (j['status'] ?? '') as String,
        message: j['message'] as String?,
      );
}

double _d(dynamic v, double fallback) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
