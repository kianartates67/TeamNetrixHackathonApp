/// Room domain model used for scheduling.
///
/// A `Room` represents a physical classroom/lab. In this project, rooms are
/// embedded directly into `ScheduledClass` entries (rather than referenced by id).
enum RoomEquipment { projector, lab, ac, whiteboard }

/// A physical room that can host classes.
///
/// - [equipment] is a list of supported equipment flags that can be used for
///   basic filtering / validation (e.g., a lab subject needs a lab room).
class Room {
  final String id;
  final String name;
  final int capacity;
  final List<RoomEquipment> equipment;

  Room({
    required this.id,
    required this.name,
    required this.capacity,
    required this.equipment,
  });
}
