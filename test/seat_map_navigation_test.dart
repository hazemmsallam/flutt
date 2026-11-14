import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_mobile/src/models/seat_map.dart';
import 'package:ticketing_mobile/src/widgets/seat_map_view.dart';

void main() {
  testWidgets('dense map starts zoomed and both controls move its viewport',
      (tester) async {
    final seats = [
      for (var row = 0; row < 24; row++)
        for (var column = 0; column < 32; column++)
          Seat.fromJson({
            'seatId': row * 32 + column,
            'label': '$row-$column',
            'layoutX': column * 20,
            'layoutY': row * 20,
            'layoutWidth': 18,
            'layoutHeight': 18,
            'status': 'AVAILABLE',
          }),
    ];
    final section = VenueSection.fromJson({'id': 1, 'name': 'Class A'});
    final selected = <int>{};
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 350,
            height: 360,
            child: StatefulBuilder(
              builder: (context, setState) => SeatMapView(
                section: section,
                seats: seats,
                selectedIds: Set.of(selected),
                onToggle: (seat) => setState(() => selected.add(seat.id)),
              ),
            ),
          ),
        ),
      ),
    ));
    final viewer = find.byKey(const ValueKey('seat-map-viewport'));
    final transform =
        tester.widget<InteractiveViewer>(viewer).transformationController!;
    expect(transform.value.getMaxScaleOnAxis(), greaterThan(2));
    final initial = transform.value.getTranslation();

    final overview = find.byKey(const ValueKey('seat-map-overview'));
    await tester.tapAt(tester.getTopLeft(overview) + const Offset(122, 5));
    await tester.pump();
    final afterOverview = transform.value.getTranslation();
    expect(afterOverview.x, greaterThan(initial.x));
    expect(afterOverview.y, greaterThan(initial.y));

    final thumb = find.byKey(const ValueKey('seat-map-vertical-thumb'));
    await tester.dragFrom(
        tester.getTopLeft(thumb) + const Offset(9, 6), const Offset(0, 140));
    await tester.pump();
    final afterThumb = transform.value.getTranslation();
    expect(afterThumb.x, closeTo(afterOverview.x, .01));
    expect(afterThumb.y, lessThan(afterOverview.y));

    await tester.tapAt(tester.getCenter(viewer));
    await tester.pump();
    expect(selected, hasLength(1));
    expect(transform.value.getTranslation(), afterThumb);
  });
}
