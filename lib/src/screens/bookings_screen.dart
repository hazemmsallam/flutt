import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/booking.dart';
import 'booking_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _api = ApiClient();
  late Future<List<Booking>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.myBookings();
  }

  void _reload() => setState(() => _future = _api.myBookings());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Booking>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                const SizedBox(height: 100),
                Center(child: Text('${snap.error}')),
              ]);
            }
            final bookings = snap.data ?? const [];
            if (bookings.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('No bookings yet.')),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final b = bookings[i];
                final labels = b.seats.map((s) => s.label).join(', ');
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(b.eventName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${b.status} · ${b.quantity} seat(s)'
                        '${labels.isEmpty ? '' : ' · $labels'}\n\$${b.totalAmount.toStringAsFixed(2)}'),
                    isThreeLine: true,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BookingScreen(bookingId: b.id, initial: b)),
                      );
                      _reload();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
