import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/event_detail.dart';
import '../models/event_summary.dart';
import '../models/seat_map.dart';
import '../theme/app_theme.dart';
import '../widgets/section_map_view.dart';
import 'events_screen.dart';
import 'seat_map_screen.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.event});
  final EventSummary event;
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _api = ApiClient();
  late final Future<EventDetail> _detail = _api.eventDetail(widget.event.id);
  late final Future<SeatMap> _seatMap = _api.seatMap(widget.event.id);
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final soldOut = event.status == 'SOLD_OUT';
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _Hero(event: event)),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28))),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.name,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.15)),
                      const SizedBox(height: 14),
                      _MetaRow(event: event),
                      const SizedBox(height: 22),
                      FutureBuilder<EventDetail>(
                          future: _detail,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Text(
                                  snapshot.hasError
                                      ? 'Event details are unavailable.'
                                      : 'Loading details…',
                                  style:
                                      const TextStyle(color: AppColors.muted));
                            }
                            final detail = snapshot.data!;
                            final description = detail.description.isEmpty
                                ? 'More details coming soon.'
                                : detail.description;
                            return _About(
                              text: description,
                              expanded: _expanded,
                              onToggle: () =>
                                  setState(() => _expanded = !_expanded),
                              pricing: detail.pricing,
                              seatMap: _seatMap,
                              onPickSeats: ({int? sectionId}) =>
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => SeatMapScreen(
                                              event: event,
                                              initialSectionId: sectionId))),
                            );
                          }),
                    ]),
              ),
            ),
          ),
        ]),
        Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white,
                    iconSize: 24,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.local_activity_outlined),
                    color: Colors.white,
                    iconSize: 24,
                    onPressed: () {},
                  ),
                ])),
      ]),
      bottomNavigationBar: SafeArea(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: FilledButton(
          onPressed: soldOut
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SeatMapScreen(event: event))),
          child: Text(soldOut ? 'Sold out' : 'Select tickets'),
        ),
      )),
    );
  }

}

/// Hero poster with tagline + category pill overlaid, matching the Figma detail header.
class _Hero extends StatelessWidget {
  const _Hero({required this.event});
  final EventSummary event;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 420,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          EventPoster(imageUrl: event.imageUrl),
          const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                Color(0x66000000),
                Colors.transparent,
                Color(0xDD101113),
              ],
                      stops: [
                0.0,
                0.35,
                1.0
              ]))),
          Positioned(
              left: 20,
              top: 76,
              right: 20,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (event.tagline?.isNotEmpty == true) ...[
                      Text(event.tagline!.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              letterSpacing: 6,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                    ],
                  ])),
          Positioned(
              left: 20,
              right: 20,
              bottom: 70,
              child: Text(event.name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 54,
                      height: 0.95,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(blurRadius: 18, color: Colors.black54)
                      ]))),
          Positioned(
              left: 20,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(event.category ?? 'Events',
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              )),
          Positioned(
              right: 20,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(26)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.ios_share, size: 20, color: Colors.black),
                  SizedBox(width: 14),
                  Icon(Icons.location_on, size: 20, color: Colors.black),
                ]),
              )),
        ]),
      );
}

/// Date-time and venue, side by side like the Figma meta row.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.event});
  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final date = event.startAt == null
        ? 'Date TBA'
        : DateFormat('d MMMM • h:mm a').format(event.startAt!);
    final venueLine = event.hallAddress?.isNotEmpty == true
        ? '${event.hallName} · ${event.hallAddress}'
        : event.hallName;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const Icon(Icons.calendar_today_outlined,
          size: 16, color: AppColors.orange),
      const SizedBox(width: 6),
      Flexible(
          child: Text(date,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.muted, fontWeight: FontWeight.w600))),
      const SizedBox(width: 14),
      const Icon(Icons.location_on_outlined,
          size: 16, color: AppColors.orange),
      const SizedBox(width: 6),
      Flexible(
          child: Text(venueLine,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.muted, fontWeight: FontWeight.w600))),
    ]);
  }
}

/// Description with "More details" / "Show less" toggle plus the pricing list.
class _About extends StatelessWidget {
  const _About({
    required this.text,
    required this.expanded,
    required this.onToggle,
    required this.pricing,
    required this.seatMap,
    required this.onPickSeats,
  });
  final String text;
  final bool expanded;
  final VoidCallback onToggle;
  final List<EventPrice> pricing;
  final Future<SeatMap> seatMap;
  // Opens the seat picker. When sectionId is set the picker opens straight on
  // that section; otherwise it shows the hall overview.
  final void Function({int? sectionId}) onPickSeats;

  @override
  Widget build(BuildContext context) {
    final maxLines = expanded ? null : 3;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(text,
          maxLines: maxLines,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
              color: AppColors.muted, fontSize: 14.5, height: 1.55)),
      const SizedBox(height: 6),
      InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(expanded ? 'Show less' : 'More Details',
              style: const TextStyle(
                  color: AppColors.orange, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(height: 22),
      FutureBuilder<SeatMap>(
        future: seatMap,
        builder: (context, snap) {
          // Match the Figma: show the admin's actual venue layout — section
          // polygons only, no seats — straight on the dark page background so
          // the shapes read as the arena from above.
          final map = snap.data;
          final aspect = (map == null || map.layoutHeight <= 0)
              ? 4 / 3
              : (map.layoutWidth / map.layoutHeight).clamp(0.9, 2.2);
          return AspectRatio(
            aspectRatio: aspect.toDouble(),
            child: !snap.hasData
                ? Center(
                    child: Text(
                        snap.hasError
                            ? 'Venue layout unavailable.'
                            : 'Loading venue layout…',
                        style: const TextStyle(color: AppColors.muted)))
                : SectionMapView(
                    map: map!,
                    onSectionTap: (s) => onPickSeats(sectionId: s.id),
                  ),
          );
        },
      ),
      if (pricing.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text('Sections',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          const gap = 12.0;
          final width = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final (i, price) in pricing.indexed)
                SizedBox(
                  width: width,
                  child: _SectionCard(
                    name: price.sectionName,
                    price: price.price,
                    currency: price.currency ?? 'JOD',
                    color: _parseColor(price.color) ?? _sectionColor(i),
                  ),
                ),
            ],
          );
        }),
      ],
    ]);
  }

  static const List<Color> _palette = [
    Color(0xFFE05252),
    Color(0xFF83BE4A),
    Color(0xFFB58CDC),
    Color(0xFFEDC94A),
    Color(0xFF4FB3D9),
    Color(0xFFEE8A3D),
  ];

  static Color _sectionColor(int index) => _palette[index % _palette.length];

  /// Parses the admin's `#RRGGBB` colour, so a section renders in the same
  /// swatch the organiser chose rather than whatever the fallback palette picked.
  static Color? _parseColor(String? hex) {
    if (hex == null) return null;
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6) return null;
    final v = int.tryParse(clean, radix: 16);
    return v == null ? null : Color(v | 0xFF000000);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.name,
      required this.price,
      required this.color,
      required this.currency,
      this.onTap});
  final String name;
  final double price;
  final Color color;
  final String currency;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.raised)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chair, size: 44, color: color),
          const SizedBox(height: 10),
          Text(name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text('${price.toStringAsFixed(0)} $currency',
              style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      ));
}

