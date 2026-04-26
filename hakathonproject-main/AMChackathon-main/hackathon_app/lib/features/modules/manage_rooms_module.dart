part of '../../main.dart';

/// Rooms module: groups schedule entries by room.
///
/// This is not a CRUD screen; it is a read-only view of rooms inferred from the
/// schedule list.
extension ManageRoomsModule on _DashboardScreenState {
  Widget buildManageRoomsModule() {
    final scheduledRoomNames =
        _visibleSchedule.map((sc) => sc.room.name).toSet().toList();
    return ListView.builder(
      itemCount: scheduledRoomNames.length,
      itemBuilder: (context, i) {
        final roomName = scheduledRoomNames[i];
        final roomSchedule =
            _visibleSchedule.where((sc) => sc.room.name == roomName).toList();
        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.meeting_room),
            title: Text(roomName),
            subtitle: Text('Total Slots: ${roomSchedule.length}'),
            children: roomSchedule
                .map(
                  (sc) => ListTile(
                    dense: true,
                    title: Text('${sc.subject.name} (${sc.section.name})'),
                    subtitle: Text(
                      'Teacher: ${sc.teacher.name} | ${getDayName(sc.day)}: ${formatMinutesToTime(sc.timeSlot.startHour * 60 + sc.timeSlot.startMinute)} - ${formatMinutesToTime(sc.timeSlot.endHour * 60 + sc.timeSlot.endMinute)}',
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
