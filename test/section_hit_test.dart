import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ticketing_mobile/src/widgets/section_map_view.dart';

/// Tapping a section is resolved by point-in-polygon containment, so this rule decides
/// what the customer actually selects. It must behave for the shapes the admin editor can
/// produce — rectangles, triangles, many-sided circles/curves and concave free-form areas —
/// and it must agree with the server's SectionGeometry.contains.
void main() {
  group('sectionContains', () {
    test('rectangle: inside, outside, and beyond each edge', () {
      const rect = [
        Offset(100, 50),
        Offset(220, 50),
        Offset(220, 150),
        Offset(100, 150),
      ];

      expect(sectionContains(rect, const Offset(160, 100)), isTrue);
      expect(sectionContains(rect, const Offset(90, 100)), isFalse); // left
      expect(sectionContains(rect, const Offset(230, 100)), isFalse); // right
      expect(sectionContains(rect, const Offset(160, 40)), isFalse); // above
      expect(sectionContains(rect, const Offset(160, 160)), isFalse); // below
    });

    test('triangle: apex region in, top corners out', () {
      // Apex-up triangle inscribed in a 240x160 box at (100,50).
      const tri = [Offset(220, 50), Offset(340, 210), Offset(100, 210)];

      expect(sectionContains(tri, const Offset(220, 200)), isTrue);
      expect(sectionContains(tri, const Offset(110, 60)), isFalse);
      expect(sectionContains(tri, const Offset(330, 60)), isFalse);
    });

    test('circle approximated by 48 segments: centre in, box corner out', () {
      final circle = <Offset>[
        for (var i = 0; i < 48; i++)
          Offset(
            200 + 80 * math.cos(2 * math.pi * i / 48),
            200 + 80 * math.sin(2 * math.pi * i / 48),
          ),
      ];

      expect(sectionContains(circle, const Offset(200, 200)), isTrue);
      expect(sectionContains(circle, const Offset(255, 255)), isTrue); // ~77.8 from centre
      // The bounding-box corner is ~113 away — outside the inscribed circle.
      expect(sectionContains(circle, const Offset(280, 280)), isFalse);
      expect(sectionContains(circle, const Offset(200, 285)), isFalse); // just past the rim
    });

    test('concave curve band: solid horn in, hollow middle out', () {
      // Crescent: outer arc swept left-to-right, inner arc swept back.
      const cx = 200.0, baseY = 200.0, outer = 100.0, inner = 50.0;
      final band = <Offset>[
        for (var i = 0; i <= 32; i++)
          Offset(cx + outer * math.cos(math.pi - math.pi * i / 32),
              baseY - outer * math.sin(math.pi - math.pi * i / 32)),
        for (var i = 0; i <= 32; i++)
          Offset(cx + inner * math.cos(math.pi * i / 32),
              baseY - inner * math.sin(math.pi * i / 32)),
      ];

      expect(sectionContains(band, const Offset(125, 195)), isTrue); // inside the band
      expect(sectionContains(band, const Offset(200, 195)), isFalse); // the hollow
    });

    test('degenerate polygons never contain anything', () {
      expect(sectionContains(const [], const Offset(0, 0)), isFalse);
      expect(
        sectionContains(const [Offset(0, 0), Offset(10, 10)], const Offset(5, 5)),
        isFalse,
      );
    });
  });
}
