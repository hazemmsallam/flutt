import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/event_summary.dart';
import '../models/seat_map.dart';
import '../widgets/seat_map_view.dart';
import '../widgets/venue_3d_view.dart';
import 'booking_screen.dart';

class SeatMapScreen extends StatefulWidget {
  const SeatMapScreen({super.key, required this.event});
  final EventSummary event;

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  final _api = ApiClient();
  SeatMap? _map;
  Object? _error;
  final _selected = <int>{};
  Timer? _poll;
  bool _holding = false;
  bool _use3D = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Live refresh: the seat map is the endpoint the app polls for near real-time status.
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final map = await _api.seatMap(widget.event.id);
      if (!mounted) return;
      setState(() {
        _map = map;
        _error = null;
        // Drop any selections that were taken by someone else in the meantime.
        final live = {for (final s in map.seats) s.id: s};
        _selected.removeWhere((id) => live[id]?.selectable != true);
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() => _error = e);
    }
  }

  double get _total {
    final map = _map;
    if (map == null) return 0;
    final byId = {for (final s in map.seats) s.id: s};
    return _selected.fold(0.0, (sum, id) => sum + (byId[id]?.price ?? 0));
  }

  Future<void> _hold() async {
    if (_selected.isEmpty || _holding) return;
    setState(() => _holding = true);
    try {
      final booking = await _api.createBooking(widget.event.id, _selected.toList());
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookingScreen(bookingId: booking.id, initial: booking)),
      );
      _selected.clear();
      _load(silent: true);
    } on ApiException catch (e) {
      _snack(e.message);
      _load(silent: true); // someone likely grabbed a seat — refresh
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _holding = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toggleSeat(Seat seat) => setState(() {
        if (!_selected.add(seat.id)) _selected.remove(seat.id);
      });

  @override
  Widget build(BuildContext context) {
    final map = _map;
    return Scaffold(
      appBar: AppBar(title: Text(widget.event.name)),
      body: _error != null && map == null
          ? _errorBody()
          : map == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Row(
                        children: [
                          Expanded(child: Text('${map.hallName} · ${map.availableCount} available',
                              style: const TextStyle(color: Colors.black54))),
                          _ViewToggle(
                            use3D: _use3D,
                            onChanged: (v) => setState(() => _use3D = v),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh',
                            onPressed: () => _load(),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Align(alignment: Alignment.centerLeft, child: SeatLegend()),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: _use3D ? const Color(0xFF11151C) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: _use3D
                            ? Venue3DView(
                                map: map,
                                selectedIds: _selected,
                                onToggle: _toggleSeat,
                              )
                            : SeatMapView(
                                map: map,
                                selectedIds: _selected,
                                onToggle: _toggleSeat,
                              ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: map == null ? null : _bottomBar(),
    );
  }

  Widget _bottomBar() {
    final count = _selected.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(count == 0 ? 'No seats selected' : '$count seat${count == 1 ? '' : 's'} selected',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (count > 0)
                    Text('Total \$${_total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            FilledButton(
              onPressed: count == 0 || _holding ? null : _hold,
              child: _holding
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(count == 0 ? 'Select seats' : 'Hold $count seat${count == 1 ? '' : 's'}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBody() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => _load(), child: const Text('Retry')),
            ],
          ),
        ),
      );
}

/// Small segmented control to switch between the 3D venue and the flat 2D map.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.use3D, required this.onChanged});

  final bool use3D;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: true, label: Text('3D'), icon: Icon(Icons.view_in_ar, size: 16)),
        ButtonSegment(value: false, label: Text('2D'), icon: Icon(Icons.grid_view, size: 16)),
      ],
      selected: {use3D},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
