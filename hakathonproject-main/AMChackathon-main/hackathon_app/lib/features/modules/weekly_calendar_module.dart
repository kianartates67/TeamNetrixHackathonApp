part of '../../main.dart';

/// Weekly calendar module.
///
/// Renders a week grid (Mon-Sat) with blocks positioned by start/end times.
/// Classes are draggable so admins/teachers can attempt to move a class to a
/// different day/time. The drop target validates basic conflicts through
/// `SchedulerService` before updating the schedule.
extension WeeklyCalendarModule on _DashboardScreenState {
  Widget buildWeeklyCalendarModule() {
    const double hourHeight = 60.0;
    const int startHour = 7;
    const int endHour = 22;

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(height: 40),
              ...List.generate(
                endHour - startHour + 1,
                (i) => Container(
                  height: hourHeight,
                  width: 65,
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(formatMinutesToTime((startHour + i) * 60),
                      style: const TextStyle(fontSize: 9)),
                ),
              ),
            ],
          ),
          ...List.generate(6, (dayIdx) {
            final dayInt = dayIdx + 1;
            final dayClasses =
                _visibleSchedule.where((sc) => sc.day == dayInt).toList();

            return Expanded(
              child: Column(
                children: [
                  Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Colors.grey[300]!.withOpacity(0.2)))),
                    child: Text(_dayNames[dayIdx].substring(0, 3),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Stack(
                    children: [
                      Column(
                        children: List.generate(
                          endHour - startHour + 1,
                          (i) => Container(
                            height: hourHeight,
                            decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Colors.grey[100]!
                                            .withOpacity(0.05)))),
                          ),
                        ),
                      ),
                      ...dayClasses.map((sc) {
                        final top =
                            (sc.timeSlot.startHour - startHour) * hourHeight +
                                (sc.timeSlot.startMinute / 60 * hourHeight);
                        final height = ((sc.timeSlot.endHour * 60 +
                                    sc.timeSlot.endMinute) -
                                (sc.timeSlot.startHour * 60 +
                                    sc.timeSlot.startMinute)) /
                            60 *
                            hourHeight;

                        return Positioned(
                          top: top,
                          left: 2,
                          right: 2,
                          height: height,
                          child: Draggable<ScheduledClass>(
                            data: sc,
                            feedback: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: 100,
                                height: height,
                                color: Colors.blue.withOpacity(0.5),
                                padding: const EdgeInsets.all(4),
                                child: Text(sc.subject.name,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10)),
                              ),
                            ),
                            childWhenDragging: Container(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                border: Border.all(
                                    color: Colors.blue.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sc.subject.name,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis),
                                  Text(sc.room.name,
                                      style: const TextStyle(
                                          fontSize: 8, color: Colors.blueGrey),
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      ...List.generate(
                        endHour - startHour,
                        (h) => Positioned(
                          top: h * hourHeight,
                          left: 0,
                          right: 0,
                          height: hourHeight,
                          child: DragTarget<ScheduledClass>(
                            onWillAccept: (data) => true,
                            onAccept: (data) {
                              final newSlot = TimeSlot(
                                startHour: startHour + h,
                                startMinute: 0,
                                endHour: startHour + h + 1,
                                endMinute: 0,
                              );

                              if (_schedulerService.isRoomAvailable(
                                      data.room, dayInt, newSlot) &&
                                  _schedulerService.isTeacherAvailable(
                                      data.teacher, dayInt, newSlot)) {
                                final index =
                                    _schedulerService.schedule.indexOf(data);
                                final updated = ScheduledClass(
                                  room: data.room,
                                  teacher: data.teacher,
                                  subject: data.subject,
                                  section: data.section,
                                  day: dayInt,
                                  timeSlot: newSlot,
                                );
                                _schedulerService.updateSchedule(
                                  index,
                                  updated,
                                  userName: widget.currentUser.name,
                                  userId: widget.currentUser.id,
                                );
                                setState(() {});
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Conflict detected!'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              return Container(
                                color: candidateData.isNotEmpty
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.transparent,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
