import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/seat_map.dart';
import '../theme/seat_colors.dart';

/// Renders a [SeatMap] by replaying the stored logical-pixel coordinates.
///
/// The canvas is scaled to fit the available width; the whole thing is wrapped
/// in an [InteractiveViewer] so the user can pinch-zoom and pan. Each seat is a
/// [Positioned] + [Transform.rotate] tile, so rotation and per-seat size from the
/// admin layout show up faithfully, and tap hit-testing is per widget.
class SeatMapView extends StatelessWidget {
  const SeatMapView({
    super.key,
    required this.map,
    required this.selectedIds,
    required this.onToggle,
  });

  final SeatMap map;
  final Set<int> selectedIds;
  final ValueChanged<Seat> onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / map.layoutWidth;
        final w = map.layoutWidth * scale;
        final h = map.layoutHeight * scale;

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
                _Stage(width: w, scale: scale),
                for (final seat in map.seats)
                  Positioned(
                    left: seat.x * scale,
                    top: seat.y * scale,
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
      ],
    );
  }
}
