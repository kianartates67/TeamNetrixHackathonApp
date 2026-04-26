/// Student section/group.
///
/// Sections are used in conflict detection so the same section can't be assigned
/// to two classes at the same time.
class Section {
  final String id;
  final String name;
  final String courseId;

  Section({
    required this.id,
    required this.name,
    required this.courseId,
  });
}
