import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../widgets/admission_ticket_card.dart';
import 'bookings_screen.dart';

class PaymentConfirmationScreen extends StatelessWidget {
  const PaymentConfirmationScreen({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final count = booking.tickets.length;
    return Scaffold(
      backgroundColor: const Color(0xFF1C1B20),
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 0, 15, 24),
          children: [
            const Text('Confirmation',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 34),
            const Center(child: _SuccessIllustration()),
            const SizedBox(height: 28),
            const Text('Payment Successful',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Your payment has been completed successfully.\n'
                'Your $count ${count == 1 ? "ticket has" : "tickets have"} been confirmed.'),
            const SizedBox(height: 20),
            const Text('Ticket Numbers:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final ticket in booking.tickets) ...[
              AdmissionTicketCard(ticket: ticket, booking: booking),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7500),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pushAndRemoveUntil<void>(
                context,
                MaterialPageRoute(builder: (_) => const BookingsScreen()),
                (route) => route.isFirst,
              ),
              child: const Text('My Tickets'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessIllustration extends StatelessWidget {
  const _SuccessIllustration();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 148,
        height: 148,
        child: Stack(
          children: [
            Center(
              child: CircleAvatar(
                radius: 74,
                backgroundColor: Color(0xFF262626),
                child: Icon(Icons.confirmation_number_rounded,
                    size: 76, color: Color(0xFFFF8200)),
              ),
            ),
            Positioned(
              top: 2,
              left: 7,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF32C82C),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 25),
              ),
            ),
          ],
        ),
      );
}
