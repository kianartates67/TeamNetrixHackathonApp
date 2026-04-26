/// Course/program model (e.g., BSIT).
///
/// Used to group schedules and related entities by [id].
class Course {
  final String id;
  final String name;
  final String department;

  Course({
    required this.id,
    required this.name,
    required this.department,
  });
}
