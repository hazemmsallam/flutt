import 'dart:async';

import 'package:flutter/material.dart';

class EventCountdownBanner extends StatefulWidget {
  const EventCountdownBanner(
      {super.key, required this.startAt, this.onStarted});

  final DateTime startAt;
  final VoidCallback? onStarted;

  @override
  State<EventCountdownBanner> createState() => _EventCountdownBannerState();
}

class _EventCountdownBannerState extends State<EventCountdownBanner> {
  Timer? _timer;
  late Duration _remaining;

  void _start() {
    _timer?.cancel();
    _remaining = widget.startAt.difference(DateTime.now());
    if (_remaining <= Duration.zero) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _remaining = widget.startAt.difference(DateTime.now()));
      if (_remaining > Duration.zero) return;
      timer.cancel();
      widget.onStarted?.call();
    });
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(EventCountdownBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startAt != widget.startAt) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining <= Duration.zero) return const SizedBox.shrink();
    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFCB00),
      padding: const EdgeInsets.symmetric(vertical: 7),
      alignment: Alignment.center,
      child: Text('$days d :  $hours h :  $minutes m :  $seconds s',
          style: const TextStyle(
              color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
