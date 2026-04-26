part of '../../main.dart';

/// Sections module: groups schedule entries by section.
///
/// This screen is built from `_visibleSchedule` and shows the list of classes
/// per student section.
extension ManageSectionsModule on _DashboardScreenState {
  Widget buildManageSectionsModule() {
    final scheduledSections =
        _visibleSchedule.map((sc) => sc.section.name).toSet().toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: scheduledSections.length,
      itemBuilder: (context, i) {
        final sectionName = scheduledSections[i];
        final sectionSchedule = _visibleSchedule
            .where((sc) => sc.section.name == sectionName)
            .toList();
        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.groups, color: Colors.orange),
            title: Text(sectionName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Slots: ${sectionSchedule.length}'),
            children: sectionSchedule
                .map(
                  (sc) => ListTile(
                    dense: true,
                    title: Text(sc.subject.name),
                    subtitle: Text(
                      'Room: ${sc.room.name} | Teacher: ${sc.teacher.name}\n${getDayName(sc.day)}: ${formatMinutesToTime(sc.timeSlot.startHour * 60 + sc.timeSlot.startMinute)} - ${formatMinutesToTime(sc.timeSlot.endHour * 60 + sc.timeSlot.endMinute)}',
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
