import 'package:flutter/material.dart';

import '../models/seat_map.dart';

/// Colours mirror the admin editor so a hall looks identical on both.
class SeatColors {
  SeatColors._();

  static const vip = Color(0xFF8B5CF6);
  static const premium = Color(0xFF2563EB);
  static const regular = Color(0xFF64748B);
  static const reserved = Color(0xFF9AA3B2); // held by someone else
  static const booked = Color(0xFF2B3444); // sold
  static const selected = Color(0xFFF59E0B);

  static Color forType(SeatType t) {
    switch (t) {
      case SeatType.vip:
        return vip;
      case SeatType.premium:
        return premium;
      case SeatType.regular:
        return regular;
    }
  }

  /// Fill colour for a seat given its status and whether the user picked it.
  static Color fill(Seat s, bool isSelected) {
    if (isSelected) return selected;
    switch (s.status) {
      case SeatStatus.booked:
        return booked;
      case SeatStatus.reserved:
        return reserved;
      case SeatStatus.available:
        return forType(s.type);
    }
  }
}
