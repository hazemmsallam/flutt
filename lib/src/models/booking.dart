/// A hold/booking (BookingResponse) and its seats.
class Booking {
  Booking({
    required this.id,
    required this.eventName,
    this.eventStartAt,
    this.eventImageUrl,
    this.hallName,
    required this.status,
    required this.quantity,
    required this.totalAmount,
    this.serviceFee = 0,
    required this.expiresAt,
    required this.paymentRef,
    required this.seats,
    required this.generalAdmission,
    this.tickets = const [],
  });

  final int id;
  final String eventName;
  final DateTime? eventStartAt;
  final String? eventImageUrl;
  final String? hallName;
  final String status; // PENDING | CONFIRMED | CANCELLED | EXPIRED
  final int quantity;
  final double totalAmount;
  final double serviceFee;
  final DateTime? expiresAt;
  final String? paymentRef;
  final List<BookingSeat> seats;
  final List<BookingGa> generalAdmission;
  final List<AdmissionTicket> tickets;

  bool get isPending => status == 'PENDING_PAYMENT' || status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool isUpcoming(DateTime now) =>
      isConfirmed && (eventStartAt?.isAfter(now) ?? false);
  String get currency => seats.isNotEmpty
      ? seats.first.currency
      : generalAdmission.isNotEmpty
          ? generalAdmission.first.currency
          : 'JOD';

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as int,
        eventName: (j['eventName'] ?? '') as String,
        eventStartAt: _date(j['eventStartAt']),
        eventImageUrl: j['eventImageUrl'] as String?,
        hallName: j['hallName'] as String?,
        status: (j['status'] ?? '') as String,
        quantity: (j['quantity'] ?? 0) as int,
        totalAmount: _d(j['totalAmount'], 0),
        serviceFee: _d(j['serviceFee'], 0),
        expiresAt: _date(j['expiresAt']),
        paymentRef: j['paymentRef'] as String?,
        seats: ((j['seats'] as List?) ?? const [])
            .map((e) => BookingSeat.fromJson(e as Map<String, dynamic>))
            .toList(),
        tickets: ((j['tickets'] as List?) ?? const [])
            .map((item) =>
                AdmissionTicket.fromJson(item as Map<String, dynamic>))
            .toList(),
        generalAdmission: ((j['generalAdmission'] as List?) ?? const [])
            .map((e) => BookingGa.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AdmissionTicket {
  const AdmissionTicket(
      {required this.number, required this.sectionName, this.seatLabel});

  final String number;
  final String sectionName;
  final String? seatLabel;

  factory AdmissionTicket.fromJson(Map<String, dynamic> json) =>
      AdmissionTicket(
        number: json['ticketNumber'] as String,
        sectionName: json['sectionName'] as String? ?? '',
        seatLabel: json['seatLabel'] as String?,
      );
}

class BookingSeat {
  BookingSeat(
      {required this.label,
      this.sectionId,
      required this.sectionName,
      required this.price,
      required this.currency});

  final String label;
  final int? sectionId;
  final String sectionName;
  final double price;
  final String currency;

  factory BookingSeat.fromJson(Map<String, dynamic> j) => BookingSeat(
        label: (j['label'] ?? '') as String,
        sectionId: j['sectionId'] as int?,
        sectionName: (j['sectionName'] ?? '') as String,
        price: _d(j['price'], 0),
        currency: (j['currency'] ?? 'JOD') as String,
      );
}

class BookingGa {
  BookingGa(
      {this.sectionId,
      required this.sectionName,
      required this.quantity,
      required this.totalAmount,
      required this.currency});
  final int? sectionId;
  final String sectionName;
  final int quantity;
  final double totalAmount;
  final String currency;

  factory BookingGa.fromJson(Map<String, dynamic> j) => BookingGa(
        sectionId: j['sectionId'] as int?,
        sectionName: (j['sectionName'] ?? '') as String,
        quantity: (j['quantity'] ?? 0) as int,
        totalAmount: _d(j['totalAmount'], 0),
        currency: (j['currency'] ?? 'JOD') as String,
      );
}

/// Result of POST /api/bookings/{id}/payment.
class PaymentResult {
  PaymentResult(
      {required this.success, required this.status, required this.message});

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

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
