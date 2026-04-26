/// Teacher domain model.
///
/// In this project, `Teacher` is used both:
/// - as a directory entry (who can teach what / when), and
/// - inside schedule entries (who is assigned to a time slot).
class Teacher {
  final String id;
  final String name;
  final List<String> expertiseSubjectIds;
  final String courseId;
  final List<int> availableDays;
  final List<TimeSlot> availableTimeSlots;

  const Teacher({
    required this.id,
    required this.name,
    required this.expertiseSubjectIds,
    required this.courseId,
    required this.availableDays,
    required this.availableTimeSlots,
  });
}

/// Time range used for teacher availability and scheduled classes.
///
/// Overlap logic uses half-open intervals: `[start, end)`.
/// That means:
/// - `8:00-9:00` overlaps `8:30-9:30`
/// - `8:00-9:00` does NOT overlap `9:00-10:00`
class TimeSlot {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const TimeSlot({
    required this.startHour,
    this.startMinute = 0,
    required this.endHour,
    this.endMinute = 0,
  });

  int get _startInMinutes => startHour * 60 + startMinute;
  int get _endInMinutes => endHour * 60 + endMinute;

  /// Returns `true` when this time slot intersects with [other].
  bool overlaps(TimeSlot other) {
    return _startInMinutes < other._endInMinutes &&
        other._startInMinutes < _endInMinutes;
  }
}
