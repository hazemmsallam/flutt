import 'dart:async';

import 'package:flutter/material.dart';

/// Ticking "mm:ss left" until [expiresAt]; calls [onExpired] once when it hits zero.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.expiresAt, this.onExpired, this.style});

  final DateTime expiresAt;
  final VoidCallback? onExpired;
  final TextStyle? style;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;
  bool _firedExpired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      if (!_firedExpired) {
        _firedExpired = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onExpired?.call());
      }
      return Text('expired', style: widget.style);
    }
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text('$m:$s left', style: widget.style);
  }
}
