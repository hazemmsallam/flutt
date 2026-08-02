import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/seat_map.dart';
import '../theme/seat_colors.dart';
import 'section_map_view.dart' show sectionColor;

/// Renders a [SeatMap] by replaying the stored logical-pixel coordinates.
///
/// The canvas is scaled to fit the available width; the whole thing is wrapped
/// in an [InteractiveViewer] so the user can pinch-zoom and pan. Each seat is a
/// [Positioned] + [Transform.rotate] tile, so rotation and per-seat size from the
/// admin layout show up faithfully, and tap hit-testing is per widget.
///
/// Pass [focus] to drill into one seated section: only that section's seats are drawn,
/// the view scales to the section's own bounds so the seats fill the screen, and the
/// section outline is kept as a faint backdrop for orientation. Seat positions are never
/// recomputed — they stay exactly where the admin put them, just viewed more closely.
class SeatMapView extends StatelessWidget {
  const SeatMapView({
    super.key,
    required this.map,
    required this.selectedIds,
    required this.onToggle,
    this.focus,
  });

  final SeatMap map;
  final Set<int> selectedIds;
  final ValueChanged<Seat> onToggle;
  final VenueSection? focus;

  @override
  Widget build(BuildContext context) {
    final section = focus;
    final seats = section == null
        ? map.seats
        : map.seats.where((s) => s.sectionId == section.id).toList();

    if (section != null && seats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No seats have been placed in this section yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    // Drilling in fits the section's bounding box (padded) instead of the whole hall,
    // so a small block of seats doesn't render as unreadable specks.
    final bounds = section == null ? null : _paddedBounds(section, seats);

    return LayoutBuilder(
      builder: (context, constraints) {
        final srcW = bounds?.width ?? map.layoutWidth;
        final srcH = bounds?.height ?? map.layoutHeight;
        final scale = bounds == null
            ? constraints.maxWidth / map.layoutWidth
            : math.min(constraints.maxWidth / srcW, constraints.maxHeight / srcH);

        final dx = -(bounds?.left ?? 0) * scale;
        final dy = -(bounds?.top ?? 0) * scale;
        final w = srcW * scale;
        final h = srcH * scale;

        return InteractiveViewer(
          constrained: false,
          minScale: 1,
          maxScale: 6,
          boundaryMargin: const EdgeInsets.all(64),
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                if (section == null)
                  _Stage(width: w, scale: scale)
                else
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SectionOutline(
                        section: section,
                        scale: scale,
                        offset: Offset(dx, dy),
                      ),
                    ),
                  ),
                for (final seat in seats)
                  Positioned(
                    left: seat.x * scale + dx,
                    top: seat.y * scale + dy,
                    width: seat.w * scale,
                    height: seat.h * scale,
                    child: Transform.rotate(
                      angle: seat.rotation * math.pi / 180,
                      child: _SeatTile(
                        seat: seat,
                        selected: selectedIds.contains(seat.id),
                        onTap: seat.selectable ? () => onToggle(seat) : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The section polygon unioned with its seats, padded so edge seats aren't clipped.
  Rect _paddedBounds(VenueSection section, List<Seat> seats) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;

    void add(double x, double y) {
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }

    for (final p in section.points) {
      add(p.dx, p.dy);
    }
    for (final s in seats) {
      add(s.x, s.y);
      add(s.x + s.w, s.y + s.h);
    }
    if (minX == double.infinity) return Rect.zero;

    const pad = 24.0;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }
}

/// The focused section's boundary, drawn behind its seats purely for orientation.
class _SectionOutline extends CustomPainter {
  _SectionOutline({required this.section, required this.scale, required this.offset});

  final VenueSection section;
  final double scale;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    if (!section.hasBoundary) return;
    final c = sectionColor(section);
    final path = Path()
      ..moveTo(section.points.first.dx * scale + offset.dx,
          section.points.first.dy * scale + offset.dy);
    for (final p in section.points.skip(1)) {
      path.lineTo(p.dx * scale + offset.dx, p.dy * scale + offset.dy);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = c.withOpacity(0.10));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = c.withOpacity(0.55),
    );
  }

  @override
  bool shouldRepaint(_SectionOutline old) =>
      old.section != section || old.scale != scale || old.offset != offset;
}

class _Stage extends StatelessWidget {
  const _Stage({required this.width, required this.scale});
  final double width;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40 * scale,
      left: width * 0.2,
      width: width * 0.6,
      height: 40 * scale,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1F2430),
          borderRadius: BorderRadius.circular(8 * scale),
        ),
        child: Text(
          'STAGE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: math.max(9, 14 * scale),
          ),
        ),
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, required this.selected, this.onTap});
  final Seat seat;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = SeatColors.fill(seat, selected);
    final taken = seat.status != SeatStatus.available;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: taken && !selected ? 0.55 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(7),
              bottom: Radius.circular(10),
            ),
            border: selected ? Border.all(color: Colors.white, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text(
                seat.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small legend row for seat colours/states.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        );

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        dot(SeatColors.vip, 'VIP'),
        dot(SeatColors.premium, 'Premium'),
        dot(SeatColors.regular, 'Regular'),
        dot(SeatColors.reserved, 'Held'),
        dot(SeatColors.booked, 'Sold'),
        dot(SeatColors.selected, 'Selected'),
        dot(const Color(0xFFA5744A), 'Table'),
      ],
    );
  }
}
