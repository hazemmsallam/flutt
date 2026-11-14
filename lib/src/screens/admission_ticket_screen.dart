import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/booking.dart';
import '../theme/app_theme.dart';
import 'events_screen.dart';

class AdmissionTicketScreen extends StatefulWidget {
  const AdmissionTicketScreen({
    super.key,
    required this.booking,
    required this.ticket,
  });

  final Booking booking;
  final AdmissionTicket ticket;

  @override
  State<AdmissionTicketScreen> createState() => _AdmissionTicketScreenState();
}

class _AdmissionTicketScreenState extends State<AdmissionTicketScreen> {
  final _ticketImage = GlobalKey();
  bool _exporting = false;

  Future<void> _export({required bool share, Rect? shareOrigin}) async {
    setState(() => _exporting = true);
    try {
      final boundary = _ticketImage.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      try {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        if (!mounted) return;
        final number =
            widget.ticket.number.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final name = 'Ticket-$number.png';
        if (share) {
          await SharePlus.instance.share(ShareParams(
            files: [XFile.fromData(png, mimeType: 'image/png')],
            fileNameOverrides: [name],
            sharePositionOrigin: shareOrigin,
          ));
        } else {
          final saved = await FilePicker.saveFile(
            fileName: name,
            bytes: png,
            mimeType: 'image/png',
          );
          if (saved != null && mounted) _notify('Ticket saved');
        }
      } finally {
        image.dispose();
      }
    } catch (_) {
      if (mounted) _notify('Couldn’t ${share ? 'share' : 'save'} the ticket');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final booking = widget.booking;
    final section = ticket.sectionName.isEmpty
        ? (ticket.seatLabel == null ? 'General admission' : 'Seat')
        : ticket.sectionName;
    final label =
        ticket.seatLabel == null ? section : '$section - ${ticket.seatLabel}';
    const orange = Color(0xFFFF7500);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return Scaffold(
      backgroundColor: AppColors.ticketBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            const Align(alignment: Alignment.centerLeft, child: BackButton()),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 20),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 23, fontWeight: FontWeight.w700)),
            ),
            RepaintBoundary(
              key: _ticketImage,
              child:
                  _TicketPass(booking: booking, ticket: ticket, label: label),
            ),
            const SizedBox(height: 30),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 42),
                shape: shape,
              ),
              onPressed: _exporting ? null : () => _export(share: false),
              child: const Text('Download'),
            ),
            const SizedBox(height: 8),
            Builder(builder: (buttonContext) {
              return OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  minimumSize: const Size(0, 42),
                  shape: shape,
                ),
                onPressed: _exporting
                    ? null
                    : () {
                        final box =
                            buttonContext.findRenderObject() as RenderBox;
                        _export(
                            share: true,
                            shareOrigin:
                                box.localToGlobal(Offset.zero) & box.size);
                      },
                child: const Text('Share'),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TicketPass extends StatelessWidget {
  const _TicketPass(
      {required this.booking, required this.ticket, required this.label});

  final Booking booking;
  final AdmissionTicket ticket;
  final String label;

  @override
  Widget build(BuildContext context) {
    final start = booking.eventStartAt;
    const barcodeHeight = 64.0;
    const barcodePadding = 16.0;
    const notchOffset = barcodeHeight + barcodePadding * 2 + 4;
    return ClipPath(
      clipper: const _TicketClipper(notchOffset),
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(barcodePadding),
          child: DefaultTextStyle(
            style: const TextStyle(
                color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 1.53,
                    child: EventPoster(imageUrl: booking.eventImageUrl),
                  ),
                ),
                const SizedBox(height: 22),
                Text(booking.eventName,
                    style: const TextStyle(
                        fontSize: 23, fontWeight: FontWeight.w700)),
                const SizedBox(height: 30),
                if (start != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _TicketField(
                              'Date', DateFormat('d MMM yyyy').format(start))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _TicketField(
                              'Time', DateFormat('h:mm a').format(start))),
                    ],
                  ),
                  const SizedBox(height: 26),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _TicketField(
                            ticket.seatLabel == null ? 'Section' : 'Seat',
                            label)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _TicketField('Ticket ID', '#${ticket.number}')),
                  ],
                ),
                if (booking.hallName case final hall? when hall.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  _TicketField('Location', hall),
                ],
                const SizedBox(height: 56),
                BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: ticket.number,
                  drawText: false,
                  height: barcodeHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  errorBuilder: (_, __) => SizedBox(
                    height: barcodeHeight,
                    child: Center(child: Text('#${ticket.number}')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketField extends StatelessWidget {
  const _TicketField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF333333))),
        const SizedBox(height: 5),
        Text(value),
      ],
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper(this.notchOffset);

  final double notchOffset;

  @override
  Path getClip(Size size) {
    final border = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(12)));
    final y = size.height - notchOffset;
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: 12))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: 12));
    return Path.combine(PathOperation.difference, border, notches);
  }

  @override
  bool shouldReclip(_TicketClipper oldClipper) =>
      notchOffset != oldClipper.notchOffset;
}
