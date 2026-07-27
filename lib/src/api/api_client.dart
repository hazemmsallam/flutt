import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/booking.dart';
import '../models/event_summary.dart';
import '../models/seat_map.dart';

/// Error carrying the API's user-facing message (backend returns `{ "message": ... }`).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

/// Thin wrapper over the event-ticketing REST API.
class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  Uri _uri(String path) => Uri.parse('${Config.baseUrl}$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Customer-Ref': Config.customerRef,
      };

  // ---- events -------------------------------------------------------------

  Future<List<EventSummary>> availableEvents() async {
    final res = await _http.get(_uri('/api/events/available'), headers: _headers);
    final list = _ok(res) as List;
    return list.map((e) => EventSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SeatMap> seatMap(int eventId) async {
    final res = await _http.get(_uri('/api/events/$eventId/seats'), headers: _headers);
    return SeatMap.fromJson(_ok(res) as Map<String, dynamic>);
  }

  // ---- bookings -----------------------------------------------------------

  Future<Booking> createBooking(int eventId, List<int> seatIds) async {
    final res = await _http.post(
      _uri('/api/bookings'),
      headers: _headers,
      body: jsonEncode({
        'eventId': eventId,
        'customerRef': Config.customerRef,
        'seatIds': seatIds,
      }),
    );
    return Booking.fromJson(_ok(res) as Map<String, dynamic>);
  }

  /// Books [quantity] general-admission tickets in [sectionId].
  Future<Booking> createSectionBooking(int eventId, int sectionId, int quantity) async {
    final res = await _http.post(
      _uri('/api/bookings'),
      headers: _headers,
      body: jsonEncode({
        'eventId': eventId,
        'customerRef': Config.customerRef,
        'sectionId': sectionId,
        'quantity': quantity,
      }),
    );
    return Booking.fromJson(_ok(res) as Map<String, dynamic>);
  }

  Future<Booking> getBooking(int id) async {
    final res = await _http.get(_uri('/api/bookings/$id'), headers: _headers);
    return Booking.fromJson(_ok(res) as Map<String, dynamic>);
  }

  Future<List<Booking>> myBookings() async {
    final res = await _http.get(_uri('/api/bookings'), headers: _headers);
    final list = _ok(res) as List;
    return list.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PaymentResult> pay(int id) async {
    final res = await _http.post(_uri('/api/bookings/$id/payment'), headers: _headers);
    return PaymentResult.fromJson(_ok(res) as Map<String, dynamic>);
  }

  Future<Booking> cancel(int id) async {
    final res = await _http.delete(_uri('/api/bookings/$id'), headers: _headers);
    return Booking.fromJson(_ok(res) as Map<String, dynamic>);
  }

  // ---- helpers ------------------------------------------------------------

  dynamic _ok(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    String message = 'Request failed (${res.statusCode})';
    if (body is Map && body['message'] is String) {
      message = body['message'] as String;
    }
    throw ApiException(res.statusCode, message);
  }

  void close() => _http.close();
}
