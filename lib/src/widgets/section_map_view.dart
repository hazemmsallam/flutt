import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/seat_map.dart';

/// The venue seen as *sections* rather than seats — the first thing a customer meets
/// after picking an event.
///
/// Every section is drawn from the boundary polygon the admin drew, replayed in the same
/// layout-pixel space the seats use, so the customer sees the room exactly as it was laid
/// out. Tapping a section is resolved by point-in-polygon containment (the same ray-casting
/// rule the server uses to assign seats to sections), which means irregular, circular and
/// free-form shapes hit-test correctly without any per-shape code.
///
/// What a tap *means* depends on the section, and that decision belongs to the caller:
/// a seated section drills into its seats, a general-admission section asks for a quantity.
class SectionMapView extends StatelessWidget {
  const SectionMapView({
    super.key,
    required this.map,
    required this.onSectionTap,
    this.selectedSectionId,
  });

  final SeatMap map;
  final ValueChanged<VenueSection> onSectionTap;
  final int? selectedSectionId;

  @override
  Widget build(BuildContext context) {
    final drawable = map.sections.where((s) => s.hasBoundary).toList();

    if (drawable.isEmpty) {
      return const _NoBoundaries();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit the whole hall in view — this is an overview, so it should never need panning
        // to understand. Seats get the zoomable treatment once you're inside a section.
        final scale = math.min(
          constraints.maxWidth / map.layoutWidth,
          constraints.maxHeight / map.layoutHeight,
        );
        final w = map.layoutWidth * scale;
        final h = map.layoutHeight * scale;

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final p = details.localPosition / scale;
                // Topmost first: later sections paint over earlier ones, so a tap in an
                // overlap should select what the customer actually sees.
                for (final s in drawable.reversed) {
                  if (sectionContains(s.points, p)) {
                    onSectionTap(s);
                    return;
                  }
                }
              },
              child: CustomPaint(
                painter: _SectionPainter(
                  sections: drawable,
                  tables: map.tables,
                  scale: scale,
                  selectedId: selectedSectionId,
                  textDirection: Directionality.of(context),
                ),
                size: Size(w, h),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Ray-casting point-in-polygon, mirroring the server's SectionGeometry.contains so the
/// client and server never disagree about which section a point belongs to.
///
/// Public so it can be tested directly: this is the rule that decides what a tap selects,
/// and it has to hold for concave and many-sided (circle/curve) polygons, not just boxes.
bool sectionContains(List<Offset> polygon, Offset p) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].dx, yi = polygon[i].dy;
    final xj = polygon[j].dx, yj = polygon[j].dy;
    final intersects = ((yi > p.dy) != (yj > p.dy)) &&
        (p.dx < (xj - xi) * (p.dy - yi) / (yj - yi) + xi);
    if (intersects) inside = !inside;
  }
  return inside;
}

class _SectionPainter extends CustomPainter {
  _SectionPainter({
    required this.sections,
    required this.tables,
    required this.scale,
    required this.selectedId,
    required this.textDirection,
  });

  final List<VenueSection> sections;
  final List<VenueTable> tables;
  final double scale;
  final int? selectedId;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    _paintStage(canvas, size);

    // Tables are context, not targets — draw them faintly beneath the sections.
    final tablePaint = Paint()..color = const Color(0x33A5744A);
    for (final t in tables) {
      final rect = Rect.fromLTWH(t.x * scale, t.y * scale, t.w * scale, t.d * scale);
      if (t.shape == TableShape.circle) {
        canvas.drawOval(rect, tablePaint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(3 * scale)),
          tablePaint,
        );
      }
    }

    for (final s in sections) {
      final path = _pathFor(s);
      final base = _colorOf(s);
      final soldOut = s.available <= 0;
      final selected = s.id == selectedId;

      canvas.drawPath(
        path,
        Paint()..color = base.withOpacity(soldOut ? 0.10 : (selected ? 0.42 : 0.26)),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 1.6
          ..color = soldOut ? base.withOpacity(0.35) : base,
      );

      _paintLabel(canvas, s, path, soldOut);
    }
  }

  void _paintStage(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width * 0.2, 14 * scale, size.width * 0.6, 34 * scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(6 * scale)),
      Paint()..color = const Color(0xFF1F2430),
    );
    _text(
      canvas,
      'STAGE',
      rect.center,
      TextStyle(
        color: Colors.white,
        fontSize: math.max(9, 12 * scale),
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    );
  }

  Path _pathFor(VenueSection s) {
    final path = Path()..moveTo(s.points.first.dx * scale, s.points.first.dy * scale);
    for (final p in s.points.skip(1)) {
      path.lineTo(p.dx * scale, p.dy * scale);
    }
    return path..close();
  }

  /// Name, then the line that actually decides the tap: seats left, or tickets left.
  void _paintLabel(Canvas canvas, VenueSection s, Path path, bool soldOut) {
    final c = path.getBounds().center;
    const onDark = Colors.white;

    _text(
      canvas,
      s.name,
      c.translate(0, -10),
      TextStyle(
        color: onDark,
        fontSize: math.max(10, 13 * scale),
        fontWeight: FontWeight.w800,
        shadows: const [Shadow(color: Color(0xCC0F1218), blurRadius: 3)],
      ),
    );

    final detail = soldOut
        ? 'Sold out'
        : s.isGeneralAdmission
            ? '${s.available} tickets'
            : '${s.available} seats';
    final price = s.price == null ? '' : ' · ${s.price!.toStringAsFixed(2)} ${s.currency ?? ''}';

    _text(
      canvas,
      '$detail$price',
      c.translate(0, 8),
      TextStyle(
        color: onDark.withOpacity(soldOut ? 0.7 : 0.92),
        fontSize: math.max(9, 11 * scale),
        fontWeight: FontWeight.w600,
        shadows: const [Shadow(color: Color(0xCC0F1218), blurRadius: 3)],
      ),
    );
  }

  void _text(Canvas canvas, String value, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: textDirection,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 160);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_SectionPainter old) =>
      old.selectedId != selectedId || old.sections != sections || old.scale != scale;
}

/// Parses the admin's `#RRGGBB`, falling back to a stable colour derived from the section id
/// so an uncoloured hall still reads as distinct areas rather than a wash of grey.
Color _colorOf(VenueSection s) {
  final hex = s.color?.replaceFirst('#', '');
  if (hex != null && hex.length == 6) {
    final value = int.tryParse(hex, radix: 16);
    if (value != null) return Color(value | 0xFF000000);
  }
  const fallback = [
    Color(0xFF2E75DC), Color(0xFF9A5CF5), Color(0xFF23A094), Color(0xFFE0803B),
    Color(0xFFD8574F), Color(0xFF3FA34D), Color(0xFFB4497E), Color(0xFF5C6BC0),
  ];
  return fallback[s.id % fallback.length];
}

/// Public so the seat view can outline the section the customer drilled into.
Color sectionColor(VenueSection s) => _colorOf(s);

class _NoBoundaries extends StatelessWidget {
  const _NoBoundaries();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This hall has no section outlines yet.\nPick your seats from the map instead.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
}
