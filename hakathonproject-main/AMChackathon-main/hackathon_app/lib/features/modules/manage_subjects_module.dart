part of '../../main.dart';

/// Subjects module: groups schedule entries by subject.
///
/// This screen derives a "subject list" from the current schedule and shows
/// where/when each subject is assigned.
extension ManageSubjectsModule on _DashboardScreenState {
  Widget buildManageSubjectsModule() {
    final scheduledSubjects =
        _visibleSchedule.map((sc) => sc.subject.name).toSet().toList();

    if (scheduledSubjects.isEmpty) {
      return const Center(child: Text('No subjects scheduled yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: scheduledSubjects.length,
      itemBuilder: (context, i) {
        final subName = scheduledSubjects[i];
        final subSchedules =
            _visibleSchedule.where((sc) => sc.subject.name == subName).toList();

        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.book, color: Colors.blue),
            title: Text(subName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Slots: ${subSchedules.length}'),
            children: subSchedules
                .map(
                  (sc) => ListTile(
                    dense: true,
                    title: Text(
                        'Instructor: ${sc.teacher.name} | Sec: ${sc.section.name}'),
                    subtitle: Text(
                      'Room: ${sc.room.name} | ${getDayName(sc.day)}: ${formatMinutesToTime(sc.timeSlot.startHour * 60 + sc.timeSlot.startMinute)} - ${formatMinutesToTime(sc.timeSlot.endHour * 60 + sc.timeSlot.endMinute)}',
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
