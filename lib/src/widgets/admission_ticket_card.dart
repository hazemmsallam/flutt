import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../screens/admission_ticket_screen.dart';

class AdmissionTicketCard extends StatelessWidget {
  const AdmissionTicketCard({
    super.key,
    required this.ticket,
    required this.booking,
  });

  final AdmissionTicket ticket;
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final seat = ticket.seatLabel;
    final section = ticket.sectionName;
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF505050)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
            seat == null ? Icons.confirmation_number : Icons.event_seat,
            color: const Color(0xFFA3BD61),
            size: 27),
        title: Text(
            seat == null ? '#${ticket.number}' : '$seat - #${ticket.number}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(section.isEmpty ? 'General admission' : section,
            style: const TextStyle(fontSize: 12, color: Color(0xFFA7A8AD))),
        trailing: const Icon(Icons.chevron_right, size: 19),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                AdmissionTicketScreen(booking: booking, ticket: ticket),
          ),
        ),
      ),
    );
  }
}
