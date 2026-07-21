/// Live seat map for a seated event — the payload from GET /api/events/{id}/seats.
///
/// Coordinates are in the same logical-pixel space the admin editor uses: a
/// [layoutWidth] x [layoutHeight] canvas, each seat placed by its top-left
/// ([Seat.x], [Seat.y]), sized [Seat.w] x [Seat.h], rotated [Seat.rotation]
/// degrees about its own centre. The client only scales and replays these.
class SeatMap {
  SeatMap({
    required this.eventId,
    required this.hallName,
    required this.layoutWidth,
    required this.layoutHeight,
    required this.totalSeats,
    required this.availableCount,
    required this.reservedCount,
    required this.bookedCount,
    required this.seats,
  });

  final int eventId;
  final String hallName;
  final double layoutWidth;
  final double layoutHeight;
  final int totalSeats;
  final int availableCount;
  final int reservedCount;
  final int bookedCount;
  final List<Seat> seats;

  factory SeatMap.fromJson(Map<String, dynamic> j) => SeatMap(
        eventId: j['eventId'] as int,
        hallName: (j['hallName'] ?? '') as String,
        layoutWidth: _d(j['layoutWidth'], 900),
        layoutHeight: _d(j['layoutHeight'], 600),
        totalSeats: (j['totalSeats'] ?? 0) as int,
        availableCount: (j['availableCount'] ?? 0) as int,
        reservedCount: (j['reservedCount'] ?? 0) as int,
        bookedCount: (j['bookedCount'] ?? 0) as int,
        seats: ((j['seats'] as List?) ?? const [])
            .map((e) => Seat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

enum SeatStatus { available, reserved, booked }

enum SeatType { vip, premium, regular }

SeatStatus _status(String? s) {
  switch (s) {
    case 'RESERVED':
      return SeatStatus.reserved;
    case 'BOOKED':
      return SeatStatus.booked;
    default:
      return SeatStatus.available;
  }
}

SeatType seatTypeOf(String? s) {
  switch (s) {
    case 'VIP':
      return SeatType.vip;
    case 'PREMIUM':
      return SeatType.premium;
    default:
      return SeatType.regular;
  }
}

class Seat {
  Seat({
    required this.id,
    required this.label,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.rotation,
    required this.sectionName,
    required this.price,
    required this.status,
  });

  final int id;
  final String label;
  final SeatType type;
  final double x;
  final double y;
  final double w;
  final double h;
  final double rotation; // degrees
  final String? sectionName;
  final double price;
  final SeatStatus status;

  bool get selectable => status == SeatStatus.available;

  factory Seat.fromJson(Map<String, dynamic> j) => Seat(
        id: j['seatId'] as int,
        label: (j['label'] ?? '') as String,
        type: seatTypeOf(j['seatType'] as String?),
        x: _d(j['layoutX'], 0),
        y: _d(j['layoutY'], 0),
        w: _d(j['layoutWidth'], 42),
        h: _d(j['layoutHeight'], 38),
        rotation: _d(j['rotationDegrees'], 0),
        sectionName: j['sectionName'] as String?,
        price: _d(j['price'], 0),
        status: _status(j['status'] as String?),
      );
}

double _d(dynamic v, double fallback) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}
