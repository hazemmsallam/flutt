class EventDetail {
  EventDetail({required this.description, required this.pricing});

  final String description;
  final List<EventPrice> pricing;

  factory EventDetail.fromJson(Map<String, dynamic> json) => EventDetail(
        description: (json['description'] ?? '') as String,
        pricing: (json['pricing'] as List? ?? const [])
            .map((e) => EventPrice.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A section the audience can book, as returned by the event-detail endpoint.
/// Includes the presentation hints (colour, booking mode) and the sectionId
/// the client uses to deep-link straight into that section's seat picker.
class EventPrice {
  EventPrice({
    required this.sectionId,
    required this.sectionName,
    required this.price,
    this.currency,
    this.color,
    this.bookingMode,
    this.capacity,
  });
  final int? sectionId;
  final String sectionName;
  final double price;
  final String? currency;
  final String? color;
  final String? bookingMode; // "SEATED" or "GENERAL_ADMISSION"
  final int? capacity;

  bool get isGeneralAdmission => bookingMode == 'GENERAL_ADMISSION';

  factory EventPrice.fromJson(Map<String, dynamic> json) => EventPrice(
        sectionId: (json['sectionId'] as num?)?.toInt(),
        sectionName: (json['sectionName'] ?? '') as String,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String?,
        color: json['color'] as String?,
        bookingMode: json['bookingMode'] as String?,
        capacity: (json['capacity'] as num?)?.toInt(),
      );
}
