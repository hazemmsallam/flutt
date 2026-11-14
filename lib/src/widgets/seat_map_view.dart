import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/seat_map.dart';
import '../theme/app_theme.dart';
import '../theme/seat_colors.dart' show SeatColors;

class SeatMapView extends StatelessWidget {
  const SeatMapView({
    super.key,
    required this.seats,
    required this.section,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Seat> seats;
  final VenueSection section;
  final Set<int> selectedIds;
  final ValueChanged<Seat> onToggle;

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      return const Center(
          child: Text('No seats have been placed in this section yet.'));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final overviewHeight = math.min(70.0, constraints.maxHeight * .24);
      final viewport = Size(
        math.max(1.0, constraints.maxWidth - 18),
        math.max(1.0, constraints.maxHeight - overviewHeight - 12),
      );
      return _SeatMapNavigator(
        seats: seats,
        section: section,
        viewport: viewport,
        overviewSize: Size(constraints.maxWidth, overviewHeight),
        selectedIds: selectedIds,
        onToggle: onToggle,
      );
    });
  }
}

class _SeatMapNavigator extends StatefulWidget {
  const _SeatMapNavigator({
    required this.seats,
    required this.section,
    required this.viewport,
    required this.overviewSize,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Seat> seats;
  final VenueSection section;
  final Size viewport;
  final Size overviewSize;
  final Set<int> selectedIds;
  final ValueChanged<Seat> onToggle;

  @override
  State<_SeatMapNavigator> createState() => _SeatMapNavigatorState();
}

class _SeatMapNavigatorState extends State<_SeatMapNavigator> {
  final _transform = TransformationController();
  late Rect _bounds;
  late Size _canvas;
  late Rect _content;
  late double _fit;
  late double _maxZoom;

  @override
  void initState() {
    super.initState();
    _measure();
    final sizes = widget.seats.map((seat) => math.min(seat.w, seat.h)).toList()
      ..sort();
    final typicalSeat = sizes[sizes.length ~/ 2] * _fit;
    final target = (widget.viewport.width / 9).clamp(24.0, 36.0);
    final zoom = (target / math.max(typicalSeat, .01)).clamp(1.0, _maxZoom);
    _moveTo(_content.center, zoom);
  }

  @override
  void didUpdateWidget(_SeatMapNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewport == widget.viewport &&
        identical(oldWidget.seats, widget.seats) &&
        identical(oldWidget.section, widget.section)) {
      return;
    }
    final oldCenter =
        _transform.toScene(oldWidget.viewport.center(Offset.zero));
    final oldScale = _transform.value.getMaxScaleOnAxis() * _fit;
    final layoutCenter =
        (oldCenter - _content.topLeft) / _fit + _bounds.topLeft;
    _measure();
    _moveTo(_content.topLeft + (layoutCenter - _bounds.topLeft) * _fit,
        (oldScale / _fit).clamp(1.0, _maxZoom));
  }

  void _measure() {
    final points = widget.section.points.toList();
    for (final seat in widget.seats) {
      final angle = seat.rotation * math.pi / 180;
      final c = math.cos(angle).abs();
      final s = math.sin(angle).abs();
      final footprint = Rect.fromCenter(
        center: Offset(seat.x + seat.w / 2, seat.y + seat.h / 2),
        width: seat.w * c + seat.h * s,
        height: seat.w * s + seat.h * c,
      );
      points.addAll([footprint.topLeft, footprint.bottomRight]);
    }
    var bounds = Rect.fromPoints(points.first, points.first);
    for (final point in points.skip(1)) {
      bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
    }
    _bounds = bounds
        .inflate(math.max(1, math.min(bounds.width, bounds.height) * .025));
    final viewport = widget.viewport;
    _fit = math.min(
        viewport.width / _bounds.width, viewport.height / _bounds.height);
    final contentSize = Size(_bounds.width * _fit, _bounds.height * _fit);
    _canvas = viewport;
    _content = Rect.fromCenter(
      center: _canvas.center(Offset.zero),
      width: contentSize.width,
      height: contentSize.height,
    );
    final smallestSide =
        widget.seats.map((seat) => math.min(seat.w, seat.h)).reduce(math.min);
    _maxZoom = math.max(6, 64 / math.max(smallestSide * _fit, .01));
  }

  void _moveTo(Offset center, double zoom) {
    final viewport = widget.viewport;
    double offset(double center, double start, double end, double extent) {
      final first = start * zoom;
      final last = end * zoom - extent;
      if (last < first) return (first + last) / 2;
      return (center * zoom - extent / 2).clamp(first, last);
    }

    final x = offset(center.dx, _content.left, _content.right, viewport.width);
    final y = offset(center.dy, _content.top, _content.bottom, viewport.height);
    _transform.value = Matrix4.diagonal3Values(zoom, zoom, zoom)
      ..setTranslationRaw(-x, -y, 0);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewSize = widget.overviewSize;
    final previewScale = math.min(
      previewSize.width / _bounds.width,
      previewSize.height / _bounds.height,
    );
    final previewRect = Rect.fromCenter(
      center: previewSize.center(Offset.zero),
      width: _bounds.width * previewScale,
      height: _bounds.height * previewScale,
    );
    final viewport = widget.viewport;

    return Column(children: [
      SizedBox.fromSize(
        size: previewSize,
        child: GestureDetector(
          key: const ValueKey('seat-map-overview'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _jumpToPreview(details.localPosition, previewRect, previewScale),
          onPanUpdate: (details) =>
              _jumpToPreview(details.localPosition, previewRect, previewScale),
          child: Stack(fit: StackFit.expand, children: [
            CustomPaint(
                painter: _OverviewPainter(
              seats: widget.seats,
              selectedIds: widget.selectedIds,
              origin: previewRect.topLeft - _bounds.topLeft * previewScale,
              scale: previewScale,
            )),
            ListenableBuilder(
              listenable: _transform,
              builder: (context, child) {
                final visible = Rect.fromPoints(_transform.toScene(Offset.zero),
                    _transform.toScene(viewport.bottomRight(Offset.zero)));
                final clip = visible.intersect(_content);
                if (clip.isEmpty) return const SizedBox.shrink();
                final rect = Rect.fromLTWH(
                  previewRect.left +
                      (clip.left - _content.left) / _fit * previewScale,
                  previewRect.top +
                      (clip.top - _content.top) / _fit * previewScale,
                  clip.width / _fit * previewScale,
                  clip.height / _fit * previewScale,
                );
                return Positioned.fromRect(
                  rect: rect,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.fromBorderSide(
                        BorderSide(color: AppColors.orange, width: 2),
                      ),
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Flexible(
        child: Row(children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              InteractiveViewer(
                key: const ValueKey('seat-map-viewport'),
                transformationController: _transform,
                constrained: false,
                maxScale: _maxZoom,
                child: SizedBox.fromSize(
                  size: _canvas,
                  child: Stack(
                    children: [
                      for (final seat in widget.seats)
                        Positioned(
                          left: _content.left + (seat.x - _bounds.left) * _fit,
                          top: _content.top + (seat.y - _bounds.top) * _fit,
                          width: seat.w * _fit,
                          height: seat.h * _fit,
                          child: Transform.rotate(
                            angle: seat.rotation * math.pi / 180,
                            child: _SeatTile(
                              seat: seat,
                              selected: widget.selectedIds.contains(seat.id),
                              onTap: seat.selectable
                                  ? () => widget.onToggle(seat)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.fromBorderSide(
                        BorderSide(color: Color(0xFF249DDC))),
                  ),
                ),
              ),
            ]),
          ),
          SizedBox(
            width: 18,
            child: ListenableBuilder(
              listenable: _transform,
              builder: (context, child) {
                final zoom = _transform.value.getMaxScaleOnAxis();
                final maxScroll = _canvas.height * zoom - viewport.height;
                final contentTop = _content.top * zoom;
                final contentHeight = _content.height * zoom;
                final scrollStart = contentTop.clamp(0.0, maxScroll);
                final scrollEnd = (contentTop + contentHeight - viewport.height)
                    .clamp(scrollStart, maxScroll);
                if (scrollEnd - scrollStart < 1) return const SizedBox.shrink();
                final offset = -_transform.value.getTranslation().y;
                return _VerticalMapThumb(
                  height: viewport.height,
                  fraction: ((offset - scrollStart) / (scrollEnd - scrollStart))
                      .clamp(0.0, 1.0),
                  visibleFraction: viewport.height / contentHeight,
                  onChanged: (fraction) {
                    final center =
                        _transform.toScene(viewport.center(Offset.zero));
                    final y =
                        scrollStart + (scrollEnd - scrollStart) * fraction;
                    _moveTo(Offset(center.dx, (y + viewport.height / 2) / zoom),
                        zoom);
                  },
                );
              },
            ),
          ),
        ]),
      ),
    ]);
  }

  void _jumpToPreview(Offset position, Rect previewRect, double previewScale) {
    final center = _content.topLeft +
        (position - previewRect.topLeft) / previewScale * _fit;
    _moveTo(center, _transform.value.getMaxScaleOnAxis());
  }
}

class _VerticalMapThumb extends StatefulWidget {
  const _VerticalMapThumb({
    required this.height,
    required this.fraction,
    required this.visibleFraction,
    required this.onChanged,
  });

  final double height;
  final double fraction;
  final double visibleFraction;
  final ValueChanged<double> onChanged;

  @override
  State<_VerticalMapThumb> createState() => _VerticalMapThumbState();
}

class _VerticalMapThumbState extends State<_VerticalMapThumb> {
  double _grabOffset = 0;

  @override
  Widget build(BuildContext context) {
    final thumb = math.min(
        widget.height, math.max(18.0, widget.height * widget.visibleFraction));
    final travel = widget.height - thumb;
    if (travel <= 0) return const SizedBox.shrink();
    final top = travel * widget.fraction;
    void move(double y) =>
        widget.onChanged(((y - _grabOffset) / travel).clamp(0.0, 1.0));

    final next = math.min(1.0, widget.fraction + .1);
    final previous = math.max(0.0, widget.fraction - .1);
    String percent(double value) => '${(value * 100).round()}%';
    return Semantics(
      label: 'Seat map vertical position',
      value: percent(widget.fraction),
      increasedValue: percent(next),
      decreasedValue: percent(previous),
      onIncrease: () => widget.onChanged(next),
      onDecrease: () => widget.onChanged(previous),
      child: GestureDetector(
        key: const ValueKey('seat-map-vertical-thumb'),
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          _grabOffset = thumb / 2;
          move(details.localPosition.dy);
        },
        onVerticalDragDown: (details) {
          final y = details.localPosition.dy;
          _grabOffset = y >= top && y <= top + thumb ? y - top : thumb / 2;
        },
        onVerticalDragUpdate: (details) => move(details.localPosition.dy),
        child: SizedBox(
          height: widget.height,
          child: Stack(alignment: Alignment.topCenter, children: [
            const Positioned(
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: AppColors.raised),
            ),
            Positioned(
              top: top,
              height: thumb,
              width: 4,
              child: const ColoredBox(color: AppColors.orange),
            ),
          ]),
        ),
      ),
    );
  }
}

Color _seatColor(Seat seat, bool selected) {
  if (selected) return const Color(0xFFF57900);
  return seat.selectable ? const Color(0xFF9BB75C) : const Color(0xFF777777);
}

class _OverviewPainter extends CustomPainter {
  const _OverviewPainter({
    required this.seats,
    required this.selectedIds,
    required this.origin,
    required this.scale,
  });

  final List<Seat> seats;
  final Set<int> selectedIds;
  final Offset origin;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final seat in seats) {
      paint.color = _seatColor(seat, selectedIds.contains(seat.id));
      final center =
          origin + Offset(seat.x + seat.w / 2, seat.y + seat.h / 2) * scale;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(seat.rotation * math.pi / 180);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero,
            width: seat.w * scale * .92,
            height: seat.h * scale * .92),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_OverviewPainter oldDelegate) =>
      oldDelegate.seats != seats ||
      oldDelegate.selectedIds != selectedIds ||
      oldDelegate.origin != origin ||
      oldDelegate.scale != scale;
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, required this.selected, this.onTap});

  final Seat seat;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Seat ${seat.label}',
      selected: selected,
      enabled: onTap != null,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FractionallySizedBox(
          widthFactor: .94,
          heightFactor: .94,
          child: ColoredBox(color: _seatColor(seat, selected)),
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
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(3))),
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
