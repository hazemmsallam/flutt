import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/booking.dart';
import '../widgets/countdown.dart';

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

  @override
  void initState() {
    super.initState();
    _booking = widget.initial;
    if (_booking == null) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final b = await _api.getBooking(widget.bookingId);
      if (mounted) setState(() => _booking = b);
    } catch (_) {/* keep whatever we have */}
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      final result = await _api.pay(widget.bookingId);
      _snack(result.success ? 'Payment confirmed' : (result.message ?? 'Payment failed'));
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await _api.cancel(widget.bookingId);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    return Scaffold(
      appBar: AppBar(title: const Text('Your booking')),
      body: b == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(b.eventName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _StatusChip(status: b.status, expiresAt: b.expiresAt, onExpired: _refresh),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      for (final s in b.seats)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.event_seat, size: 20),
                          title: Text('${s.label}  ·  ${s.seatType}'),
                          trailing: Text('\$${s.price.toStringAsFixed(2)}'),
                        ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                        trailing: Text('\$${b.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                if (b.paymentRef != null) ...[
                  const SizedBox(height: 8),
                  Text('Payment ref: ${b.paymentRef}', style: const TextStyle(color: Colors.black54)),
                ],
                const SizedBox(height: 20),
                if (b.isPending) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : _pay,
                    icon: const Icon(Icons.payment),
                    label: const Text('Pay now'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : _cancel,
                    child: const Text('Cancel hold'),
                  ),
                ] else if (b.isConfirmed)
                  const Card(
                    color: Color(0xFFE7F6EC),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(children: [
                        Icon(Icons.check_circle, color: Color(0xFF1C7A43)),
                        SizedBox(width: 10),
                        Text('Confirmed — enjoy the show!', style: TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
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
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        if (status == 'PENDING' && expiresAt != null)
          Countdown(expiresAt: expiresAt!, onExpired: onExpired, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}
