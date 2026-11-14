import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/event_summary.dart';
import '../models/seat_map.dart';
import '../widgets/seat_map_view.dart';
import '../widgets/section_map_view.dart';
import '../models/booking.dart';
import 'payment_confirmation_screen.dart';
import 'payment_methods_screen.dart';
import 'ticket_review_screen.dart';
import '../theme/app_theme.dart';

class SeatMapScreen extends StatefulWidget {
  const SeatMapScreen({super.key, required this.event, this.initialSectionId});
  final EventSummary event;

  /// When set, the screen opens directly on this section's seat picker so a
  /// customer who already tapped a section on the detail screen is not asked
  /// to pick one again.
  final int? initialSectionId;

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
  bool _reviewing = false;

  // A seated selection and one general-admission section can share a booking.
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
    _poll =
        Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
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
      // First successful load: honour initialSectionId. If the deep-linked
      // section is GA, open its quantity sheet instead of a seat picker.
      VenueSection? openGa;
      if (_map == null && widget.initialSectionId != null) {
        final s = map.sectionById(widget.initialSectionId);
        if (s != null) {
          if (s.isGeneralAdmission) {
            openGa = s;
          } else {
            _focusedSectionId = s.id;
          }
        }
      }
      setState(() {
        _map = map;
        _error = null;
        // Drop any selections that were taken by someone else in the meantime.
        final live = {for (final s in map.seats) s.id: s};
        if (_reviewing) return;
        _selected.removeWhere((id) => live[id]?.selectable != true);
        // Drop a GA selection whose section vanished or sold out.
        final section = map.sectionById(_gaSectionId);
        if (section == null || !section.gaSelectable) {
          _gaSectionId = null;
        } else if (_gaQty > section.available) {
          _gaQty = section.available;
        }
        // If the admin deleted the section we were browsing, fall back to the overview.
        if (_focusedSectionId != null &&
            map.sectionById(_focusedSectionId) == null) {
          _focusedSectionId = null;
        }
      });
      if (openGa != null) _askQuantity(openGa);
    } catch (e) {
      if (!mounted || silent) return;
      setState(() => _error = e);
    }
  }

  double get _total {
    final map = _map;
    if (map == null) return 0;
    final section = map.sectionById(_gaSectionId);
    final byId = {for (final s in map.seats) s.id: s};
    return _selected.fold(
            0.0,
            (sum, id) =>
                sum +
                (byId[id] == null
                    ? 0.0
                    : byId[id]!.price +
                        (map
                                .sectionById(byId[id]!.sectionId)
                                ?.serviceFeePerTicket ??
                            1))) +
        (section == null
            ? 0
            : ((section.price ?? 0) + section.serviceFeePerTicket) * _gaQty);
  }

  VenueSection? get _gaSection => _map?.sectionById(_gaSectionId);

  Future<void> _reviewTickets() async {
    final map = _map;
    final ga = _gaSection;
    if (map == null || _holding || _reviewing) return;
    final seats =
        map.seats.where((seat) => _selected.contains(seat.id)).toList();
    if (seats.isEmpty && ga == null) return;
    if (seats.length + (ga == null ? 0 : _gaQty) > 10) {
      _snack('Choose up to 10 tickets per booking.');
      return;
    }
    _reviewing = true;
    final result = await Navigator.push<
        ({
          List<int> seatIds,
          int gaQuantity,
          bool proceed,
          bool pickAnotherSection
        })>(
      context,
      MaterialPageRoute(
        builder: (_) => TicketReviewScreen(
          event: widget.event,
          seats: seats,
          seatSections: {
            for (final section in map.sections) section.id: section
          },
          gaSection: ga,
          gaQuantity: ga == null ? 0 : _gaQty,
        ),
      ),
    );
    if (!mounted) return;
    _reviewing = false;
    if (result == null) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(result.seatIds);
      _gaSectionId = result.gaQuantity > 0 ? ga?.id : null;
      _gaQty = result.gaQuantity > 0 ? result.gaQuantity : 1;
      if (result.pickAnotherSection) _focusedSectionId = null;
    });
    if (result.proceed) {
      await _hold(result.gaQuantity > 0 ? ga : null);
    } else {
      await _load(silent: true);
    }
  }

  Future<void> _hold(VenueSection? section) async {
    if (_holding) return;
    if (_selected.isEmpty && section == null) return;
    if (_selected.length + (section == null ? 0 : _gaQty) > 10) {
      _snack('Choose up to 10 tickets per booking.');
      return;
    }
    setState(() => _holding = true);
    try {
      final booking = await _api.createBooking(
          widget.event.id, _selected.toList(),
          generalAdmission: section == null ? const {} : {section.id: _gaQty});
      if (!mounted) return;
      final paid = await Navigator.push<Booking>(
        context,
        MaterialPageRoute(
            builder: (_) => PaymentMethodsScreen(booking: booking)),
      );
      if (!mounted) return;
      if (paid != null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) => PaymentConfirmationScreen(booking: paid)),
        );
        if (!mounted) return;
      }
      setState(() {
        _selected.clear();
        _gaSectionId = null;
        _gaQty = 1;
      });
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
      setState(() => _focusedSectionId = section.id);
    }
  }

  void _exitSection() {
    setState(() => _focusedSectionId = null);
  }

  /// Quantity sheet for a general-admission section — the GA equivalent of picking seats.
  Future<void> _askQuantity(VenueSection section) async {
    final qty = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => _QuantitySheet(section: section),
    );
    if (qty == null || !mounted) return;
    setState(() {
      _gaSectionId = section.id;
      _gaQty = qty;
    });
  }

  VenueSection? get _focused => _map?.sectionById(_focusedSectionId);

  @override
  Widget build(BuildContext context) {
    final map = _map;
    final focused = _focused;

    if (_error != null && map == null) {
      return Scaffold(appBar: AppBar(), body: _errorBody());
    }
    if (map == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Section-detail screen matches the Figma: dark background, big section name,
    // minimap, chunky grid, selected-seat chips, Total Due card.
    if (focused != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exitSection();
        },
        child: _buildFocusedView(map, focused),
      );
    }
    return _buildOverviewView(map);
  }

  Widget _buildOverviewView(SeatMap map) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.event.name), actions: [
        IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _load()),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${map.hallName} · tap a section to begin',
                  style: const TextStyle(color: AppColors.muted))),
        ),
        _gaSectionsBar(map),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SectionMapView(
              map: map,
              onSectionTap: _onSectionTap,
              selectedSectionId: _gaSectionId,
            ),
          ),
        ),
      ]),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _buildFocusedView(SeatMap map, VenueSection focused) {
    final seats = map.seats.where((s) => s.sectionId == focused.id).toList();
    final byId = {for (final s in seats) s.id: s};
    final selectedSeats = _selected
        .map((id) => byId[id])
        .whereType<Seat>()
        .toList(growable: false);
    final currency =
        selectedSeats.isNotEmpty ? 'JOD' : (focused.currency ?? 'JOD');
    return Scaffold(
      backgroundColor: AppColors.ticketBackground,
      body: SafeArea(
        child: Column(children: [
          _focusedHeader(focused),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SeatMapView(
                key: ValueKey(focused.id),
                seats: seats,
                section: focused,
                selectedIds: Set.of(_selected),
                onToggle: _toggleSeat,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (selectedSeats.isNotEmpty)
            _SelectedSeatsRow(seats: selectedSeats, onRemove: _toggleSeat),
          _TotalAndBuyCard(
            total: _total,
            currency: currency,
            canBuy: !_holding && (_selected.isNotEmpty || _gaSection != null),
            busy: _holding,
            onBuy: _reviewTickets,
          ),
        ]),
      ),
    );
  }

  Widget _focusedHeader(VenueSection focused) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
            onPressed: _exitSection,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(focused.name,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
              const SizedBox(height: 14),
              const Text('Select your seat',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text(
                'Pinch to zoom to explore the seating map and tap an '
                'available seat to select it.',
                style: TextStyle(
                    color: Colors.white, fontSize: 13.5, height: 1.35),
              ),
            ]),
          ),
        ]),
      ),
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
          final priceText = s.price == null
              ? ''
              : ' · ${s.price!.toStringAsFixed(2)} ${s.currency ?? ''}';
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
    final count = _selected.length + (_gaSection == null ? 0 : _gaQty);
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
                  Text(
                      count == 0
                          ? 'Select seats or a section'
                          : '$count ticket${count == 1 ? '' : 's'} selected',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (count > 0)
                    Text(
                        'Total ${_total.toStringAsFixed(2)} ${_gaSection?.currency ?? 'JOD'}',
                        style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
            FilledButton(
              onPressed: count == 0 || _holding ? null : _reviewTickets,
              child: _holding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(count == 0 ? 'Select tickets' : 'Continue'),
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
              FilledButton(
                  onPressed: () => _load(), child: const Text('Retry')),
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
            Text(s.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              s.price == null
                  ? 'Standing · $max available'
                  : '${unit.toStringAsFixed(2)} $currency each · $max available',
              style: const TextStyle(color: AppColors.muted),
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
                    style: const TextStyle(
                        fontSize: 34, fontWeight: FontWeight.w800),
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
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton(
                  onPressed:
                      max < 1 ? null : () => Navigator.pop(context, _qty),
                  child: Text('Add $_qty ticket${_qty == 1 ? '' : 's'}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chair icons for the current selection, each with an X to drop it — matches
/// the "A12 / A13 / A14" row in the Figma.
class _SelectedSeatsRow extends StatelessWidget {
  const _SelectedSeatsRow({required this.seats, required this.onRemove});
  final List<Seat> seats;
  final ValueChanged<Seat> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: seats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final seat = seats[i];
          return SizedBox(
            width: 68,
            child: Stack(clipBehavior: Clip.none, children: [
              Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.chair, size: 48, color: Color(0xFF8DBE4A)),
                const SizedBox(height: 2),
                Text(seat.label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              Positioned(
                top: 0,
                right: 2,
                child: GestureDetector(
                  onTap: () => onRemove(seat),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFFE05252)),
                    child:
                        const Icon(Icons.close, size: 15, color: Colors.white),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _TotalAndBuyCard extends StatelessWidget {
  const _TotalAndBuyCard({
    required this.total,
    required this.currency,
    required this.canBuy,
    required this.busy,
    required this.onBuy,
  });

  final double total;
  final String currency;
  final bool canBuy;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        Expanded(
          child: Text(
            'Total Due · ${total.toStringAsFixed(2)} $currency',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: canBuy ? onBuy : null,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Buy Tickets'),
        ),
      ]),
    );
  }
}
