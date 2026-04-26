part of '../../main.dart';

/// Schedule list module.
///
/// Shows the schedule in a day-tabbed list format. For teachers, it shows only
/// their own schedule via `_visibleSchedule`.
extension ScheduleManagementModule on _DashboardScreenState {
  Widget buildScheduleManagementModule() {
    return DefaultTabController(
      length: _dayNames.length,
      child: Scaffold(
        appBar: TabBar(
          isScrollable: true,
          tabs: _dayNames.map((day) => Tab(text: day)).toList(),
          labelColor: Colors.blueGrey,
        ),
        body: TabBarView(
          children: List.generate(_dayNames.length, (index) {
            final dayInt = index + 1;
            final daySchedules = _visibleSchedule
                .where((sc) => sc.day == dayInt)
                .toList()
              ..sort((a, b) {
                final aMin = a.timeSlot.startHour * 60 + a.timeSlot.startMinute;
                final bMin = b.timeSlot.startHour * 60 + b.timeSlot.startMinute;
                return aMin.compareTo(bMin);
              });
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: daySchedules.length,
              itemBuilder: (context, i) {
                final sc = daySchedules[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueGrey[50],
                      child: Text(
                        sc.section.name.length > 2
                            ? sc.section.name
                                .substring(sc.section.name.length - 2)
                            : '?',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text('${sc.subject.name} (${sc.section.name})',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Teacher: ${sc.teacher.name} | Room: ${sc.room.name}'),
                    trailing: Text(
                      '${formatMinutesToTime(sc.timeSlot.startHour * 60 + sc.timeSlot.startMinute)}\n${formatMinutesToTime(sc.timeSlot.endHour * 60 + sc.timeSlot.endMinute)}',
                      textAlign: TextAlign.end,
                      style:
                          const TextStyle(color: Colors.blueGrey, fontSize: 10),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
