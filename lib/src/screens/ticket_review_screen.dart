import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_summary.dart';
import '../models/seat_map.dart';
import 'events_screen.dart' show EventPoster;

const _background = Color(0xFF1C1B20);
const _card = Color(0xFF252525);
const _totalBar = Color(0xFF424242);
const _orange = Color(0xFFFF7500);
const _muted = Color(0xFFA7A8AD);
const _divider = Color(0xFF343434);

class TicketReviewScreen extends StatefulWidget {
  const TicketReviewScreen({
    super.key,
    required this.event,
    required this.seats,
    required this.seatSections,
    this.gaSection,
    this.gaQuantity = 0,
  });

  final EventSummary event;
  final List<Seat> seats;
  final Map<int, VenueSection> seatSections;
  final VenueSection? gaSection;
  final int gaQuantity;

  @override
  State<TicketReviewScreen> createState() => _TicketReviewScreenState();
}

class _TicketReviewScreenState extends State<TicketReviewScreen> {
  late final _seats = List<Seat>.of(widget.seats);
  late int _gaQuantity = widget.gaQuantity;

  List<int> get _seatIds => _seats.map((seat) => seat.id).toList();

  void _editSelection({bool pickAnotherSection = false}) {
    Navigator.pop(context, (
      seatIds: _seatIds,
      gaQuantity: _gaQuantity,
      proceed: false,
      pickAnotherSection: pickAnotherSection
    ));
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final ga = widget.gaSection;
    final groups = <(int?, String, double), int>{};
    for (final seat in _seats) {
      final section = widget.seatSections[seat.sectionId];
      final key = (
        seat.sectionId,
        section?.name.trim().isNotEmpty == true
            ? section!.name
            : (seat.sectionName?.trim().isNotEmpty == true
                ? seat.sectionName!
                : seat.sectionId == null
                    ? 'Reserved seats'
                    : 'Section ${seat.sectionId}'),
        seat.price
      );
      groups.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    final fee = _seats.fold(
            0.0,
            (sum, seat) =>
                sum +
                (widget.seatSections[seat.sectionId]?.serviceFeePerTicket ??
                    1)) +
        (ga?.serviceFeePerTicket ?? 0) * _gaQuantity;
    final subtotal = _seats.fold(0.0, (sum, seat) => sum + seat.price) +
        (ga?.price ?? 0) * _gaQuantity;
    final currency = event.currency ?? ga?.currency ?? 'JOD';
    String money(double amount) => '${amount.toStringAsFixed(2)} $currency';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _editSelection();
      },
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: ListView(
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: MediaQuery.sizeOf(context).width * (215 / 332),
                    child: EventPoster(imageUrl: event.imageUrl),
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xCC1C1B20), Colors.transparent],
                            stops: [0, .65],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 8,
                    child: IconButton(
                      onPressed: _editSelection,
                      tooltip: 'Back to seat selection',
                      icon: const Icon(Icons.arrow_back,
                          size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 20, 15, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(event.name,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        if (event.startAt case final start?)
                          _EventInfo(Icons.calendar_today_outlined,
                              DateFormat('d MMMM Â· h:mm a').format(start)),
                        if (event.hallName.isNotEmpty)
                          _EventInfo(
                              Icons.location_on_outlined, event.hallName),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: ColoredBox(
                        color: _card,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_seats.isNotEmpty) ...[
                                    const Text('Seats',
                                        style: TextStyle(fontSize: 12)),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final seat in _seats)
                                          _SeatBadge(
                                            label: seat.label,
                                            onRemove: () => setState(
                                                () => _seats.remove(seat)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: _divider),
                                    const SizedBox(height: 13),
                                  ],
                                  const Text('Tickets',
                                      style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 8),
                                  for (final entry in groups.entries)
                                    _TicketLine(
                                      label:
                                          '${entry.key.$2} Ã— ${entry.value}',
                                      amount: money(entry.key.$3 * entry.value),
                                    ),
                                  if (ga != null && _gaQuantity > 0)
                                    _TicketLine(
                                      label:
                                          '${ga.name} Â· General admission Ã— $_gaQuantity',
                                      amount:
                                          money((ga.price ?? 0) * _gaQuantity),
                                      onRemove: () =>
                                          setState(() => _gaQuantity--),
                                    ),
                                  if (_seats.isNotEmpty || _gaQuantity > 0) ...[
                                    const Divider(color: _divider),
                                    DefaultTextStyle.merge(
                                      style: const TextStyle(color: _muted),
                                      child: _TicketLine(
                                          label: 'Service fee',
                                          amount: money(fee)),
                                    ),
                                  ],
                                  if (_seats.isEmpty && _gaQuantity == 0)
                                    const Text('No tickets selected',
                                        style: TextStyle(color: _muted)),
                                ],
                              ),
                            ),
                            ColoredBox(
                              color: _totalBar,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 13),
                                child: DefaultTextStyle.merge(
                                  style: const TextStyle(
                                      color: _orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                  child: _TicketLine(
                                      label: 'Total',
                                      amount: money(subtotal + fee)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 29),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 37),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _seats.isEmpty && _gaQuantity == 0
                          ? null
                          : () => Navigator.pop(context, (
                                seatIds: _seatIds,
                                gaQuantity: _gaQuantity,
                                proceed: true,
                                pickAnotherSection: false
                              )),
                      child: const Text('Proceed to Payment'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 37),
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      onPressed: () => _editSelection(pickAnotherSection: true),
                      child: const Text('Add More Tickets'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventInfo extends StatelessWidget {
  const _EventInfo(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 12))),
        ],
      );
}

class _TicketLine extends StatelessWidget {
  const _TicketLine({required this.label, required this.amount, this.onRemove});
  final String label;
  final String amount;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: label == 'Total'
                        ? null
                        : const TextStyle(fontSize: 12))),
            const SizedBox(width: 12),
            Text(amount),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                tooltip: 'Remove one general admission ticket',
                icon: const Icon(Icons.remove_circle_outline),
              ),
          ],
        ),
      );
}

class _SeatBadge extends StatelessWidget {
  const _SeatBadge({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 55,
        height: 52,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: CustomPaint(
                size: const Size(43, 35),
                painter: _ChairPainter(),
              ),
            ),
            Positioned(
              left: 7,
              top: 19,
              width: 29,
              child: Text(label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF181E12),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Semantics(
                button: true,
                label: 'Remove seat $label',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: const SizedBox(
                    width: 28,
                    height: 25,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: Color(0xFFC83D42),
                        child: Icon(Icons.close, size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ChairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final green = Paint()..color = const Color(0xFFA3BD61);
    final outline = Paint()
      ..color = const Color(0xFF374525)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    void panel(double x, double y, double w, double h, double radius) {
      final shape = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      );
      canvas.drawRRect(shape, green);
      canvas.drawRRect(shape, outline);
    }

    panel(6, 1, 31, 23, 4);
    panel(6, 18, 31, 11, 2);
    canvas.drawRect(const Rect.fromLTWH(4, 28, 5, 6), green);
    canvas.drawRect(const Rect.fromLTWH(34, 28, 5, 6), green);
    panel(1, 12, 7, 19, 2);
    panel(35, 12, 7, 19, 2);
    canvas.drawRect(const Rect.fromLTWH(7, 27, 29, 4), green);
  }

  @override
  bool shouldRepaint(covariant _ChairPainter oldDelegate) => false;
}
