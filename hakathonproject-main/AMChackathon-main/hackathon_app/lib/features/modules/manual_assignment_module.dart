part of '../../main.dart';

/// Admin-only module for creating schedules by manual input.
///
/// This is the main "assignment" workflow:
/// - Admin fills in teacher/subject/room/section + day/time
/// - `SchedulerService.addManualSchedule` validates conflicts and saves
/// - If there's a conflict, `SchedulerService.suggestAlternativeTimeSlots` is used
///   to generate quick "AI Suggestions" that can be applied to the form.
extension ManualAssignmentModule on _DashboardScreenState {
  Widget buildManualAssignmentModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Manually Assign Teacher & Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
                labelText: 'Teacher Name', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _teacherName = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(
                labelText: 'Subject Name', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _subjectName = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(
                labelText: 'Room Name', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _roomName = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(
                labelText: 'Section Name (e.g. BSIT-3A)',
                border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _sectionName = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(
                labelText: 'Select Day', border: OutlineInputBorder()),
            value: _dayIndex,
            items: List.generate(_dayNames.length, (index) {
              return DropdownMenuItem(
                  value: index + 1, child: Text(_dayNames[index]));
            }),
            onChanged: (v) => setState(() => _dayIndex = v!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                      labelText: 'Start Time (e.g. 10:30 AM)',
                      border: OutlineInputBorder()),
                  initialValue: _startTime,
                  onChanged: (v) => setState(() => _startTime = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                      labelText: 'End Time (e.g. 1:00 PM)',
                      border: OutlineInputBorder()),
                  initialValue: _endTime,
                  onChanged: (v) => setState(() => _endTime = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50)),
            onPressed: () async {
              if (_teacherName.isNotEmpty &&
                  _subjectName.isNotEmpty &&
                  _roomName.isNotEmpty &&
                  _sectionName.isNotEmpty) {
                final activeCourseId = widget.currentUser.courseId ?? 'C1';
                final start = parseTimeToMinutes(_startTime);
                final end = parseTimeToMinutes(_endTime);

                final manualTeacher = Teacher(
                  id: 'M_T_${DateTime.now().millisecondsSinceEpoch}',
                  name: _teacherName,
                  expertiseSubjectIds: const [],
                  courseId: activeCourseId,
                  availableDays: const [1, 2, 3, 4, 5, 6],
                  availableTimeSlots: const [
                    TimeSlot(
                        startHour: 8, startMinute: 0, endHour: 17, endMinute: 0)
                  ],
                );

                final manualSubject = Subject(
                  id: 'M_S_${DateTime.now().millisecondsSinceEpoch}',
                  name: _subjectName,
                  units: 3,
                  requirements: const [],
                  courseId: activeCourseId,
                );

                final manualRoom = Room(
                  id: 'M_R_${DateTime.now().millisecondsSinceEpoch}',
                  name: _roomName,
                  capacity: 40,
                  equipment: const [],
                );

                final manualSection = Section(
                  id: 'M_SEC_${DateTime.now().millisecondsSinceEpoch}',
                  name: _sectionName,
                  courseId: activeCourseId,
                );

                final desiredSlot = TimeSlot(
                  startHour: start['hour']!,
                  startMinute: start['minute']!,
                  endHour: end['hour']!,
                  endMinute: end['minute']!,
                );

                final error = await _schedulerService.addManualSchedule(
                  room: manualRoom,
                  teacher: manualTeacher,
                  subject: manualSubject,
                  section: manualSection,
                  day: _dayIndex,
                  slot: desiredSlot,
                  courseId: widget.currentUser.courseId,
                  userName: widget.currentUser.name,
                  userId: widget.currentUser.id,
                );
                if (error != null) {
                  final suggestions =
                      _schedulerService.suggestAlternativeTimeSlots(
                    teacher: manualTeacher,
                    room: manualRoom,
                    day: _dayIndex,
                    desiredSlot: desiredSlot,
                  );
                  setState(() {
                    _aiConflictMessage = error;
                    _aiSuggestions = suggestions;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(error), backgroundColor: Colors.red));
                } else {
                  setState(() {
                    _aiConflictMessage = null;
                    _aiSuggestions = const [];
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Assignment Saved!'),
                      backgroundColor: Colors.green));
                }
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Save Assignment'),
          ),
          const SizedBox(height: 12),
          if (_aiConflictMessage != null || _aiSuggestions.isNotEmpty)
            AiSuggestionsCard(
              suggestions: _aiSuggestions,
              conflictMessage: _aiConflictMessage,
              formatRange: _formatTimeRange,
              onApplySuggestion: _applySuggestedSlot,
            ),
          const Divider(height: 40),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _visibleSchedule.length,
            itemBuilder: (context, i) {
              final sc = _visibleSchedule[i];
              return Card(
                child: ListTile(
                  title: Text(
                      '${sc.teacher.name} - ${sc.subject.name} (${sc.section.name})'),
                  subtitle: Text(
                    '${sc.room.name} | ${getDayName(sc.day)} | ${formatMinutesToTime(sc.timeSlot.startHour * 60 + sc.timeSlot.startMinute)} - ${formatMinutesToTime(sc.timeSlot.endHour * 60 + sc.timeSlot.endMinute)}',
                  ),
                  trailing: _isTeacher
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(
                            () => _schedulerService.removeSchedule(
                              i,
                              userName: widget.currentUser.name,
                              userId: widget.currentUser.id,
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
