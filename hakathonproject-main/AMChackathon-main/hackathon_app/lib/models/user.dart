/// Application-level user model used by the UI.
///
/// This is *not* the same as FirebaseAuth's `User`. It is a lightweight snapshot
/// that the app stores locally to restore the session and to drive role-based UI.
enum UserRole { superAdmin, courseAdmin, teacher }

/// Current signed-in user as understood by RoomSync.
///
/// - [id] is typically a FirebaseAuth uid for teachers, and a fixed string for the
///   prototype admin login.
/// - [courseId] scopes schedules/rooms/sections (e.g., `C1`).
class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? courseId;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.courseId,
  });
}
