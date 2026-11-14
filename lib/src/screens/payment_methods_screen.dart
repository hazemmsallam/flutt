import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/booking.dart';
import '../widgets/countdown.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key, required this.booking});

  final Booking booking;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final _api = ApiClient();
  bool _busy = false;
  bool _expired = false;

  bool _paymentAccepted = false;

  Future<void> _pay() async {
    if (_busy) return;
    final booking = widget.booking;
    if (!_paymentAccepted &&
        (_expired || (booking.expiresAt?.isBefore(DateTime.now()) ?? false))) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (!_paymentAccepted) {
        final result = await _api.pay(booking.id);
        if (!mounted) return;
        if (!result.success) {
          _notice(result.message ?? 'Payment failed. Try again.');
          return;
        }
        _paymentAccepted = true;
      }
      final confirmed = await _api.getBooking(booking.id);
      if (!mounted) return;
      if (confirmed.isConfirmed &&
          confirmed.tickets.length == confirmed.quantity) {
        Navigator.pop(context, confirmed);
      } else {
        _notice('Tickets are not ready yet. Try loading them again.');
      }
    } catch (error) {
      if (mounted) {
        _notice(_paymentAccepted
            ? 'Payment succeeded. Try loading your tickets again.'
            : error is ApiException
                ? error.message
                : 'Could not reach the payment service. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final expiresAt = widget.booking.expiresAt;
    final canPay = !_busy &&
        !_paymentAccepted &&
        !_expired &&
        (expiresAt == null || expiresAt.isAfter(DateTime.now()));

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1B20),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(15, 4, 15, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: _busy ? null : () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('Complete Payment',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 28),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('Select Payment Method',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 28),
              _PaymentOption(
                title: 'Credit Card',
                icon: const _CardMarks(),
                onTap: canPay ? _pay : null,
              ),
              const SizedBox(height: 14),
              _PaymentOption(
                title: 'Orange Money',
                icon: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.north_east, size: 21, color: Colors.white),
                    Icon(Icons.south_west, size: 21, color: Color(0xFFFF8200)),
                  ],
                ),
                onTap: canPay ? _pay : null,
              ),
              const SizedBox(height: 14),
              _PaymentOption(
                title: 'CliQ',
                icon: const Text('CliQ',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.5)),
                onTap: canPay ? _pay : null,
              ),
              const SizedBox(height: 14),
              _PaymentOption(
                title: 'Loyalty Points',
                subtitle: 'Demo payment',
                icon: const Icon(Icons.card_giftcard,
                    size: 37, color: Color(0xFFFF8200)),
                onTap: canPay ? _pay : null,
              ),
              if (_paymentAccepted && !_busy) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                    onPressed: _pay, child: const Text('Load tickets')),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (!canPay && !_busy && !_paymentAccepted) ...[
                const SizedBox(height: 16),
                const Text('Your hold expired. Select tickets again.'),
              ],
              if (expiresAt != null && !_expired)
                Offstage(
                  child: Countdown(
                    expiresAt: expiresAt,
                    onExpired: () {
                      if (mounted) setState(() => _expired = true);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption(
      {required this.title, required this.icon, this.subtitle, this.onTap});

  final String title;
  final Widget icon;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF505050)),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 67),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 45, child: Center(child: icon)),
                  const SizedBox(width: 22),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      if (subtitle case final text?) ...[
                        const SizedBox(height: 5),
                        Text(text,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFA7A8AD))),
                      ],
                    ],
                  )),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ),
      );
}

class _CardMarks extends StatelessWidget {
  const _CardMarks();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          Text('VISA',
              style: TextStyle(
                  color: Color(0xFF1689DB),
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  height: 1)),
          SizedBox(
            width: 35,
            height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                    left: 1,
                    child: CircleAvatar(
                        radius: 10, backgroundColor: Color(0xFFEB001B))),
                Positioned(
                    right: 1,
                    child: CircleAvatar(
                        radius: 10, backgroundColor: Color(0xDDF79E1B))),
              ],
            ),
          ),
        ],
      );
}
