/// Simple "requirements" tags for subjects.
///
/// These tags can be used to match a subject with rooms that have the required
/// equipment (e.g., projector).
enum SubjectRequirement { lab, lecture, projector }

/// Subject/course unit that can be scheduled.
///
/// - [courseId] allows scoping subjects to a specific course/program (e.g. BSIT).
class Subject {
  final String id;
  final String name;
  final int units;
  final List<SubjectRequirement> requirements;
  final String courseId; // Added courseId

  Subject({
    required this.id,
    required this.name,
    required this.units,
    required this.requirements,
    required this.courseId,
  });
}
