import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/booking.dart';
import '../widgets/admission_ticket_card.dart';
import '../widgets/countdown.dart';
import '../widgets/event_countdown_banner.dart';
import '../theme/app_theme.dart';
import 'events_screen.dart';
import 'payment_methods_screen.dart';
import 'payment_confirmation_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.bookingId, this.initial});
  final int bookingId;
  final Booking? initial;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _api = ApiClient();
  Booking? _booking;
  bool _busy = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.initial;
    if (_booking == null) _refresh();
  }

  Future<void> _refresh() async {
    if (_loadFailed) setState(() => _loadFailed = false);
    try {
      final b = await _api.getBooking(widget.bookingId);
      if (mounted) setState(() => _booking = b);
    } catch (_) {
      if (mounted && _booking == null) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _choosePayment(Booking booking) async {
    final paid = await Navigator.push<Booking>(
      context,
      MaterialPageRoute(builder: (_) => PaymentMethodsScreen(booking: booking)),
    );
    if (!mounted || paid == null) return;
    setState(() => _booking = paid);
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentConfirmationScreen(booking: paid),
        ));
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await _api.cancel(widget.bookingId);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    if (b?.isConfirmed == true) return _PurchasedBookingDetails(booking: b!);
    return Scaffold(
      appBar: AppBar(title: const Text('Your tickets')),
      body: b == null
          ? Center(
              child: _loadFailed
                  ? TextButton(
                      onPressed: _refresh, child: const Text('Retry booking'))
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(b.eventName,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                _StatusChip(
                    status: b.status,
                    expiresAt: b.expiresAt,
                    onExpired: _refresh),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      for (final s in b.seats)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.event_seat, size: 20),
                          title: Text('${s.sectionName} · ${s.label}'),
                          trailing: Text(
                              '${s.price.toStringAsFixed(2)} ${s.currency}'),
                        ),
                      for (final ga in b.generalAdmission)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.groups_outlined, size: 20),
                          title: Text(ga.sectionName),
                          subtitle: Text(
                              '${ga.quantity} general admission ticket${ga.quantity == 1 ? '' : 's'}'),
                          trailing: Text(
                              '${ga.totalAmount.toStringAsFixed(2)} ${ga.currency}'),
                        ),
                      if (b.serviceFee > 0)
                        ListTile(
                          dense: true,
                          title: const Text('Service fee'),
                          trailing: Text(
                              '${b.serviceFee.toStringAsFixed(2)} ${b.currency}'),
                        ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Total',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        trailing: Text(
                            '${b.totalAmount.toStringAsFixed(2)} ${b.currency}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                if (b.paymentRef != null) ...[
                  const SizedBox(height: 8),
                  Text('Payment ref: ${b.paymentRef}',
                      style: const TextStyle(color: AppColors.muted)),
                ],
                const SizedBox(height: 20),
                if (b.isPending) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _choosePayment(b),
                    icon: const Icon(Icons.payment),
                    label: const Text('Proceed to Payment'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : _cancel,
                    child: const Text('Cancel hold'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PurchasedBookingDetails extends StatelessWidget {
  const _PurchasedBookingDetails({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final date = booking.eventStartAt;
    final venue = booking.hallName;
    return Scaffold(
      backgroundColor: AppColors.ticketBackground,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(
              height: 196,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EventPoster(imageUrl: booking.eventImageUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, .6],
                        colors: [
                          AppColors.ticketBackground,
                          Colors.transparent
                        ],
                      ),
                    ),
                  ),
                  const Positioned(top: 2, left: 4, child: BackButton()),
                ],
              ),
            ),
            if (date != null && booking.isUpcoming(DateTime.now()))
              EventCountdownBanner(startAt: date),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 21, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(booking.eventName,
                      style: const TextStyle(
                          fontSize: 23, fontWeight: FontWeight.w700)),
                  if (date != null || (venue != null && venue.isNotEmpty)) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (date != null)
                          _EventMetadata(
                            icon: Icons.calendar_today_outlined,
                            text: DateFormat('d MMMM  -  h:mm a').format(date),
                          ),
                        if (venue != null && venue.isNotEmpty)
                          _EventMetadata(
                              icon: Icons.location_on_outlined, text: venue),
                      ],
                    ),
                  ],
                  const SizedBox(height: 30),
                  const Text('Ticket Numbers:',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (booking.tickets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                          'Ticket numbers are unavailable for this booking.',
                          style: TextStyle(color: AppColors.muted)),
                    ),
                  for (final ticket in booking.tickets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child:
                          AdmissionTicketCard(ticket: ticket, booking: booking),
                    ),
                  const SizedBox(height: 5),
                  const Text('Payment Details',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  _PaymentDetails(booking: booking),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventMetadata extends StatelessWidget {
  const _EventMetadata({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Icon(icon, size: 15),
          ),
        ),
        TextSpan(text: text),
      ]),
      style: const TextStyle(fontSize: 12, color: Color(0xFFE4E4E4)),
    );
  }
}

class _PaymentDetails extends StatelessWidget {
  const _PaymentDetails({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final sections = <Object, ({String name, int quantity, double amount})>{};
    void addLine(int? id, String name, int quantity, double amount) {
      final key = id ?? name;
      final previous = sections[key];
      sections[key] = (
        name: name,
        quantity: (previous?.quantity ?? 0) + quantity,
        amount: (previous?.amount ?? 0) + amount,
      );
    }

    for (final seat in booking.seats) {
      addLine(seat.sectionId,
          seat.sectionName.isEmpty ? 'Seats' : seat.sectionName, 1, seat.price);
    }
    for (final admission in booking.generalAdmission) {
      addLine(
          admission.sectionId,
          admission.sectionName.isEmpty
              ? 'General admission'
              : admission.sectionName,
          admission.quantity,
          admission.totalAmount);
    }
    String money(double amount) =>
        '${amount.toStringAsFixed(2)} ${booking.currency}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: const Color(0xFF262626),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final line in sections.values)
                    _AmountRow(
                      label: '${line.name}  ·  ×${line.quantity}',
                      amount: money(line.amount),
                    ),
                  if (sections.isNotEmpty)
                    const Divider(height: 1, color: Color(0xFF343434)),
                  _AmountRow(
                    label: 'Service Fee',
                    amount: money(booking.serviceFee),
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
            ColoredBox(
              color: const Color(0xFF424244),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AmountRow(
                  label: 'Total',
                  amount: money(booking.totalAmount),
                  color: const Color(0xFFFF7500),
                  isTotal: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.color = Colors.white,
    this.isTotal = false,
  });

  final String label;
  final String amount;
  final Color color;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
      fontSize: isTotal ? 15 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(amount, style: style),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.expiresAt, this.onExpired});
  final String status;
  final DateTime? expiresAt;
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (status) {
      case 'CONFIRMED':
        bg = const Color(0xFF1C7A43);
        break;
      case 'PENDING_PAYMENT':
      case 'PENDING':
        bg = const Color(0xFF96650A);
        break;
      default:
        bg = const Color(0xFFB3261E);
    }
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(999)),
          child: Text(status,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        if ((status == 'PENDING_PAYMENT' || status == 'PENDING') &&
            expiresAt != null)
          Countdown(
              expiresAt: expiresAt!,
              onExpired: onExpired,
              style: const TextStyle(color: AppColors.muted)),
      ],
    );
  }
}
