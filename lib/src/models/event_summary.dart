/// One bookable event from GET /api/events/available.
class EventSummary {
  EventSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.startAt,
    required this.status,
    required this.hallName,
    required this.seated,
    this.imageUrl,
    this.tagline,
    this.hallAddress,
    this.featured = false,
    this.tags = const [],
    this.startingPrice,
    this.currency,
  });

  final int id;
  final String name;
  final String? category;
  final DateTime? startAt;
  final String status;
  final String hallName;
  final bool seated;
  final String? imageUrl;
  final String? tagline;
  final String? hallAddress;
  final bool featured;
  final List<String> tags;
  final double? startingPrice;
  final String? currency;

  factory EventSummary.fromJson(Map<String, dynamic> j) => EventSummary(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        category: j['category'] as String?,
        startAt: _date(j['startAt']),
        status: (j['status'] ?? '') as String,
        hallName: (j['hallName'] ?? '') as String,
        seated: (j['seated'] ?? false) as bool,
        imageUrl: j['imageUrl'] as String?,
        tagline: j['tagline'] as String?,
        hallAddress: j['hallAddress'] as String?,
        featured: j['featured'] == true,
        tags:
            (j['tags'] as List? ?? const []).map((e) => e.toString()).toList(),
        startingPrice: (j['startingPrice'] as num?)?.toDouble(),
        currency: j['currency'] as String?,
      );
}

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
