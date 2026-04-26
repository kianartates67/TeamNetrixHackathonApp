import 'room.dart';
import 'subject.dart';
import 'teacher.dart';
import 'section.dart';

/// One scheduled class entry.
///
/// A `ScheduledClass` ties together:
/// - [subject] being taught
/// - [teacher] who teaches it
/// - [section] of students attending
/// - [room] where it happens
/// - [day] of the week (1-7, but UI mostly uses 1-6 for Mon-Sat)
/// - [timeSlot] start/end time
class ScheduledClass {
  final Room room;
  final Teacher teacher;
  final Subject subject;
  final Section section; // Added section
  final int day;
  final TimeSlot timeSlot;

  ScheduledClass({
    required this.room,
    required this.teacher,
    required this.subject,
    required this.section,
    required this.day,
    required this.timeSlot,
  });
}
