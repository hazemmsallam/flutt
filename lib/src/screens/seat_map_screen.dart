import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/event_summary.dart';
import '../models/seat_map.dart';
import '../widgets/seat_map_view.dart';
import '../widgets/section_map_view.dart';
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

  // General-admission selection (mutually exclusive with seat selection).
  int? _gaSectionId;
  int _gaQty = 1;

  /// The seated section the customer drilled into, if any. Null means we're showing the
  /// section overview — the customer picks an area before they pick a seat.
  int? _focusedSectionId;

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
        // Drop a GA selection whose section vanished or sold out.
        final section = map.sectionById(_gaSectionId);
        if (section == null || !section.gaSelectable) {
          _gaSectionId = null;
        } else if (_gaQty > section.available) {
          _gaQty = section.available;
        }
        // If the admin deleted the section we were browsing, fall back to the overview.
        if (_focusedSectionId != null && map.sectionById(_focusedSectionId) == null) {
          _focusedSectionId = null;
        }
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() => _error = e);
    }
  }

  double get _total {
    final map = _map;
    if (map == null) return 0;
    final section = map.sectionById(_gaSectionId);
    if (section != null) {
      return (section.price ?? 0) * _gaQty;
    }
    final byId = {for (final s in map.seats) s.id: s};
    return _selected.fold(0.0, (sum, id) => sum + (byId[id]?.price ?? 0));
  }

  VenueSection? get _gaSection => _map?.sectionById(_gaSectionId);

  Future<void> _hold() async {
    if (_holding) return;
    final section = _gaSection;
    if (section != null) {
      await _holdGa(section);
      return;
    }
    if (_selected.isEmpty) return;
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

  Future<void> _holdGa(VenueSection section) async {
    setState(() => _holding = true);
    try {
      final booking =
          await _api.createSectionBooking(widget.event.id, section.id, _gaQty);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookingScreen(bookingId: booking.id, initial: booking)),
      );
      setState(() {
        _gaSectionId = null;
        _gaQty = 1;
      });
      _load(silent: true);
    } on ApiException catch (e) {
      _snack(e.message);
      _load(silent: true);
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
        _gaSectionId = null; // seats and a GA section can't be selected together
        if (!_selected.add(seat.id)) _selected.remove(seat.id);
      });

  void _selectSection(VenueSection section) => setState(() {
        _selected.clear();
        if (_gaSectionId == section.id) {
          _gaSectionId = null;
        } else {
          _gaSectionId = section.id;
          _gaQty = section.available > 0 ? 1 : 0;
        }
      });

  /// A tap on a section in the overview. What it means depends entirely on how the admin
  /// configured that section: seated areas open their seats, general-admission areas ask
  /// how many tickets you want.
  void _onSectionTap(VenueSection section) {
    if (section.available <= 0) {
      _snack('${section.name} is sold out.');
      return;
    }
    if (section.isGeneralAdmission) {
      _askQuantity(section);
    } else {
      setState(() {
        _gaSectionId = null;
        _focusedSectionId = section.id;
      });
    }
  }

  void _exitSection() => setState(() {
        _focusedSectionId = null;
        _selected.clear();
      });

  /// Quantity sheet for a general-admission section — the GA equivalent of picking seats.
  Future<void> _askQuantity(VenueSection section) async {
    final qty = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => _QuantitySheet(section: section),
    );
    if (qty == null || !mounted) return;
    setState(() {
      _selected.clear();
      _gaSectionId = section.id;
      _gaQty = qty;
    });
    await _hold();
  }

  VenueSection? get _focused => _map?.sectionById(_focusedSectionId);

  @override
  Widget build(BuildContext context) {
    final map = _map;
    final focused = _focused;

    return Scaffold(
      appBar: AppBar(
        title: Text(focused?.name ?? widget.event.name),
        leading: focused == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'All sections',
                onPressed: _exitSection,
              ),
      ),
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
                          Expanded(
                            child: Text(
                              focused == null
                                  ? '${map.hallName} · tap a section to begin'
                                  : '${focused.name} · ${focused.available} seats available',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
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
                    // The seat legend only means anything once seats are on screen.
                    if (focused != null || _use3D)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Align(alignment: Alignment.centerLeft, child: SeatLegend()),
                      ),
                    // Chips are a fallback for GA sections the admin never drew a boundary
                    // for — without them those sections would be unreachable on the map.
                    if (focused == null) _gaSectionsBar(map),
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
                                selectedSectionId: _gaSectionId,
                                onSectionTap: _selectSection,
                              )
                            : focused == null
                                ? SectionMapView(
                                    map: map,
                                    onSectionTap: _onSectionTap,
                                    selectedSectionId: _gaSectionId,
                                  )
                                : SeatMapView(
                                    map: map,
                                    selectedIds: _selected,
                                    onToggle: _toggleSeat,
                                    focus: focused,
                                  ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: map == null ? null : _bottomBar(),
    );
  }

  /// A horizontal row of the hall's general-admission sections (view-independent), so GA is
  /// always reachable even in the 2D map. Tapping a chip selects the section.
  Widget _gaSectionsBar(SeatMap map) {
    final ga = map.sections.where((s) => s.isGeneralAdmission).toList();
    if (ga.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        itemCount: ga.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = ga[i];
          final selected = s.id == _gaSectionId;
          final priceText = s.price == null ? '' : ' · ${s.price!.toStringAsFixed(2)} ${s.currency ?? ''}';
          return ChoiceChip(
            selected: selected,
            onSelected: s.gaSelectable ? (_) => _onSectionTap(s) : null,
            label: Text(
              '${s.name}$priceText · ${s.available > 0 ? '${s.available} left' : 'Sold out'}',
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }

  Widget _bottomBar() {
    final section = _gaSection;
    if (section != null) {
      return _gaBottomBar(section);
    }
    // In the overview there is nothing to total up yet — say what to do instead.
    if (_focusedSectionId == null && !_use3D) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Text(
            'Tap a section to choose seats or tickets',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
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

  Widget _gaBottomBar(VenueSection section) {
    final currency = section.currency ?? '';
    final canDecrement = _gaQty > 1;
    final canIncrement = _gaQty < section.available;
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
                  Text(section.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Total ${_total.toStringAsFixed(2)} $currency',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: canDecrement ? () => setState(() => _gaQty--) : null,
            ),
            Text('$_gaQty', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: canIncrement ? () => setState(() => _gaQty++) : null,
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _gaQty < 1 || _holding ? null : _hold,
              child: _holding
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Hold $_gaQty'),
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

/// Asks how many tickets to buy in a general-admission section — the GA counterpart to
/// picking seats. Capped at what is actually left, so the customer can't compose a request
/// the server will only reject.
class _QuantitySheet extends StatefulWidget {
  const _QuantitySheet({required this.section});
  final VenueSection section;

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    final currency = s.currency ?? '';
    final unit = s.price ?? 0;
    final max = s.available;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              s.price == null
                  ? 'Standing · $max available'
                  : '${unit.toStringAsFixed(2)} $currency each · $max available',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  iconSize: 28,
                  icon: const Icon(Icons.remove),
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    '$_qty',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton.filledTonal(
                  iconSize: 28,
                  icon: const Icon(Icons.add),
                  onPressed: _qty < max ? () => setState(() => _qty++) : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total ${(unit * _qty).toStringAsFixed(2)} $currency',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton(
                  onPressed: max < 1 ? null : () => Navigator.pop(context, _qty),
                  child: Text('Hold $_qty ticket${_qty == 1 ? '' : 's'}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
