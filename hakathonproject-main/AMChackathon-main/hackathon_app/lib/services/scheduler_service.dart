import '../models/room.dart';
import '../models/subject.dart';
import '../models/teacher.dart';
import '../models/section.dart';
import '../models/scheduled_class.dart';
import '../models/history_log.dart';
import '../models/user.dart';
import 'history_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Central scheduling engine for RoomSync.
///
/// Responsibilities:
/// - Maintain an in-memory list of scheduled classes (`_schedule`)
/// - Persist schedules locally for offline use (SharedPreferences)
/// - Best-effort sync schedules to Firestore (when Firebase is initialized
///   AND the user is signed in)
/// - Provide conflict detection and "AI-ish" alternative time suggestions
///
/// Data model note:
/// - Conflicts currently compare by `name` (teacher/room/section). This is simple
///   for a hackathon prototype but may produce false positives if names are not
///   unique. A production version should compare stable IDs.
class SchedulerService {
  List<ScheduledClass> _schedule = [];

  List<ScheduledClass> get schedule => _schedule;

  static const _storageKey = 'roomsync_schedule_v1';
  static const _coursesCollection = 'courses';
  static const _schedulesSubcollection = 'schedules';

  /// Replace the current schedule list and persist locally.
  ///
  /// This is used after loading from Firestore and for bulk updates.
  void setSchedule(List<ScheduledClass> next) {
    _schedule = next;
    _saveToLocal();
  }

  /// Load the schedule from local storage (SharedPreferences).
  ///
  /// This enables offline access and gives the UI something to render quickly
  /// while a remote Firestore fetch happens in the background.
  Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return;

    final decoded = jsonDecode(raw);
    if (decoded is! List) return;

    _schedule = decoded
        .whereType<Map<String, dynamic>>()
        .map(_scheduledClassFromJson)
        .toList();
  }

  /// Persist the current schedule list to local storage.
  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_schedule.map(_scheduledClassToJson).toList());
    await prefs.setString(_storageKey, encoded);
  }

  /// Clear all schedule entries (local) and write an audit log entry.
  void clearSchedule({String? courseId, String? userName, String? userId}) {
    _schedule = [];
    _saveToLocal();
    HistoryService.logAction(
      action: ActionType.delete,
      details: 'Cleared all schedules',
      courseId: courseId,
      userName: userName,
      userId: userId,
    );
  }

  /// Remove one schedule entry by index (local) and write an audit log entry.
  void removeSchedule(int index, {String? userName, String? userId}) {
    if (index >= 0 && index < _schedule.length) {
      final removed = _schedule[index];
      _schedule.removeAt(index);
      _saveToLocal();
      HistoryService.logAction(
        action: ActionType.delete,
        details:
            'Removed schedule: ${removed.subject.name} for ${removed.section.name} in ${removed.room.name}',
        courseId: removed.subject.courseId,
        userName: userName,
        userId: userId,
      );
    }
  }

  /// Add a schedule created via manual form entry.
  ///
  /// Returns a human-readable error string when a conflict is detected, or
  /// `null` if the schedule was accepted.
  ///
  /// This method:
  /// - validates conflicts (room/teacher/section)
  /// - saves locally immediately
  /// - logs the action
  /// - then attempts Firestore sync (best-effort)
  Future<String?> addManualSchedule({
    required Room room,
    required Teacher teacher,
    required Subject subject,
    required Section section,
    required int day,
    required TimeSlot slot,
    String? courseId,
    String? userName,
    String? userId,
  }) async {
    // Conflict Detection: Room
    if (!isRoomAvailable(room, day, slot)) {
      return "Conflict: Room ${room.name} is already occupied at this time.";
    }

    // Conflict Detection: Teacher
    if (!isTeacherAvailable(teacher, day, slot)) {
      return "Conflict: Teacher ${teacher.name} has a schedule conflict.";
    }

    // Conflict Detection: Section (Students can't be in two places at once)
    if (!isSectionAvailable(section, day, slot)) {
      return "Conflict: Section ${section.name} is already in another class at this time.";
    }

    _schedule.add(ScheduledClass(
      room: room,
      teacher: teacher,
      subject: subject,
      section: section,
      day: day,
      timeSlot: slot,
    ));
    _saveToLocal();

    HistoryService.logAction(
      action: ActionType.add,
      details:
          'Added schedule: ${subject.name} (${section.name}) in ${room.name} on ${_dayName(day)}',
      courseId: courseId ?? subject.courseId,
      userName: userName,
      userId: userId,
    );

    // Firestore sync (best-effort)
    return _trySyncToFirestore(
      room: room,
      teacher: teacher,
      subject: subject,
      section: section,
      day: day,
      slot: slot,
      courseId: courseId,
    );
  }

  /// Replace a schedule entry at [index] with [newClass].
  ///
  /// Note: this currently does not re-run full conflict validation, because
  /// the UI already checks room/teacher conflicts for drag-drop changes.
  /// If you add new update entry points, consider validating here too.
  Future<String?> updateSchedule(int index, ScheduledClass newClass,
      {String? userName, String? userId}) async {
    if (index >= 0 && index < _schedule.length) {
      final old = _schedule[index];
      _schedule[index] = newClass;
      _saveToLocal();
      HistoryService.logAction(
        action: ActionType.update,
        details:
            'Updated schedule: ${old.subject.name} -> ${newClass.subject.name}',
        courseId: newClass.subject.courseId,
        userName: userName,
        userId: userId,
      );
      return null;
    }
    return "Index out of bounds";
  }

  /// Attempt to sync a single newly-created schedule entry to Firestore.
  ///
  /// This is "best-effort":
  /// - If Firebase is not initialized, it silently does nothing.
  /// - If the user is not authenticated, it returns a message indicating the
  ///   schedule is only saved locally.
  ///
  /// Firestore layout:
  /// - `courses/{courseId}/schedules/*` for course-shared schedules
  Future<String?> _trySyncToFirestore({
    required Room room,
    required Teacher teacher,
    required Subject subject,
    required Section section,
    required int day,
    required TimeSlot slot,
    String? courseId,
  }) async {
    try {
      if (Firebase.apps.isEmpty) return null;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return 'Saved locally, but not synced (not signed in).';
      }
      final resolvedCourseId = (courseId ?? subject.courseId).trim();
      if (resolvedCourseId.isEmpty) {
        return 'Saved locally, but not synced (missing course id).';
      }

      final startMinutes = slot.startHour * 60 + slot.startMinute;
      final endMinutes = slot.endHour * 60 + slot.endMinute;
      final teacherIdentity = await _resolveTeacherIdentity(
        teacherName: teacher.name,
        courseId: resolvedCourseId,
      );

      await FirebaseFirestore.instance
          .collection(_coursesCollection)
          .doc(resolvedCourseId)
          .collection(_schedulesSubcollection)
          .add({
        'createdByUid': currentUser.uid,
        'courseId': resolvedCourseId,
        'teacherName': teacher.name,
        'teacherUid': teacherIdentity.$1,
        'teacherEmail': teacherIdentity.$2,
        'subjectName': subject.name,
        'roomName': room.name,
        'sectionName': section.name,
        'dayIndex': day,
        'day': _dayName(day).toLowerCase(),
        'startTime': _formatMinutes(startMinutes),
        'endTime': _formatMinutes(endMinutes),
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'Saved locally, but failed to sync to Firestore: $e';
    }
  }

  /// Load schedules for a given [courseId] from Firestore.
  ///
  /// Returns `true` when at least one remote item is found and applied to the
  /// local schedule list.
  Future<bool> loadFromFirestore({String? courseId}) async {
    try {
      if (Firebase.apps.isEmpty) return false;
      final resolvedCourseId = (courseId ?? '').trim();
      if (resolvedCourseId.isEmpty) return false;

      Query query = FirebaseFirestore.instance
          .collection(_coursesCollection)
          .doc(resolvedCourseId)
          .collection(_schedulesSubcollection);

      final snap = await query.get();
      final items = snap.docs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        final day = (m['dayIndex'] as num?)?.toInt() ?? 1;
        final startMin = (m['startMinutes'] as num?)?.toInt() ?? 480;
        final endMin = (m['endMinutes'] as num?)?.toInt() ?? (480 + 60);

        TimeSlot slotFromMinutes(int s, int e) {
          return TimeSlot(
            startHour: s ~/ 60,
            startMinute: s % 60,
            endHour: e ~/ 60,
            endMinute: e % 60,
          );
        }

        return ScheduledClass(
          room: Room(
              id: 'fs_room_${m['roomName']}',
              name: (m['roomName'] ?? '').toString(),
              capacity: 0,
              equipment: const []),
          teacher: Teacher(
            id: (m['teacherUid'] ?? 'fs_teacher_${m['teacherName']}')
                .toString(),
            name: (m['teacherName'] ?? '').toString(),
            expertiseSubjectIds: const [],
            courseId: resolvedCourseId,
            availableDays: const [1, 2, 3, 4, 5, 6],
            availableTimeSlots: const [],
          ),
          subject: Subject(
            id: 'fs_subject_${m['subjectName']}',
            name: (m['subjectName'] ?? '').toString(),
            units: 3,
            requirements: const [],
            courseId: resolvedCourseId,
          ),
          section: Section(
            id: 'fs_section_${m['sectionName']}',
            name: (m['sectionName'] ?? '').toString(),
            courseId: resolvedCourseId,
          ),
          day: day,
          timeSlot: slotFromMinutes(startMin, endMin),
        );
      }).toList();

      if (items.isNotEmpty) {
        setSchedule(items);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<(String, String)> _resolveTeacherIdentity({
    required String teacherName,
    required String courseId,
  }) async {
    final name = teacherName.trim();
    if (name.isEmpty) return ('', '');
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: UserRole.teacher.name)
          .where('courseId', isEqualTo: courseId)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return ('', '');
      final doc = snap.docs.first;
      final email = (doc.data()['email'] ?? '').toString();
      return (doc.id, email);
    } catch (_) {
      return ('', '');
    }
  }

  /// Convert an integer day index (1-7) into a display day name.
  static String _dayName(int dayIndex) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final i = dayIndex.clamp(1, 7) - 1;
    return days[i];
  }

  /// Format minutes-since-midnight into a 12h time label like `1:30 PM`.
  static String _formatMinutes(int totalMinutes) {
    final hour24 = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = (hour24 % 12) == 0 ? 12 : (hour24 % 12);
    final m = minute.toString().padLeft(2, '0');
    return '$hour12:$m $period';
  }

  /// Check room availability for a given day and time slot.
  bool isRoomAvailable(Room room, int day, TimeSlot slot) {
    return !_schedule.any((sc) =>
        sc.room.name == room.name &&
        sc.day == day &&
        sc.timeSlot.overlaps(slot));
  }

  /// Check teacher availability for a given day and time slot.
  bool isTeacherAvailable(Teacher teacher, int day, TimeSlot slot) {
    return !_schedule.any((sc) =>
        sc.teacher.name == teacher.name &&
        sc.day == day &&
        sc.timeSlot.overlaps(slot));
  }

  /// Check section availability for a given day and time slot.
  bool isSectionAvailable(Section section, int day, TimeSlot slot) {
    return !_schedule.any((sc) =>
        sc.section.name == section.name &&
        sc.day == day &&
        sc.timeSlot.overlaps(slot));
  }

  // ---- AI-ish suggestions (rule-based) ----
  /// Return all existing scheduled classes that conflict by room OR teacher.
  ///
  /// This is used to explain why a requested slot can't be scheduled.
  List<ScheduledClass> findTeacherOrRoomConflicts({
    required Teacher teacher,
    required Room room,
    required int day,
    required TimeSlot slot,
  }) {
    return _schedule.where((sc) {
      if (sc.day != day) return false;
      final sameTeacher = sc.teacher.name == teacher.name;
      final sameRoom = sc.room.name == room.name;
      if (!(sameTeacher || sameRoom)) return false;
      return sc.timeSlot.overlaps(slot);
    }).toList();
  }

  /// Convenience wrapper that returns `true` when any room/teacher conflict exists.
  bool hasTeacherOrRoomConflict({
    required Teacher teacher,
    required Room room,
    required int day,
    required TimeSlot slot,
  }) {
    return findTeacherOrRoomConflicts(
      teacher: teacher,
      room: room,
      day: day,
      slot: slot,
    ).isNotEmpty;
  }

  /// Suggest alternative time slots that fit the same duration as [desiredSlot].
  ///
  /// Approach:
  /// - Build "busy" intervals from existing schedule entries for that day
  ///   (teacher OR room)
  /// - Merge busy intervals
  /// - Subtract them from teacher availability windows to produce free segments
  /// - Emit candidate slots aligned to [stepMinutes]
  ///
  /// This is intentionally simple and deterministic (no ML), but provides
  /// useful UX for quickly resolving conflicts.
  List<TimeSlot> suggestAlternativeTimeSlots({
    required Teacher teacher,
    required Room room,
    required int day,
    required TimeSlot desiredSlot,
    int dayStartMinutes = 8 * 60,
    int dayEndMinutes = 17 * 60,
    int stepMinutes = 30,
    int maxSuggestions = 6,
  }) {
    final desiredStart = desiredSlot.startHour * 60 + desiredSlot.startMinute;
    final desiredEnd = desiredSlot.endHour * 60 + desiredSlot.endMinute;
    final duration = desiredEnd - desiredStart;
    if (duration <= 0) return const [];

    // Teacher must be available on that day
    if (teacher.availableDays.isNotEmpty &&
        !teacher.availableDays.contains(day)) return const [];

    // Availability windows: if teacher has explicit windows use them; else default to full day.
    final teacherWindows = teacher.availableTimeSlots.isNotEmpty
        ? teacher.availableTimeSlots
            .map((ts) => _Interval(
                  ts.startHour * 60 + ts.startMinute,
                  ts.endHour * 60 + ts.endMinute,
                ))
            .where((w) => w.end > w.start)
            .toList()
        : <_Interval>[_Interval(dayStartMinutes, dayEndMinutes)];

    // Busy intervals from either teacher OR room (union).
    final busy = <_Interval>[];
    for (final sc in _schedule.where((sc) => sc.day == day)) {
      if (sc.teacher.name == teacher.name || sc.room.name == room.name) {
        final s = sc.timeSlot.startHour * 60 + sc.timeSlot.startMinute;
        final e = sc.timeSlot.endHour * 60 + sc.timeSlot.endMinute;
        if (e > s) busy.add(_Interval(s, e));
      }
    }
    final mergedBusy = _mergeIntervals(busy);

    // For each teacher window, subtract busy intervals => free segments.
    final freeSegments = <_Interval>[];
    for (final w in teacherWindows) {
      freeSegments.addAll(_subtractIntervals(w, mergedBusy));
    }

    // Generate candidate slots from free segments, aligned to stepMinutes.
    final suggestions = <TimeSlot>[];
    for (final seg in freeSegments) {
      int start = _ceilToStep(seg.start, stepMinutes);
      while (start + duration <= seg.end) {
        final candidate =
            _intervalToTimeSlot(_Interval(start, start + duration));

        if (isTeacherAvailable(teacher, day, candidate) &&
            isRoomAvailable(room, day, candidate)) {
          if (!(start == desiredStart && start + duration == desiredEnd)) {
            suggestions.add(candidate);
          }
        }

        if (suggestions.length >= maxSuggestions) return suggestions;
        start += stepMinutes;
      }
    }

    return suggestions;
  }

  static int _ceilToStep(int minutes, int step) {
    if (step <= 1) return minutes;
    final r = minutes % step;
    return r == 0 ? minutes : (minutes + (step - r));
  }

  /// Convert internal minute interval representation into a [TimeSlot].
  static TimeSlot _intervalToTimeSlot(_Interval i) {
    return TimeSlot(
      startHour: i.start ~/ 60,
      startMinute: i.start % 60,
      endHour: i.end ~/ 60,
      endMinute: i.end % 60,
    );
  }

  /// Merge overlapping minute intervals into a minimal set of disjoint intervals.
  static List<_Interval> _mergeIntervals(List<_Interval> intervals) {
    if (intervals.isEmpty) return const [];
    final sorted = [...intervals]..sort((a, b) => a.start.compareTo(b.start));
    final out = <_Interval>[sorted.first];
    for (final cur in sorted.skip(1)) {
      final last = out.last;
      if (cur.start <= last.end) {
        out[out.length - 1] =
            _Interval(last.start, cur.end > last.end ? cur.end : last.end);
      } else {
        out.add(cur);
      }
    }
    return out;
  }

  /// Subtract [busy] intervals from a [window] interval and return remaining segments.
  static List<_Interval> _subtractIntervals(
      _Interval window, List<_Interval> busy) {
    var segments = <_Interval>[window];
    for (final b in busy) {
      final next = <_Interval>[];
      for (final s in segments) {
        if (b.end <= s.start || s.end <= b.start) {
          next.add(s);
          continue;
        }
        if (b.start > s.start) next.add(_Interval(s.start, b.start));
        if (b.end < s.end) next.add(_Interval(b.end, s.end));
      }
      segments = next;
      if (segments.isEmpty) break;
    }
    return segments.where((s) => s.end > s.start).toList();
  }

  /// Basic report helper: compute total scheduled hours and utilization % for a room.
  ///
  /// The utilization denominator is currently hardcoded to 50 hours/week (3000 minutes).
  Map<String, dynamic> getRoomUtilizationReport(String roomName) {
    var roomClasses =
        _schedule.where((sc) => sc.room.name == roomName).toList();
    int totalMinutes = roomClasses.fold(0, (sum, sc) {
      int duration = (sc.timeSlot.endHour * 60 + sc.timeSlot.endMinute) -
          (sc.timeSlot.startHour * 60 + sc.timeSlot.startMinute);
      return sum + duration;
    });

    // Assuming 50 hours (3000 minutes) per week
    double utilityPercentage = (totalMinutes / 3000) * 100;

    return {
      'roomName': roomName,
      'totalHours': (totalMinutes / 60).toStringAsFixed(1),
      'utility': utilityPercentage,
      'classes': roomClasses,
    };
  }

  /// Basic report helper: compute total subject units taught by a given teacher.
  Map<String, dynamic> getTeacherLoadReport(String teacherName) {
    var teacherClasses =
        _schedule.where((sc) => sc.teacher.name == teacherName).toList();
    int totalUnits =
        teacherClasses.fold(0, (sum, sc) => sum + sc.subject.units);

    return {
      'teacher': teacherName,
      'totalUnits': totalUnits,
      'classes': teacherClasses,
    };
  }

  /// Export the current schedule list to a simple CSV format.
  ///
  /// Note: This does not escape commas/quotes. If you expect names with commas,
  /// add proper CSV escaping.
  String generateCsvExport() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln("Day,Time,Section,Subject,Teacher,Room");
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    for (var sc in _schedule) {
      buffer.writeln(
          "${days[sc.day - 1]},${sc.timeSlot.startHour}:${sc.timeSlot.startMinute}-${sc.timeSlot.endHour}:${sc.timeSlot.endMinute},${sc.section.name},${sc.subject.name},${sc.teacher.name},${sc.room.name}");
    }
    return buffer.toString();
  }

  // ---- Serialization helpers (local persistence) ----
  /// Encode a [ScheduledClass] to a JSON-friendly map for local storage.
  static Map<String, dynamic> _scheduledClassToJson(ScheduledClass sc) {
    return {
      'day': sc.day,
      'timeSlot': {
        'startHour': sc.timeSlot.startHour,
        'startMinute': sc.timeSlot.startMinute,
        'endHour': sc.timeSlot.endHour,
        'endMinute': sc.timeSlot.endMinute,
      },
      'room': {
        'id': sc.room.id,
        'name': sc.room.name,
        'capacity': sc.room.capacity,
        'equipment': sc.room.equipment.map((e) => e.name).toList(),
      },
      'teacher': {
        'id': sc.teacher.id,
        'name': sc.teacher.name,
        'expertiseSubjectIds': sc.teacher.expertiseSubjectIds,
        'courseId': sc.teacher.courseId,
        'availableDays': sc.teacher.availableDays,
        'availableTimeSlots': sc.teacher.availableTimeSlots
            .map((ts) => {
                  'startHour': ts.startHour,
                  'startMinute': ts.startMinute,
                  'endHour': ts.endHour,
                  'endMinute': ts.endMinute,
                })
            .toList(),
      },
      'subject': {
        'id': sc.subject.id,
        'name': sc.subject.name,
        'units': sc.subject.units,
        'requirements': sc.subject.requirements.map((r) => r.name).toList(),
        'courseId': sc.subject.courseId,
      },
      'section': {
        'id': sc.section.id,
        'name': sc.section.name,
        'courseId': sc.section.courseId,
      },
    };
  }

  /// Decode a [ScheduledClass] from a local-storage JSON map.
  static ScheduledClass _scheduledClassFromJson(Map<String, dynamic> map) {
    final ts = map['timeSlot'] as Map<String, dynamic>;
    final roomMap = map['room'] as Map<String, dynamic>;
    final teacherMap = map['teacher'] as Map<String, dynamic>;
    final subjectMap = map['subject'] as Map<String, dynamic>;
    final sectionMap = map['section'] as Map<String, dynamic>;

    final room = Room(
      id: (roomMap['id'] ?? '').toString(),
      name: (roomMap['name'] ?? '').toString(),
      capacity: (roomMap['capacity'] as num?)?.toInt() ?? 0,
      equipment: ((roomMap['equipment'] as List?) ?? const [])
          .whereType<String>()
          .map((s) => RoomEquipment.values.firstWhere(
                (e) => e.name == s,
                orElse: () => RoomEquipment.whiteboard,
              ))
          .toList(),
    );

    final teacher = Teacher(
      id: (teacherMap['id'] ?? '').toString(),
      name: (teacherMap['name'] ?? '').toString(),
      expertiseSubjectIds:
          ((teacherMap['expertiseSubjectIds'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
      courseId: (teacherMap['courseId'] ?? '').toString(),
      availableDays: ((teacherMap['availableDays'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      availableTimeSlots:
          ((teacherMap['availableTimeSlots'] as List?) ?? const [])
              .whereType<Map>()
              .map((m) => TimeSlot(
                    startHour: ((m['startHour'] as num?)?.toInt() ?? 8),
                    startMinute: ((m['startMinute'] as num?)?.toInt() ?? 0),
                    endHour: ((m['endHour'] as num?)?.toInt() ?? 9),
                    endMinute: ((m['endMinute'] as num?)?.toInt() ?? 0),
                  ))
              .toList(),
    );

    final subject = Subject(
      id: (subjectMap['id'] ?? '').toString(),
      name: (subjectMap['name'] ?? '').toString(),
      units: (subjectMap['units'] as num?)?.toInt() ?? 0,
      requirements: ((subjectMap['requirements'] as List?) ?? const [])
          .whereType<String>()
          .map((s) => SubjectRequirement.values.firstWhere(
                (r) => r.name == s,
                orElse: () => SubjectRequirement.lecture,
              ))
          .toList(),
      courseId: (subjectMap['courseId'] ?? '').toString(),
    );

    final section = Section(
      id: (sectionMap['id'] ?? '').toString(),
      name: (sectionMap['name'] ?? '').toString(),
      courseId: (sectionMap['courseId'] ?? '').toString(),
    );

    final timeSlot = TimeSlot(
      startHour: ((ts['startHour'] as num?)?.toInt() ?? 8),
      startMinute: ((ts['startMinute'] as num?)?.toInt() ?? 0),
      endHour: ((ts['endHour'] as num?)?.toInt() ?? 9),
      endMinute: ((ts['endMinute'] as num?)?.toInt() ?? 0),
    );

    return ScheduledClass(
      room: room,
      teacher: teacher,
      subject: subject,
      section: section,
      day: (map['day'] as num?)?.toInt() ?? 1,
      timeSlot: timeSlot,
    );
  }
}

/// Internal minute-based interval used by the suggestion algorithm.
class _Interval {
  final int start;
  final int end;
  const _Interval(this.start, this.end);
}
