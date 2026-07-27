import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/event_summary.dart';
import 'bookings_screen.dart';
import 'seat_map_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _api = ApiClient();
  late Future<List<EventSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.availableEvents();
  }

  void _reload() => setState(() => _future = _api.availableEvents());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined),
            tooltip: 'My bookings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<EventSummary>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorView(message: '${snap.error}', onRetry: _reload);
            }
            final events = snap.data ?? const [];
            if (events.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('No events available right now.')),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _EventCard(event: events[i]),
            );
          },
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final when = event.startAt != null
        ? DateFormat('EEE d MMM • HH:mm').format(event.startAt!)
        : 'Date TBA';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(event.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$when\n${event.hallName} · ${event.seated ? 'Seated' : 'General admission'}'),
        isThreeLine: true,
        trailing: event.seated ? const Icon(Icons.event_seat) : const Icon(Icons.groups),
        // Every event opens the venue view now: a hall may have seated and/or
        // general-admission sections, and the screen adapts per section.
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SeatMapScreen(event: event)),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(message, textAlign: TextAlign.center))),
        const SizedBox(height: 12),
        Center(child: FilledButton(onPressed: onRetry, child: const Text('Retry'))),
      ],
    );
  }
}
