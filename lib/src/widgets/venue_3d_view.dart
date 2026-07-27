import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/seat_map.dart';
import '../theme/seat_colors.dart';

/// Renders a [SeatMap] as an interactive 3D venue — the same layout the admin
/// created, using the same coordinate system, so chairs and tables line up with
/// the web preview.
///
/// This is a dependency-free renderer: it projects the stored layout into a
/// small perspective camera and paints it with a [CustomPainter] (painter's
/// algorithm + back-face culling). Chairs stay tap-selectable exactly like the
/// 2D map; tables are drawn for context only and are never hit-tested.
///
/// Gestures: one-finger drag orbits, two-finger pinch zooms, tap selects a chair.
class Venue3DView extends StatefulWidget {
  const Venue3DView({
    super.key,
    required this.map,
    required this.selectedIds,
    required this.onToggle,
  });

  final SeatMap map;
  final Set<int> selectedIds;
  final ValueChanged<Seat> onToggle;

  @override
  State<Venue3DView> createState() => _Venue3DViewState();
}

class _Venue3DViewState extends State<Venue3DView> {
  // Logical pixels per world metre — matches the admin 3D preview scale.
  static const double _ppm = 52.0;

  double _azimuth = 0.6;
  double _elevation = 0.72;
  late double _distance;
  bool _initialised = false;

  // Gesture anchors (captured at the start of a scale/drag).
  double _azStart = 0;
  double _elStart = 0;
  double _distStart = 0;
  Offset _focalStart = Offset.zero;

  Size _viewport = Size.zero;

  double get _worldWidth => widget.map.layoutWidth / _ppm;
  double get _worldDepth => widget.map.layoutHeight / _ppm;
  double get _span => math.max(_worldWidth, _worldDepth);

  void _ensureInit() {
    if (_initialised) return;
    _distance = _span * 1.7 + 4;
    _initialised = true;
  }

  double get _minDistance => 2.5;
  double get _maxDistance => _span * 6 + 24;

  void _onScaleStart(ScaleStartDetails d) {
    _azStart = _azimuth;
    _elStart = _elevation;
    _distStart = _distance;
    _focalStart = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      // Zoom from pinch scale.
      if ((d.scale - 1).abs() > 0.001) {
        _distance = (_distStart / d.scale).clamp(_minDistance, _maxDistance);
      }
      // Orbit from focal-point travel since the gesture started.
      final delta = d.localFocalPoint - _focalStart;
      _azimuth = _azStart - delta.dx * 0.008;
      _elevation = (_elStart - delta.dy * 0.008).clamp(0.12, 1.45);
    });
  }

  void _onTapUp(TapUpDetails d) {
    final cam = _camera(_viewport);
    if (cam == null) return;
    final seat = _hitTestChair(cam, d.localPosition);
    if (seat != null && seat.selectable) {
      widget.onToggle(seat);
    }
  }

  _OrbitCamera? _camera(Size size) {
    if (size.isEmpty) return null;
    _ensureInit();
    return _OrbitCamera(
      azimuth: _azimuth,
      elevation: _elevation,
      distance: _distance,
      viewport: size,
      focal: size.shortestSide * 1.15,
    );
  }

  // Chair centre in world space (y is up; seat.y maps to world depth/z).
  _Vec3 _seatCentre(Seat s) => _Vec3(
        (s.x + s.w / 2) / _ppm - _worldWidth / 2,
        0,
        (s.y + s.h / 2) / _ppm - _worldDepth / 2,
      );

  Seat? _hitTestChair(_OrbitCamera cam, Offset p) {
    Seat? best;
    double bestDepth = double.infinity;
    for (final seat in widget.map.seats) {
      if (!seat.selectable) continue;
      final centre = _seatCentre(seat);
      final w = seat.w / _ppm;
      final d = seat.h / _ppm;
      const topY = 0.44; // cushion top
      final corners = _footprint(centre.x, centre.z, w, d, seat.rotation, topY);
      final projected = <Offset>[];
      var depth = 0.0;
      var ok = true;
      for (final c in corners) {
        final pr = cam.project(c);
        if (pr == null) {
          ok = false;
          break;
        }
        projected.add(pr.screen);
        depth += pr.depth;
      }
      if (!ok) continue;
      if (_pointInPolygon(p, projected) && depth < bestDepth) {
        bestDepth = depth;
        best = seat;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final cam = _camera(_viewport);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onTapUp: _onTapUp,
          child: CustomPaint(
            size: _viewport,
            painter: _VenuePainter(
              map: widget.map,
              selectedIds: widget.selectedIds,
              camera: cam,
              ppm: _ppm,
              worldWidth: _worldWidth,
              worldDepth: _worldDepth,
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Geometry helpers
// ---------------------------------------------------------------------------

class _Vec3 {
  const _Vec3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator -(_Vec3 o) => _Vec3(x - o.x, y - o.y, z - o.z);
  _Vec3 scale(double s) => _Vec3(x * s, y * s, z * s);
  double dot(_Vec3 o) => x * o.x + y * o.y + z * o.z;
  _Vec3 cross(_Vec3 o) =>
      _Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  _Vec3 get normalized {
    final l = length;
    return l == 0 ? const _Vec3(0, 0, 0) : _Vec3(x / l, y / l, z / l);
  }
}

class _Projected {
  const _Projected(this.screen, this.depth);
  final Offset screen;
  final double depth; // camera-forward distance
}

class _OrbitCamera {
  _OrbitCamera({
    required this.azimuth,
    required this.elevation,
    required this.distance,
    required this.viewport,
    required this.focal,
  }) {
    eye = _Vec3(
      distance * math.cos(elevation) * math.sin(azimuth),
      distance * math.sin(elevation),
      distance * math.cos(elevation) * math.cos(azimuth),
    );
    const target = _Vec3(0, 0, 0);
    forward = (target - eye).normalized;
    const worldUp = _Vec3(0, 1, 0);
    right = forward.cross(worldUp).normalized;
    up = right.cross(forward).normalized;
  }

  final double azimuth;
  final double elevation;
  final double distance;
  final Size viewport;
  final double focal;

  late final _Vec3 eye;
  late final _Vec3 forward;
  late final _Vec3 right;
  late final _Vec3 up;

  _Projected? project(_Vec3 p) {
    final rel = p - eye;
    final camZ = rel.dot(forward);
    if (camZ <= 0.05) return null; // behind camera / too close
    final camX = rel.dot(right);
    final camY = rel.dot(up);
    final sx = viewport.width / 2 + focal * camX / camZ;
    final sy = viewport.height / 2 - focal * camY / camZ;
    return _Projected(Offset(sx, sy), camZ);
  }
}

/// Footprint corners (CCW) of a w x d rectangle centred at (cx,cz), rotated
/// [rotDeg] about the vertical axis, all at height [y].
List<_Vec3> _footprint(
    double cx, double cz, double w, double d, double rotDeg, double y) {
  final hw = w / 2, hd = d / 2;
  final th = rotDeg * math.pi / 180;
  final c = math.cos(th), s = math.sin(th);
  const locals = [
    [-1.0, -1.0],
    [1.0, -1.0],
    [1.0, 1.0],
    [-1.0, 1.0],
  ];
  return locals.map((l) {
    final dx = l[0] * hw, dz = l[1] * hd;
    return _Vec3(cx + dx * c - dz * s, y, cz + dx * s + dz * c);
  }).toList();
}

/// Footprint corners for an ellipse (used for circular tables), [n] segments.
List<_Vec3> _ellipseFootprint(
    double cx, double cz, double w, double d, double rotDeg, double y, int n) {
  final rx = w / 2, rz = d / 2;
  final th = rotDeg * math.pi / 180;
  final c = math.cos(th), s = math.sin(th);
  final out = <_Vec3>[];
  for (var i = 0; i < n; i++) {
    final a = (i / n) * 2 * math.pi;
    final dx = math.cos(a) * rx, dz = math.sin(a) * rz;
    out.add(_Vec3(cx + dx * c - dz * s, y, cz + dx * s + dz * c));
  }
  return out;
}

bool _pointInPolygon(Offset p, List<Offset> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    final intersect = (a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx;
    if (intersect) inside = !inside;
  }
  return inside;
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _Face {
  _Face(this.world, this.color, this.camera);

  final List<_Vec3> world;
  final Color color;
  final _OrbitCamera camera;

  List<Offset>? _screen;
  double _depth = 0;
  bool _visible = false;

  static final _Vec3 _light = const _Vec3(-0.4, 1.0, 0.35).normalized;

  void prepare() {
    // Project every corner; a face is drawn only if all corners are in front of
    // the camera. Occlusion is handled by depth-sorting faces (painter's
    // algorithm), so no back-face culling is needed — nearer faces overpaint
    // farther ones, which keeps the result correct regardless of winding.
    final pts = <Offset>[];
    var depth = 0.0;
    for (final v in world) {
      final pr = camera.project(v);
      if (pr == null) {
        _visible = false;
        return;
      }
      pts.add(pr.screen);
      depth += pr.depth;
    }
    _screen = pts;
    _depth = depth / world.length;
    _visible = true;
  }

  Color get shaded {
    final n = (world[1] - world[0]).cross(world[2] - world[0]).normalized;
    final lambert = 0.55 + 0.45 * math.max(0.0, n.dot(_light));
    return Color.fromARGB(
      color.alpha,
      (color.red * lambert).clamp(0, 255).round(),
      (color.green * lambert).clamp(0, 255).round(),
      (color.blue * lambert).clamp(0, 255).round(),
    );
  }
}

class _VenuePainter extends CustomPainter {
  _VenuePainter({
    required this.map,
    required this.selectedIds,
    required this.camera,
    required this.ppm,
    required this.worldWidth,
    required this.worldDepth,
  });

  final SeatMap map;
  final Set<int> selectedIds;
  final _OrbitCamera? camera;
  final double ppm;
  final double worldWidth;
  final double worldDepth;

  static const _tableTop = Color(0xFFA5744A);
  static const _tablePedestal = Color(0xFF6B4423);

  @override
  void paint(Canvas canvas, Size size) {
    final cam = camera;
    if (cam == null) return;

    canvas.drawColor(const Color(0xFF11151C), BlendMode.src);

    _paintFloor(canvas, cam);

    final faces = <_Face>[];
    _addStage(faces, cam);
    for (final table in map.tables) {
      _addTable(faces, cam, table);
    }
    for (final seat in map.seats) {
      _addSeat(faces, cam, seat);
    }

    for (final f in faces) {
      f.prepare();
    }
    final visible = faces.where((f) => f._visible).toList()
      ..sort((a, b) => b._depth.compareTo(a._depth)); // far first

    final fill = Paint()..style = PaintingStyle.fill;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0x22000000);
    for (final f in visible) {
      final path = _poly(f._screen!);
      fill.color = f.shaded;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }

    _paintStageLabel(canvas, cam);
  }

  Path _poly(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path..close();
  }

  void _paintFloor(Canvas canvas, _OrbitCamera cam) {
    final hw = worldWidth / 2 + 1.2;
    final hd = worldDepth / 2 + 1.2;
    final corners = [
      _Vec3(-hw, 0, -hd),
      _Vec3(hw, 0, -hd),
      _Vec3(hw, 0, hd),
      _Vec3(-hw, 0, hd),
    ];
    final pts = <Offset>[];
    for (final c in corners) {
      final pr = cam.project(c);
      if (pr == null) return;
      pts.add(pr.screen);
    }
    canvas.drawPath(_poly(pts), Paint()..color = const Color(0xFF20262F));

    // Grid lines every ~2 m.
    final grid = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 0.6;
    const step = 2.0;
    for (double x = -hw; x <= hw + 0.001; x += step) {
      final a = cam.project(_Vec3(x, 0, -hd));
      final b = cam.project(_Vec3(x, 0, hd));
      if (a != null && b != null) canvas.drawLine(a.screen, b.screen, grid);
    }
    for (double z = -hd; z <= hd + 0.001; z += step) {
      final a = cam.project(_Vec3(-hw, 0, z));
      final b = cam.project(_Vec3(hw, 0, z));
      if (a != null && b != null) canvas.drawLine(a.screen, b.screen, grid);
    }
  }

  void _addPrism(List<_Face> faces, _OrbitCamera cam, List<_Vec3> bottom,
      List<_Vec3> top, Color side, Color topColor) {
    // Top face.
    faces.add(_Face(top, topColor, cam));
    // Side faces.
    for (var i = 0; i < bottom.length; i++) {
      final j = (i + 1) % bottom.length;
      faces.add(_Face([bottom[i], bottom[j], top[j], top[i]], side, cam));
    }
  }

  void _addSeat(List<_Face> faces, _OrbitCamera cam, Seat seat) {
    final cx = (seat.x + seat.w / 2) / ppm - worldWidth / 2;
    final cz = (seat.y + seat.h / 2) / ppm - worldDepth / 2;
    final w = seat.w / ppm;
    final d = seat.h / ppm;
    final selected = selectedIds.contains(seat.id);
    final base = SeatColors.fill(seat, selected);

    const seatTop = 0.44;
    final bottom = _footprint(cx, cz, w, d, seat.rotation, 0.06);
    final top = _footprint(cx, cz, w, d, seat.rotation, seatTop);
    _addPrism(faces, cam, bottom, top, base, base);

    // Backrest: a slab standing on the back edge (corners 2->3, local +d side).
    final backLow = [top[2], top[3]];
    final backHigh = [
      _Vec3(top[3].x, 0.82, top[3].z),
      _Vec3(top[2].x, 0.82, top[2].z),
    ];
    faces.add(_Face(
        [backLow[0], backLow[1], backHigh[0], backHigh[1]], base, cam));
  }

  void _addTable(List<_Face> faces, _OrbitCamera cam, VenueTable t) {
    final cx = (t.x + t.w / 2) / ppm - worldWidth / 2;
    final cz = (t.y + t.d / 2) / ppm - worldDepth / 2;
    final w = t.w / ppm;
    final d = t.d / ppm;
    final baseY = t.z / ppm;
    final height = math.max(0.12, t.height / ppm);
    final topThick = math.min(0.1, height * 0.35);
    final legTop = baseY + height - topThick;

    final circle = t.shape == TableShape.circle;
    final n = circle ? 20 : 4;
    List<_Vec3> foot(double scale, double y) => circle
        ? _ellipseFootprint(cx, cz, w * scale, d * scale, t.rotation, y, n)
        : _footprint(cx, cz, w * scale, d * scale, t.rotation, y);

    // Table top slab.
    _addPrism(faces, cam, foot(1, legTop), foot(1, baseY + height),
        _tableTop, _tableTop);
    // Central pedestal.
    _addPrism(faces, cam, foot(0.42, baseY), foot(0.42, legTop),
        _tablePedestal, _tablePedestal);
  }

  void _addStage(List<_Face> faces, _OrbitCamera cam) {
    final stageW = math.min(map.layoutWidth * 0.6, 520) / ppm;
    final stageDepth = 1.0;
    final cz = 60 / ppm - worldDepth / 2;
    final bottom = _footprint(0, cz, stageW, stageDepth, 0, 0);
    final top = _footprint(0, cz, stageW, stageDepth, 0, 0.4);
    _addPrism(faces, cam, bottom, top, const Color(0xFF2A3140),
        const Color(0xFF323B4C));
  }

  void _paintStageLabel(Canvas canvas, _OrbitCamera cam) {
    final cz = 60 / ppm - worldDepth / 2;
    final pr = cam.project(_Vec3(0, 0.42, cz));
    if (pr == null) return;
    final tp = TextPainter(
      text: const TextSpan(
        text: 'STAGE',
        style: TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pr.screen - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _VenuePainter old) =>
      old.camera != camera ||
      old.map != map ||
      old.selectedIds != selectedIds;
}
