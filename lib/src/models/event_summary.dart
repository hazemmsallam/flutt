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
  });

  final int id;
  final String name;
  final String? category;
  final DateTime? startAt;
  final String status;
  final String hallName;
  final bool seated;

  factory EventSummary.fromJson(Map<String, dynamic> j) => EventSummary(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        category: j['category'] as String?,
        startAt: _date(j['startAt']),
        status: (j['status'] ?? '') as String,
        hallName: (j['hallName'] ?? '') as String,
        seated: (j['seated'] ?? false) as bool,
      );
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
