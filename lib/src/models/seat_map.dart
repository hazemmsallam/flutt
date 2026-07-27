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
    required this.tables,
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

  /// Non-bookable layout objects (tables) — display only, never selectable.
  final List<VenueTable> tables;

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
        tables: ((j['layoutObjects'] as List?) ?? const [])
            .map((e) => VenueTable.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

enum TableShape { square, rectangle, circle }

TableShape tableShapeOf(String? s) {
  switch (s) {
    case 'RECTANGLE':
      return TableShape.rectangle;
    case 'CIRCLE':
      return TableShape.circle;
    default:
      return TableShape.square;
  }
}

/// A non-bookable table in the venue layout. Shares the seat coordinate space
/// (top-left [x],[y] with footprint [w] x [d]) and adds the extra 3D dimensions
/// the admin editor stores: [z] elevation off the floor and physical [height].
class VenueTable {
  VenueTable({
    required this.id,
    required this.shape,
    required this.label,
    required this.x,
    required this.y,
    required this.z,
    required this.w,
    required this.d,
    required this.height,
    required this.rotation,
  });

  final int? id;
  final TableShape shape;
  final String? label;
  final double x;
  final double y;
  final double z;
  final double w;
  final double d;
  final double height;
  final double rotation; // degrees

  factory VenueTable.fromJson(Map<String, dynamic> j) => VenueTable(
        id: j['id'] as int?,
        shape: tableShapeOf(j['shape'] as String?),
        label: j['label'] as String?,
        x: _d(j['layoutX'], 0),
        y: _d(j['layoutY'], 0),
        z: _d(j['layoutZ'], 0),
        w: _d(j['layoutWidth'], 90),
        d: _d(j['layoutDepth'], 90),
        height: _d(j['objectHeight'], 40),
        rotation: _d(j['rotationDegrees'], 0),
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
