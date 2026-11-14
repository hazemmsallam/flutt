import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/booking.dart';
import '../theme/app_theme.dart';
import '../widgets/event_countdown_banner.dart';
import 'booking_screen.dart';
import 'events_screen.dart';

const _cardColor = Color(0xFF262626);
const _outline = Color(0xFF505050);

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _api = ApiClient();
  late Future<List<Booking>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _api.myBookings();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = _api.myBookings();
    setState(() => _future = request);
    try {
      await request;
    } catch (_) {
      // FutureBuilder displays the error.
    }
  }

  Future<void> _open(Booking booking) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(bookingId: booking.id, initial: booking),
      ),
    );
    if (mounted) await _reload();
  }

  bool _matches(Booking booking) {
    return [
      booking.eventName,
      booking.hallName ?? '',
      ...booking.tickets.map((ticket) => ticket.number),
    ].any((text) => text.toLowerCase().contains(_query));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ticketBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: BackButton(onPressed: () => Navigator.maybePop(context)),
              ),
              const Text('My Tickets',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
              const SizedBox(height: 22),
              TextField(
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search Now',
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  filled: false,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF828282)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF828282)),
                  ),
                ),
              ),
              FutureBuilder<List<Booking>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Text('Couldn’t load your tickets.'),
                          TextButton(
                              onPressed: _reload, child: const Text('Retry')),
                        ],
                      ),
                    );
                  }
                  final now = DateTime.now();
                  final bookings = (snapshot.data ?? []).where(_matches);
                  if (bookings.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Center(
                        child: Text(_query.isEmpty
                            ? 'No bookings yet.'
                            : 'No matching bookings.'),
                      ),
                    );
                  }
                  final upcoming = bookings
                      .where((booking) => booking.isUpcoming(now))
                      .toList()
                    ..sort(
                        (a, b) => a.eventStartAt!.compareTo(b.eventStartAt!));
                  final groups = {
                    'Upcoming': upcoming,
                    'Past': bookings.where((booking) =>
                        booking.isConfirmed &&
                        booking.eventStartAt != null &&
                        !booking.isUpcoming(now)),
                    'Pending Payment':
                        bookings.where((booking) => booking.isPending),
                    'Other Bookings': bookings.where((booking) =>
                        !booking.isPending &&
                        (!booking.isConfirmed || booking.eventStartAt == null)),
                  };
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final group in groups.entries)
                        if (group.value.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(group.key,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          for (final booking in group.value)
                            Padding(
                              key: ValueKey(booking.id),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _BookingCard(
                                booking: booking,
                                showCountdown: booking.isUpcoming(now),
                                onStarted: () => setState(() {}),
                                onTap: () => _open(booking),
                              ),
                            ),
                        ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.showCountdown,
    required this.onStarted,
    required this.onTap,
  });

  final Booking booking;
  final bool showCountdown;
  final VoidCallback onStarted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = booking.eventStartAt;
    final venue = booking.hallName;
    final location = [
      if (venue != null && venue.isNotEmpty) venue,
      if (date != null) DateFormat('d MMM yyyy').format(date),
    ].join(' - ');
    final unit = booking.generalAdmission.isNotEmpty ? 'Ticket' : 'Seat';
    return Material(
      color: _cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 7),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: EventPoster(imageUrl: booking.eventImageUrl),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking.eventName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          booking.isConfirmed
                              ? '${booking.quantity} $unit${booking.quantity == 1 ? '' : 's'}'
                              : booking.status.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 1,
              child: CustomPaint(painter: _PerforationPainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 11, 22, 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(location,
                        style: const TextStyle(
                            color: Color(0xFFA7A7A7), fontSize: 12)),
                  ),
                  const Icon(Icons.chevron_right, size: 19),
                ],
              ),
            ),
            if (showCountdown && date != null)
              EventCountdownBanner(startAt: date, onStarted: onStarted),
          ],
        ),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()..color = _outline;
    final background = Paint()..color = AppColors.ticketBackground;
    for (var x = 14.0; x < size.width - 14; x += 10) {
      canvas.drawLine(Offset(x, 0), Offset(x + 5, 0), outline);
    }
    for (final x in [0.0, size.width]) {
      canvas.drawCircle(Offset(x, 0), 13, outline);
      canvas.drawCircle(Offset(x, 0), 12, background);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter oldDelegate) => false;
}
