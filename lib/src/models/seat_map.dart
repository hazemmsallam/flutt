import 'dart:ui' show Offset;

/// Live seat map for an event — the payload from GET /api/events/{id}/seats.
///
/// Coordinates are in the same logical-pixel space the admin editor uses: a
/// [layoutWidth] x [layoutHeight] canvas, each seat placed by its top-left
/// ([Seat.x], [Seat.y]), sized [Seat.w] x [Seat.h], rotated [Seat.rotation]
/// degrees about its own centre. Sections carry a boundary polygon in the same
/// space. The client only scales and replays these.
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
    required this.sections,
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

  /// First-class sections with dynamic name/price/mode/geometry and live availability.
  final List<VenueSection> sections;

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
        sections: ((j['sections'] as List?) ?? const [])
            .map((e) => VenueSection.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  VenueSection? sectionById(int? id) {
    if (id == null) return null;
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// A section's booking behaviour — configuration-driven, never inferred from the name.
enum SectionMode { seated, generalAdmission }

SectionMode sectionModeOf(String? s) => s == 'GENERAL_ADMISSION'
    ? SectionMode.generalAdmission
    : SectionMode.seated;

/// A first-class section: dynamic name/price/currency, booking mode, boundary polygon
/// (layout-pixel points) and live availability. The app renders whatever it receives and
/// never hardcodes names or prices.
class VenueSection {
  VenueSection({
    required this.id,
    required this.name,
    required this.mode,
    required this.price,
    required this.currency,
    this.serviceFeePerTicket = 1,
    required this.capacity,
    required this.available,
    required this.reserved,
    required this.sold,
    required this.points,
    required this.color,
  });

  final int id;
  final String name;
  final SectionMode mode;
  final double? price;
  final String? currency;
  final double serviceFeePerTicket;
  final int capacity;
  final int available;
  final int reserved;
  final int sold;

  /// Boundary polygon in layout-pixel space (may be empty if the admin drew no boundary).
  final List<Offset> points;
  final String? color;

  bool get isGeneralAdmission => mode == SectionMode.generalAdmission;
  bool get hasBoundary => points.length >= 3;

  /// A GA section the customer can buy into right now.
  bool get gaSelectable => isGeneralAdmission && available > 0;

  factory VenueSection.fromJson(Map<String, dynamic> j) => VenueSection(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        serviceFeePerTicket: _d(j['serviceFeePerTicket'], 1),
        mode: sectionModeOf(j['bookingMode'] as String?),
        price: j['price'] == null ? null : _d(j['price'], 0),
        currency: j['currency'] as String?,
        capacity: (j['capacity'] ?? 0) as int,
        available: (j['available'] ?? 0) as int,
        reserved: (j['reserved'] ?? 0) as int,
        sold: (j['sold'] ?? 0) as int,
        points: ((j['points'] as List?) ?? const [])
            .map((e) => Offset(
                  _d((e as Map<String, dynamic>)['x'], 0),
                  _d(e['y'], 0),
                ))
            .toList(),
        color: j['color'] as String?,
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
    required this.sectionId,
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
  final int? sectionId;
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
        sectionId: j['sectionId'] as int?,
        price: _d(j['price'], 0),
        status: _status(j['status'] as String?),
      );
}

double _d(dynamic v, double fallback) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}
